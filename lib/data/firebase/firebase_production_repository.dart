import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/enums/revo_enums.dart';
import '../../core/errors/revo_exception.dart';
import '../../models/production.dart';
import '../../services/auth_identity.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/production_repository.dart';

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
    Query<Map<String, dynamic>> query = _productions;
    if (role == UserRole.director) {
      query = query.where('directorId', isEqualTo: userId);
    }
    return query.snapshots().map(
      (s) =>
          s.docs.map(_fromDocument).toList()
            ..sort((a, b) => a.startDate.compareTo(b.startDate)),
    );
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

  @override
  Future<Production> createProduction(ProductionInput input) async {
    final identity = await _requireManager();
    _validate(input);
    final ref = _productions.doc();
    final now = DateTime.now();
    final production = Production(
      productionId: ref.id,
      name: input.name.trim(),
      description: input.description.trim(),
      directorId: identity.userId,
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
    await _requireManager();
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
}
