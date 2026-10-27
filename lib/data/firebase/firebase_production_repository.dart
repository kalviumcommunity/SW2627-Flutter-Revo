import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/enums/revo_enums.dart';
import '../../core/errors/revo_exception.dart';
import '../../models/cast_assignment.dart';
import '../../models/production.dart';
import '../../models/production_role.dart';
import '../../models/rehearsal.dart';
import '../../models/venue.dart';
import '../../services/auth_identity.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/production_repository.dart';
import '../../services/mock_data_service.dart';

class FirebaseProductionRepository implements ProductionRepository {
  FirebaseProductionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuthIdentityProvider? identityProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityProvider =
           identityProvider ??
           (auth != null
               ? FirebaseAuthIdentityProvider(
                   auth: auth,
                   firestore: firestore ?? FirebaseFirestore.instance,
                 )
               : FirebaseAuthService());

  final FirebaseFirestore _firestore;
  final AuthIdentityProvider _identityProvider;
  CollectionReference<Map<String, dynamic>> get _productions =>
      _firestore.collection('productions');
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  dynamic _value(Map<String, dynamic> data, String key) => data[key];
  DateTime _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  Production _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data == null) {
      throw StateError('Production document ${document.id} has no data.');
    }
    final normalized = Map<String, dynamic>.from(data)
      ..['startDate'] = _date(_value(data, 'startDate')).toIso8601String()
      ..['endDate'] = _date(_value(data, 'endDate')).toIso8601String()
      ..['createdAt'] = _date(_value(data, 'createdAt')).toIso8601String()
      ..['updatedAt'] = _date(_value(data, 'updatedAt')).toIso8601String();
    final raw = data['status']?.toString().toUpperCase();
    normalized['status'] = switch (raw) {
      'PLANNED' => ProductionStatus.planning.name,
      'ACTIVE' => ProductionStatus.rehearsing.name,
      _ => raw?.toLowerCase(),
    };
    return Production.fromMap(normalized, document.id);
  }

  @override
  Stream<List<Production>> watchProductions({
    required String userId,
    required UserRole role,
  }) {
    final fallback = MockDataService().getProductionsSync().where((p) {
      if (role == UserRole.director && p.directorId != userId) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    Query<Map<String, dynamic>> query = _productions;
    if (role == UserRole.director) {
      query = query.where('directorId', isEqualTo: userId);
    }
    // Show the local role-scoped catalog immediately while Firestore connects.
    // A snapshot may be delayed indefinitely when Firebase is offline or the
    // user has not been granted access, which would otherwise leave the UI in
    // its loading state forever.
    return Stream<List<Production>>.multi((controller) {
      controller.add(fallback);
      final subscription = query.snapshots().listen(
        (snapshot) {
          try {
            final items = snapshot.docs.map(_fromDocument).toList()
              ..sort((a, b) => a.startDate.compareTo(b.startDate));
            controller.add(items.isNotEmpty ? items : fallback);
          } catch (error) {
            controller.addError(error);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.add(fallback);
        },
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<Production> getProduction(String productionId) async {
    final document = await _productions.doc(productionId).get();
    if (!document.exists) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Production "$productionId" was not found.',
      );
    }
    return _fromDocument(document);
  }

  void _validate(ProductionInput input) {
    if (input.name.trim().isEmpty) {
      throw ArgumentError('Production name cannot be empty.');
    }

    if (input.endDate.isBefore(input.startDate)) {
      throw ArgumentError('End date cannot be before start date.');
    }
  }

  Future<AuthIdentity> _requireManager() async {
    final identity = await _identityProvider.currentIdentity();
    if (identity == null || !identity.isFirebaseAuthenticated) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Authentication is required.',
      );
    }
    if (identity.role != UserRole.director && identity.role != UserRole.admin) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only directors or admins can manage productions.',
      );
    }
    return identity;
  }

  Future<void> _requireProductionAccess(String productionId) async {
    final identity = await _requireManager();
    if (identity.role == UserRole.admin) {
      return;
    }
    final production = await _productions.doc(productionId).get();
    if (!production.exists ||
        production.data()?['directorId'] != identity.userId) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Directors can only manage their own productions.',
      );
    }
  }

  @override
  Future<List<Production>> getProductions({
    required String userId,
    required UserRole role,
  }) async {
    Query<Map<String, dynamic>> query = _productions;
    if (role == UserRole.director) {
      query = query.where('directorId', isEqualTo: userId);
    }
    final snapshot = await query.get();
    return snapshot.docs.map(_fromDocument).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  @override
  Future<Production> createProduction(
    ProductionInput input, {
    String? directorId,
  }) async {
    final identity = await _requireManager();
    _validate(input);
    final selectedDirectorId = directorId?.trim().isNotEmpty == true
        ? directorId!.trim()
        : identity.userId;
    if (identity.role == UserRole.director &&
        selectedDirectorId != identity.userId) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Directors can only create productions for themselves.',
      );
    }
    final ref = _productions.doc();
    final now = DateTime.now();
    final production = Production(
      productionId: ref.id,
      name: input.name.trim(),
      description: input.description.trim(),
      directorId: selectedDirectorId,
      startDate: input.startDate,
      endDate: input.endDate,
      status: input.status,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(production.toMap());
    return production;
  }

  @override
  Future<void> updateProduction(
    String productionId,
    ProductionInput input,
  ) async {
    await _requireProductionAccess(productionId);
    _validate(input);
    final ref = _productions.doc(productionId);
    if (!(await ref.get()).exists) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Production "$productionId" was not found.',
      );
    }
    await ref.update({
      'name': input.name.trim(),
      'description': input.description.trim(),
      'startDate': input.startDate.toIso8601String(),
      'endDate': input.endDate.toIso8601String(),
      'status': input.status.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> setStatus(String productionId, ProductionStatus status) async {
    await _requireProductionAccess(productionId);
    final ref = _productions.doc(productionId);
    if (!(await ref.get()).exists) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Production "$productionId" was not found.',
      );
    }
    await ref.update({
      'status': status.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteProduction(String productionId) async {
    await _requireProductionAccess(productionId);

    final document = _productions.doc(productionId);
    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Production not found.',
      );
    }

    await document.delete();
  }

  @override
  Future<String> getDirectorName(String directorId) => getUserName(directorId);

  @override
  Future<List<ProductionRole>> getRolesForProduction(String productionId) async {
    final snapshot = await _firestore
        .collection('roles')
        .where('productionId', isEqualTo: productionId)
        .get();
    return snapshot.docs
        .map((document) => ProductionRole.fromMap(document.data(), document.id))
        .toList();
  }

  @override
  Future<List<CastAssignment>> getCastAssignmentsForProduction(
    String productionId,
  ) async {
    final snapshot = await _firestore
        .collection('castAssignments')
        .where('productionId', isEqualTo: productionId)
        .get();
    return snapshot.docs
        .map((document) => CastAssignment.fromMap(document.data(), document.id))
        .where((assignment) => assignment.status == AssignmentStatus.active)
        .toList();
  }

  @override
  Future<List<Rehearsal>> getRehearsalsForProduction(
    String productionId,
  ) async {
    final snapshot = await _firestore
        .collection('rehearsals')
        .where('productionId', isEqualTo: productionId)
        .get();
    return snapshot.docs
        .map((document) => Rehearsal.fromMap(document.data(), document.id))
        .where((rehearsal) => rehearsal.status != RehearsalStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  @override
  Future<List<Venue>> getVenuesForProduction(String productionId) async {
    final rehearsals = await getRehearsalsForProduction(productionId);
    final venueIds = rehearsals.map((rehearsal) => rehearsal.venueId).toSet();
    if (venueIds.isEmpty) {
      return [];
    }
    final venues = <Venue>[];
    for (final venueId in venueIds) {
      final venue = await getVenueById(venueId);
      if (venue != null) {
        venues.add(venue);
      }
    }
    return venues;
  }

  @override
  Future<String> getUserName(String userId) async {
    final document = await _users.doc(userId).get();
    final name = document.data()?['name']?.toString().trim();
    return name == null || name.isEmpty ? 'Team Member ($userId)' : name;
  }

  @override
  Future<Venue?> getVenueById(String venueId) async {
    final document = await _firestore.collection('venues').doc(venueId).get();
    return document.exists
        ? Venue.fromMap(
            _normalizeVenueData(document.data()!, document.id),
            document.id,
          )
        : null;
  }

  Map<String, dynamic> _normalizeVenueData(
    Map<String, dynamic> data,
    String id,
  ) {
    final normalized = Map<String, dynamic>.from(data);
    final availability = normalized['availability'];
    normalized['availability'] = availability is Map
        ? Map<String, dynamic>.from(availability)
        : <String, dynamic>{'available': availability is bool && availability};
    final status = normalized['status']?.toString().toUpperCase();
    normalized['status'] = status == 'AVAILABLE'
        ? VenueStatus.active.name
        : status?.toLowerCase();
    normalized['venueId'] ??= id;
    return normalized;
  }
}
