import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/enums/revo_enums.dart';
import '../../core/errors/revo_exception.dart';
import '../../models/rehearsal.dart';
import '../../models/venue.dart';
import '../../services/auth_identity.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/venue_repository.dart';

class FirebaseVenueRepository implements VenueRepository {
  FirebaseVenueRepository({
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

  CollectionReference<Map<String, dynamic>> get _venues =>
      _firestore.collection('venues');

  Future<void> _requireAdmin() async {
    final identity = await _identityProvider.currentIdentity();
    if (identity == null || !identity.isFirebaseAuthenticated) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Authentication is required.',
      );
    }
    if (identity.role != UserRole.admin) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only admins can manage venues.',
      );
    }
  }

  Venue _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data == null) {
      throw StateError('Venue document ${document.id} has no data.');
    }
    final normalized = Map<String, dynamic>.from(data);
    final availability = normalized['availability'];
    if (availability is bool) {
      normalized['availability'] = <String, dynamic>{'available': availability};
    } else if (availability is! Map) {
      normalized['availability'] = <String, dynamic>{};
    } else {
      normalized['availability'] = Map<String, dynamic>.from(availability);
    }
    final rawStatus = normalized['status']?.toString().toUpperCase();
    normalized['status'] = rawStatus == 'AVAILABLE'
        ? VenueStatus.active.name
        : rawStatus?.toLowerCase();
    return Venue.fromMap(normalized, document.id);
  }

  Map<String, dynamic> _mapInput(VenueInput input) => {
    'name': input.name.trim(),
    'location': input.location.trim(),
    'capacity': input.capacity,
    'availability': input.availability,
  };

  void _validate(VenueInput input) {
    if (input.name.trim().isEmpty || input.location.trim().isEmpty) {
      throw ArgumentError('Venue name and location cannot be empty.');
    }
    if (input.capacity < 0) {
      throw ArgumentError('Venue capacity cannot be negative.');
    }
  }

  @override
  Stream<List<Venue>> watchVenues({bool activeOnly = true}) {
    Query<Map<String, dynamic>> query = _venues;
    if (activeOnly) {
      query = query.where('status', whereIn: ['active', 'ACTIVE', 'AVAILABLE']);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(_fromDocument).toList(),
    );
  }

  @override
  Future<List<Venue>> getVenues({bool activeOnly = false}) async {
    final snapshot = await _venues.get();
    final venues = snapshot.docs.map(_fromDocument);
    return activeOnly
        ? venues.where((venue) => venue.status == VenueStatus.active).toList()
        : venues.toList();
  }

  @override
  Future<Venue> getVenue(String venueId) async {
    final document = await _venues.doc(venueId).get();
    if (!document.exists) {
      throw RevoException(RevoErrorCode.notFound, 'Venue not found.');
    }
    return _fromDocument(document);
  }

  @override
  Future<Venue> createVenue(VenueInput input) async {
    await _requireAdmin();
    _validate(input);
    final document = _venues.doc();
    final data = _mapInput(input)..['status'] = VenueStatus.active.name;
    await document.set({...data, 'venueId': document.id});
    return Venue.fromMap(data, document.id);
  }

  @override
  Future<void> updateVenue(String venueId, VenueInput input) async {
    await _requireAdmin();
    _validate(input);
    final document = _venues.doc(venueId);
    if (!(await document.get()).exists) {
      throw RevoException(RevoErrorCode.notFound, 'Venue not found.');
    }
    await document.update(_mapInput(input));
  }

  @override
  Future<void> toggleStatus(String venueId) async {
    await _requireAdmin();
    final document = _venues.doc(venueId);
    final snapshot = await document.get();
    if (!snapshot.exists) {
      throw RevoException(RevoErrorCode.notFound, 'Venue not found.');
    }
    final venue = _fromDocument(snapshot);
    final status = venue.status == VenueStatus.active
        ? VenueStatus.inactive
        : VenueStatus.active;
    await document.update({'status': status.name});
  }

  @override
  Future<List<Rehearsal>> getRehearsalsForVenue(String venueId) async {
    final snapshot = await _firestore
        .collection('rehearsals')
        .where('venueId', isEqualTo: venueId)
        .get();
    return snapshot.docs
        .map((document) => Rehearsal.fromMap(document.data(), document.id))
        .where((rehearsal) => rehearsal.status != RehearsalStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  @override
  Future<String> getProductionName(String productionId) async {
    final document = await _firestore
        .collection('productions')
        .doc(productionId)
        .get();
    final name = document.data()?['name']?.toString().trim();
    return name == null || name.isEmpty ? 'Unknown Production' : name;
  }

  @override
  Future<List<TimeRange>> getBookings(String venueId, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final snapshot = await _firestore
        .collection('rehearsals')
        .where('venueId', isEqualTo: venueId)
        .where('status', isEqualTo: RehearsalStatus.confirmed.name)
        .get();
    return snapshot.docs
        .map((doc) => doc.data())
        .where((data) {
          final rehearsalStart = DateTime.tryParse(
            data['startAt']?.toString() ?? '',
          );
          return rehearsalStart != null &&
              !rehearsalStart.isBefore(start) &&
              rehearsalStart.isBefore(end);
        })
        .map(
          (data) => TimeRange(
            startAt: DateTime.parse(data['startAt'].toString()),
            endAt: DateTime.parse(data['endAt'].toString()),
          ),
        )
        .toList();
  }
}
