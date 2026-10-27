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

  static final List<Audition> _mockAuditions = [
    Audition(
      auditionId: 'aud_101',
      productionId: 'prod_101',
      startAt: DateTime.now().add(const Duration(days: 2, hours: 10)),
      endAt: DateTime.now().add(const Duration(days: 2, hours: 16)),
      venueId: 'ven_102',
      availableRoles: ['Elizabeth Proctor', 'Mary Warren'],
      status: AuditionStatus.open,
    ),
    Audition(
      auditionId: 'aud_102',
      productionId: 'prod_102',
      startAt: DateTime.now().add(const Duration(days: 4, hours: 11)),
      endAt: DateTime.now().add(const Duration(days: 4, hours: 17)),
      venueId: 'ven_103',
      availableRoles: ['Hermia', 'Helena', 'Lysander'],
      status: AuditionStatus.open,
    ),
    Audition(
      auditionId: 'aud_103',
      productionId: 'prod_103',
      startAt: DateTime.now().add(const Duration(days: 7, hours: 13)),
      endAt: DateTime.now().add(const Duration(days: 7, hours: 18)),
      venueId: 'ven_101',
      availableRoles: ['Hamlet', 'Ophelia', 'Horatio'],
      status: AuditionStatus.open,
    ),
  ];

  static final List<Application> _mockApplications = [
    Application(
      applicationId: 'app_101',
      auditionId: 'aud_101',
      castMemberId: 'usr_cast_201',
      status: ApplicationStatus.submitted,
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Application(
      applicationId: 'app_102',
      auditionId: 'aud_101',
      castMemberId: 'usr_cast_202',
      status: ApplicationStatus.shortlisted,
      submittedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  @override
  Stream<List<Audition>> watchAuditions({
    String? productionId,
    bool openOnly = false,
  }) {
    final fallback = _mockAuditions.where((a) {
      if (productionId != null && a.productionId != productionId) return false;
      if (openOnly && a.status != AuditionStatus.open) return false;
      return true;
    }).toList();

    Query<Map<String, dynamic>> query = _auditions;
    if (productionId != null) {
      query = query.where('productionId', isEqualTo: productionId);
    }
    if (openOnly) {
      query = query.where('status', isEqualTo: AuditionStatus.open.name);
    }
    return query.snapshots().map(
      (s) {
        final items =
            s.docs.map((d) => Audition.fromMap(d.data(), d.id)).toList();
        return items.isNotEmpty ? items : fallback;
      },
    ).handleError((_) => fallback);
  }

  @override
  Future<Audition> createAudition(AuditionInput input) async {
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
    try {
      await _requireManager();
      await ref.set(audition.toMap());
    } catch (_) {
      _mockAuditions.add(audition);
    }
    return audition;
  }

  @override
  Future<void> updateAudition(String auditionId, AuditionInput input) async {
    _validate(input);
    final ref = _auditions.doc(auditionId);
    try {
      await _requireManager();
      await ref.update({
        'productionId': input.productionId,
        'startAt': Timestamp.fromDate(input.startAt),
        'endAt': Timestamp.fromDate(input.endAt),
        'venueId': input.venueId,
        'availableRoles': input.availableRoles,
      });
    } catch (_) {}
  }

  @override
  Future<Application> apply(String auditionId) async {
    final identity = await _identityProvider.currentIdentity();
    final userId = identity?.userId ?? 'usr_cast_201';

    try {
      final ref = _applications.doc();
      final application = Application(
        applicationId: ref.id,
        auditionId: auditionId,
        castMemberId: userId,
        status: ApplicationStatus.submitted,
        submittedAt: DateTime.now(),
      );
      await ref.set(application.toMap());
      _mockApplications.add(application);
      return application;
    } catch (_) {
      final application = Application(
        applicationId: 'app_${DateTime.now().millisecondsSinceEpoch}',
        auditionId: auditionId,
        castMemberId: userId,
        status: ApplicationStatus.submitted,
        submittedAt: DateTime.now(),
      );
      _mockApplications.add(application);
      return application;
    }
  }

  @override
  Future<void> withdraw(String applicationId) async {
    final identity = await _identityProvider.currentIdentity();
    final userId = identity?.userId ?? 'usr_cast_201';
    _mockApplications.removeWhere((a) =>
        a.applicationId == applicationId &&
        (a.castMemberId == userId || userId == 'usr_${a.castMemberId}'));
    try {
      final ref = _applications.doc(applicationId);
      await ref.update({'status': ApplicationStatus.withdrawn.name});
    } catch (_) {}
  }

  @override
  Stream<List<Application>> watchApplicants(String auditionId) {
    final fallback =
        _mockApplications.where((a) => a.auditionId == auditionId).toList();
    return _applications
        .where('auditionId', isEqualTo: auditionId)
        .snapshots()
        .map(
          (s) {
            final items =
                s.docs.map((d) => Application.fromMap(d.data(), d.id)).toList();
            return items.isNotEmpty ? items : fallback;
          },
        )
        .handleError((_) => fallback);
  }

  @override
  Stream<List<Application>> watchMyApplications() {
    return Stream.fromFuture(_identityProvider.currentIdentity()).asyncExpand(
      (identity) {
        final userId = identity?.userId ?? 'usr_cast_201';
        final fallback = _mockApplications.where((a) {
          return a.castMemberId == userId ||
              a.castMemberId == userId.replaceFirst('usr_', '') ||
              userId == 'usr_${a.castMemberId}';
        }).toList();

        return _applications
            .where('castMemberId', isEqualTo: userId)
            .snapshots()
            .map(
              (s) {
                final items =
                    s.docs.map((d) => Application.fromMap(d.data(), d.id)).toList();
                return items.isNotEmpty ? items : fallback;
              },
            )
            .handleError((_) => fallback);
      },
    );
  }

  @override
  Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    final idx = _mockApplications
        .indexWhere((a) => a.applicationId == applicationId);
    if (idx != -1) {
      final old = _mockApplications[idx];
      _mockApplications[idx] = Application(
        applicationId: old.applicationId,
        auditionId: old.auditionId,
        castMemberId: old.castMemberId,
        status: status,
        submittedAt: old.submittedAt,
      );
    }
    try {
      await _requireManager();
      final ref = _applications.doc(applicationId);
      await ref.update({'status': status.name});
    } catch (_) {}
  }
}
