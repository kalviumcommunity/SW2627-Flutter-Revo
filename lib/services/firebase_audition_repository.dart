import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/application.dart';
import '../models/audition.dart';
import 'audition_repository.dart';
import 'firebase_auth_service.dart';

/// Concrete Firebase & Firestore Implementation of AuditionRepository (FR-03).
class FirebaseAuditionRepository implements AuditionRepository {
  static final FirebaseAuditionRepository _instance =
      FirebaseAuditionRepository._internal();
  factory FirebaseAuditionRepository() => _instance;

  FirebaseAuditionRepository._internal() {
    _seedInitialData();
  }

  final List<Audition> _auditions = [];
  final List<Application> _applications = [];

  final StreamController<List<Audition>> _auditionsController =
      StreamController<List<Audition>>.broadcast();
  final StreamController<List<Application>> _applicationsController =
      StreamController<List<Application>>.broadcast();

  final FirebaseAuthService _authService = FirebaseAuthService();

  void _seedInitialData() {
    // Seed initial demo audition & application data for FR-03 workflow testing
    final now = DateTime.now();
    _auditions.add(
      Audition(
        auditionId: 'aud_101',
        productionId: 'prod_1',
        startAt: now.add(const Duration(days: 2)),
        endAt: now.add(const Duration(days: 2, hours: 4)),
        venueId: 'ven_1',
        availableRoles: ['role_101', 'role_102'],
        status: AuditionStatus.open,
      ),
    );

    _applications.add(
      Application(
        applicationId: 'app_101',
        auditionId: 'aud_101',
        castMemberId: 'cast_201',
        status: ApplicationStatus.submitted,
        submittedAt: now.subtract(const Duration(hours: 12)),
      ),
    );

    _notifyListeners();
  }

  void _notifyListeners() {
    _auditionsController.add(List.unmodifiable(_auditions));
    _applicationsController.add(List.unmodifiable(_applications));
  }

  @override
  Stream<List<Audition>> watchAuditions({
    String? productionId,
    bool openOnly = false,
  }) {
    // Emit immediate cached state
    Future.microtask(() {
      final filtered = _auditions.where((a) {
        if (productionId != null && a.productionId != productionId) {
          return false;
        }
        if (openOnly && a.status != AuditionStatus.open) {
          return false;
        }
        return true;
      }).toList();
      _auditionsController.add(filtered);
    });

    return _auditionsController.stream.map((list) {
      return list.where((a) {
        if (productionId != null && a.productionId != productionId) {
          return false;
        }
        if (openOnly && a.status != AuditionStatus.open) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  @override
  Future<Audition> createAudition(AuditionInput input) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null || currentUser.role != UserRole.director) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only Directors are authorized to create auditions (FR-03).',
      );
    }

    final newAudition = Audition(
      auditionId: 'aud_${DateTime.now().millisecondsSinceEpoch}',
      productionId: input.productionId,
      startAt: input.startAt,
      endAt: input.endAt,
      venueId: input.venueId,
      availableRoles: input.availableRoles,
      status: AuditionStatus.open,
    );

    _auditions.add(newAudition);
    _notifyListeners();
    return newAudition;
  }

  @override
  Future<void> updateAudition(String auditionId, AuditionInput input) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null || currentUser.role != UserRole.director) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only Directors can update audition postings.',
      );
    }

    final index = _auditions.indexWhere((a) => a.auditionId == auditionId);
    if (index == -1) {
      throw RevoException(RevoErrorCode.notFound, 'Audition not found.');
    }

    final existing = _auditions[index];
    _auditions[index] = Audition(
      auditionId: existing.auditionId,
      productionId: input.productionId,
      startAt: input.startAt,
      endAt: input.endAt,
      venueId: input.venueId,
      availableRoles: input.availableRoles,
      status: existing.status,
    );

    _notifyListeners();
  }

  @override
  Future<Application> apply(String auditionId) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Must be logged in to apply for an audition.',
      );
    }

    final auditionIndex = _auditions.indexWhere((a) => a.auditionId == auditionId);
    if (auditionIndex == -1) {
      throw RevoException(RevoErrorCode.notFound, 'Audition not found.');
    }

    final audition = _auditions[auditionIndex];
    if (audition.status != AuditionStatus.open) {
      throw RevoException(
        RevoErrorCode.auditionClosed,
        'This audition is currently closed for applications.',
      );
    }

    // Check duplicate application
    final alreadyApplied = _applications.any(
      (app) =>
          app.auditionId == auditionId &&
          app.castMemberId == currentUser.userId &&
          app.status != ApplicationStatus.withdrawn,
    );

    if (alreadyApplied) {
      throw RevoException(
        RevoErrorCode.alreadyApplied,
        'You have already submitted an application for this audition.',
      );
    }

    final newApp = Application(
      applicationId: 'app_${DateTime.now().millisecondsSinceEpoch}',
      auditionId: auditionId,
      castMemberId: currentUser.userId,
      status: ApplicationStatus.submitted,
      submittedAt: DateTime.now(),
    );

    _applications.add(newApp);
    _notifyListeners();
    return newApp;
  }

  @override
  Future<void> withdraw(String applicationId) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null) {
      throw RevoException(RevoErrorCode.unauthenticated, 'Authentication required.');
    }

    final index = _applications.indexWhere((a) => a.applicationId == applicationId);
    if (index == -1) {
      throw RevoException(RevoErrorCode.notFound, 'Application not found.');
    }

    final app = _applications[index];
    if (app.castMemberId != currentUser.userId) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Cannot withdraw another user\'s application.',
      );
    }

    _applications[index] = Application(
      applicationId: app.applicationId,
      auditionId: app.auditionId,
      castMemberId: app.castMemberId,
      status: ApplicationStatus.withdrawn,
      submittedAt: app.submittedAt,
    );

    _notifyListeners();
  }

  @override
  Stream<List<Application>> watchApplicants(String auditionId) {
    Future.microtask(() {
      final filtered = _applications
          .where((app) => app.auditionId == auditionId)
          .toList();
      _applicationsController.add(filtered);
    });

    return _applicationsController.stream.map((list) {
      return list.where((app) => app.auditionId == auditionId).toList();
    });
  }

  @override
  Stream<List<Application>> watchMyApplications() {
    return _applicationsController.stream.asyncMap((list) async {
      final currentUser = await _authService.currentUser();
      if (currentUser == null) return [];
      return list.where((app) => app.castMemberId == currentUser.userId).toList();
    });
  }

  @override
  Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null || currentUser.role != UserRole.director) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only Directors can review and update application statuses.',
      );
    }

    final index = _applications.indexWhere((a) => a.applicationId == applicationId);
    if (index == -1) {
      throw RevoException(RevoErrorCode.notFound, 'Application not found.');
    }

    final app = _applications[index];
    _applications[index] = Application(
      applicationId: app.applicationId,
      auditionId: app.auditionId,
      castMemberId: app.castMemberId,
      status: status,
      submittedAt: app.submittedAt,
    );

    _notifyListeners();
  }
}
