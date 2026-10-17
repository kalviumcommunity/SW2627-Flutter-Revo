import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/application.dart';
import '../models/audition.dart';
import 'auth_identity.dart';
import 'firebase_auth_service.dart';
import 'audition_repository.dart';

class FirebaseAuditionRepository implements AuditionRepository {
  FirebaseAuditionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuthIdentityProvider? identityProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityProvider = identityProvider ??
           (auth != null
               ? FirebaseAuthIdentityProvider(
                   auth: auth,
                   firestore: firestore ?? FirebaseFirestore.instance,
                 )
               : FirebaseAuthService());

  final FirebaseFirestore _firestore;
  final AuthIdentityProvider _identityProvider;
  CollectionReference<Map<String, dynamic>> get _auditions =>
      _firestore.collection('auditions');
  CollectionReference<Map<String, dynamic>> get _applications =>
      _firestore.collection('applications');

  Future<String> _requireManager() async {
    final identity = await _identityProvider.currentIdentity();
    if (identity == null || !identity.isFirebaseAuthenticated) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Authentication is required.',
      );
    }
    if (identity.role != UserRole.director &&
        identity.role != UserRole.admin) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only directors or admins can manage auditions.',
      );
    }
    return identity.userId;
  }

  void _validate(AuditionInput input) {
    if (input.productionId.trim().isEmpty ||
        input.startAt.isAfter(input.endAt)) {
      throw ArgumentError('Audition production and valid dates are required.');
    }
  }

  @override
  Stream<List<Audition>> watchAuditions({
    String? productionId,
    bool openOnly = false,
  }) {
    Query<Map<String, dynamic>> query = _auditions;
    if (productionId != null) {
      query = query.where('productionId', isEqualTo: productionId);
    }
    if (openOnly) {
      query = query.where('status', isEqualTo: AuditionStatus.open.name);
    }
    return query.snapshots().map(
      (s) => s.docs.map((d) => Audition.fromMap(d.data(), d.id)).toList(),
    );
  }

  @override
  Future<Audition> createAudition(AuditionInput input) async {
    await _requireManager();
    _validate(input);
    final ref = _auditions.doc();
    final audition = Audition(
      auditionId: ref.id,
      productionId: input.productionId,
      startAt: input.startAt,
      endAt: input.endAt,
      venueId: input.venueId,
      availableRoles: input.availableRoles,
      status: AuditionStatus.open,
    );
    await ref.set(audition.toMap());
    return audition;
  }

  @override
  Future<void> updateAudition(String auditionId, AuditionInput input) async {
    await _requireManager();
    _validate(input);
    final ref = _auditions.doc(auditionId);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw RevoException(RevoErrorCode.notFound, 'Audition not found.');
    }
    await ref.update({
      'productionId': input.productionId,
      'startAt': input.startAt.toIso8601String(),
      'endAt': input.endAt.toIso8601String(),
      'venueId': input.venueId,
      'availableRoles': input.availableRoles,
    });
  }

  @override
  Future<Application> apply(String auditionId) async {
    final identity = await _identityProvider.currentIdentity();
    if (identity == null) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Authentication is required.',
      );
    }
    final auditionSnapshot = await _auditions.doc(auditionId).get();
    if (!auditionSnapshot.exists) {
      throw RevoException(RevoErrorCode.notFound, 'Audition not found.');
    }
    final audition = Audition.fromMap(auditionSnapshot.data()!, auditionId);
    if (audition.status != AuditionStatus.open) {
      throw RevoException(
        RevoErrorCode.auditionClosed,
        'This audition is closed for applications.',
      );
    }
    final existing = await _applications
        .where('auditionId', isEqualTo: auditionId)
        .where('castMemberId', isEqualTo: identity.userId)
        .get();
    if (existing.docs.any(
      (d) => d.data()['status'] != ApplicationStatus.withdrawn.name,
    )) {
      throw RevoException(
        RevoErrorCode.alreadyApplied,
        'You have already applied for this audition.',
      );
    }
    final ref = _applications.doc();
    final application = Application(
      applicationId: ref.id,
      auditionId: auditionId,
      castMemberId: identity.userId,
      status: ApplicationStatus.submitted,
      submittedAt: DateTime.now(),
    );
    await ref.set(application.toMap());
    return application;
  }

  @override
  Future<void> withdraw(String applicationId) async {
    final identity = await _identityProvider.currentIdentity();
    if (identity == null) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Authentication is required.',
      );
    }
    final ref = _applications.doc(applicationId);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw RevoException(RevoErrorCode.notFound, 'Application not found.');
    }
    if (snapshot.data()?['castMemberId'] != identity.userId) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Cannot withdraw another user\'s application.',
      );
    }
    await ref.update({'status': ApplicationStatus.withdrawn.name});
  }

  @override
  Stream<List<Application>> watchApplicants(String auditionId) => _applications
      .where('auditionId', isEqualTo: auditionId)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Application.fromMap(d.data(), d.id)).toList(),
      );

  @override
  Stream<List<Application>> watchMyApplications() {
    return Stream.fromFuture(_identityProvider.currentIdentity()).asyncExpand(
      (identity) {
        if (identity == null) {
          return Stream.value(const <Application>[]);
        }
        return _applications
            .where('castMemberId', isEqualTo: identity.userId)
            .snapshots()
            .map(
              (s) => s.docs
                  .map((d) => Application.fromMap(d.data(), d.id))
                  .toList(),
            );
      },
    );
  }

  @override
  Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    await _requireManager();
    final ref = _applications.doc(applicationId);
    if (!(await ref.get()).exists) {
      throw RevoException(RevoErrorCode.notFound, 'Application not found.');
    }
    await ref.update({'status': status.name});
  }
}
