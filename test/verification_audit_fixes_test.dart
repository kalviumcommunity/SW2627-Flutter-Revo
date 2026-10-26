import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/services/firebase_audition_repository.dart';
import 'package:sw2627_flutter_revo_1/services/firebase_cast_repository.dart';
import 'package:sw2627_flutter_revo_1/services/firebase_schedule_service.dart';
import 'package:sw2627_flutter_revo_1/services/mock_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Verification Audit Retests: BUG-001 & BUG-002', () {
    late MockAuthService authService;
    late FirebaseScheduleService scheduleService;
    late FirebaseCastRepository castRepo;
    late FirebaseAuditionRepository auditionRepo;

    setUp(() {
      authService = MockAuthService();
      scheduleService = FirebaseScheduleService();
      scheduleService.reset();
      castRepo = FirebaseCastRepository();
      auditionRepo = FirebaseAuditionRepository();
    });

    test('BUG-001 Fix: watchMySchedule yields rehearsals for logged-in Cast Member (usr_cast_201)', () async {
      await authService.login(email: 'cast@revo.com', password: 'password123');
      final currentUser = await authService.currentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!.userId, equals('usr_cast_201'));

      final snapshot = await scheduleService.watchMySchedule().first;
      expect(snapshot.items, isNotEmpty,
          reason: 'Seeded rehearsals must match logged-in cast member usr_cast_201');
      expect(snapshot.items.any((r) => r.rehearsalId == 'reh_101'), isTrue);
    });

    test('BUG-001 Fix: watchProductionSchedule yields rehearsals for prod_101', () async {
      final snapshot = await scheduleService.watchProductionSchedule('prod_101').first;
      expect(snapshot.items, isNotEmpty,
          reason: 'Seeded rehearsals must match production prod_101');
      expect(snapshot.items.any((r) => r.rehearsalId == 'reh_101'), isTrue);
    });

    test('BUG-001 Fix: watchMyAssignments yields assignments for logged-in Cast Member (usr_cast_201)', () async {
      await authService.login(email: 'cast@revo.com', password: 'password123');
      final assignments = await castRepo.watchMyAssignments().first;
      expect(assignments, isNotEmpty,
          reason: 'Seeded assignments must match logged-in cast member usr_cast_201');
      expect(assignments.first.roleId, equals('role_101'));
    });

    test('BUG-001 Fix: watchMyApplications yields applications for logged-in Cast Member (usr_cast_201)', () async {
      await authService.login(email: 'cast@revo.com', password: 'password123');
      final applications = await auditionRepo.watchMyApplications().first;
      expect(applications, isNotEmpty,
          reason: 'Seeded applications must match logged-in cast member usr_cast_201');
      expect(applications.first.auditionId, equals('aud_101'));
    });
  });
}
