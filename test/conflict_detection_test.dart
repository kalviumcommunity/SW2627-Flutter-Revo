import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/core/errors/revo_exception.dart';
import 'package:sw2627_flutter_revo_1/models/app_user.dart';
import 'package:sw2627_flutter_revo_1/services/mock_conflict_service.dart';
import 'package:sw2627_flutter_revo_1/services/mock_data_service.dart';
import 'package:sw2627_flutter_revo_1/services/mock_rehearsal_repository.dart';
import 'package:sw2627_flutter_revo_1/services/rehearsal_repository.dart';

void main() {
  late MockDataService dataService;
  late MockConflictService conflictService;
  late MockRehearsalRepository rehearsalRepo;

  final directorUser = AppUser(
    userId: 'usr_dir_101',
    name: 'Sarah Jenkins',
    email: 'director@revo.com',
    role: UserRole.director,
    createdAt: DateTime.now(),
  );

  final otherDirector = AppUser(
    userId: 'usr_dir_999',
    name: 'Other Director',
    email: 'other@revo.com',
    role: UserRole.director,
    createdAt: DateTime.now(),
  );

  final adminUser = AppUser(
    userId: 'usr_admin_301',
    name: 'Theatre Admin',
    email: 'admin@revo.com',
    role: UserRole.admin,
    createdAt: DateTime.now(),
  );

  final castUser = AppUser(
    userId: 'usr_cast_201',
    name: 'Alex Rivera',
    email: 'cast@revo.com',
    role: UserRole.cast,
    createdAt: DateTime.now(),
  );

  setUp(() {
    dataService = MockDataService();
    dataService.reset();
    conflictService = MockConflictService(dataService: dataService);
    rehearsalRepo = MockRehearsalRepository(
      dataService: dataService,
      conflictService: conflictService,
    );
  });

  group('Phase 4: Mocked Conflict Detection Service Tests (FR-08)', () {
    test(
      'Detects blocking venue conflict for overlapping interval on same day',
      () async {
        // In MockDataService, reh_101 is seeded on day + 1 at ven_102 (Studio A Rehearsal Hall)
        final existingRehearsal = dataService.getRehearsalById('reh_101')!;

        // Overlapping interval at the same venue
        final proposedStart = existingRehearsal.startAt.add(
          const Duration(minutes: 30),
        );
        final proposedEnd = existingRehearsal.endAt.add(
          const Duration(minutes: 30),
        );

        final conflicts = await conflictService.checkConflicts(
          productionId: 'prod_101',
          venueId: existingRehearsal.venueId,
          date: proposedStart,
          startTime: proposedStart,
          endTime: proposedEnd,
          participantIds: ['usr_cast_999'], // non-conflicting participant
        );

        expect(conflicts.isNotEmpty, isTrue);
        final venueConflict = conflicts.firstWhere(
          (c) => c.type == ConflictType.venue,
        );
        expect(venueConflict.isBlocking, isTrue);
        expect(venueConflict.resourceName, contains('Studio A Rehearsal Hall'));
        expect(venueConflict.conflictingRehearsalId, equals('reh_101'));
        expect(
          venueConflict.availableResolutions,
          contains(ConflictResolutionOption.changeVenue),
        );
        expect(
          venueConflict.availableResolutions,
          contains(ConflictResolutionOption.changeTime),
        );
      },
    );

    test('Detects blocking Cast Member conflict for overlapping interval on same day', () async {
      // reh_101 has participants: usr_cast_201, usr_cast_202
      final existingRehearsal = dataService.getRehearsalById('reh_101')!;

      // Different venue (ven_101), same participant (usr_cast_201), overlapping interval
      final proposedStart = existingRehearsal.startAt.add(
        const Duration(minutes: 15),
      );
      final proposedEnd = existingRehearsal.endAt.subtract(
        const Duration(minutes: 15),
      );

      final conflicts = await conflictService.checkConflicts(
        productionId: 'prod_101',
        venueId: 'ven_101', // Different venue
        date: proposedStart,
        startTime: proposedStart,
        endTime: proposedEnd,
        participantIds: ['usr_cast_201'],
      );

      expect(conflicts.isNotEmpty, isTrue);
      final castConflict = conflicts.firstWhere(
        (c) => c.type == ConflictType.cast,
      );
      expect(castConflict.isBlocking, isTrue);
      expect(castConflict.resourceId, equals('usr_cast_201'));
      expect(castConflict.resourceName, equals('Alex Rivera'));
      expect(castConflict.conflictingRehearsalId, equals('reh_101'));
      expect(
        castConflict.availableResolutions,
        contains(ConflictResolutionOption.changeParticipants),
      );
      expect(
        castConflict.availableResolutions,
        contains(ConflictResolutionOption.changeTime),
      );
    });

    test('Reports both venue and cast member conflicts when both overlap simultaneously', () async {
      final existingRehearsal = dataService.getRehearsalById('reh_101')!;

      // Same venue AND same cast member overlapping
      final proposedStart = existingRehearsal.startAt.add(
        const Duration(minutes: 30),
      );
      final proposedEnd = existingRehearsal.endAt.add(
        const Duration(minutes: 30),
      );

      final conflicts = await conflictService.checkConflicts(
        productionId: 'prod_101',
        venueId: existingRehearsal.venueId,
        date: proposedStart,
        startTime: proposedStart,
        endTime: proposedEnd,
        participantIds: ['usr_cast_201'],
      );

      expect(conflicts.length, greaterThanOrEqualTo(2));
      expect(conflicts.any((c) => c.type == ConflictType.venue), isTrue);
      expect(conflicts.any((c) => c.type == ConflictType.cast), isTrue);
    });

    test('Reports multiple conflicting cast members individually', () async {
      final existingRehearsal = dataService.getRehearsalById('reh_101')!;

      // Both usr_cast_201 and usr_cast_202 are in reh_101
      final proposedStart = existingRehearsal.startAt.add(
        const Duration(minutes: 30),
      );
      final proposedEnd = existingRehearsal.endAt.add(
        const Duration(minutes: 30),
      );

      final conflicts = await conflictService.checkConflicts(
        productionId: 'prod_101',
        venueId: 'ven_101', // Different venue
        date: proposedStart,
        startTime: proposedStart,
        endTime: proposedEnd,
        participantIds: ['usr_cast_201', 'usr_cast_202'],
      );

      final castConflicts = conflicts
          .where((c) => c.type == ConflictType.cast)
          .toList();
      expect(castConflicts.length, equals(2));
      expect(
        castConflicts.map((c) => c.resourceId).toSet(),
        containsAll(['usr_cast_201', 'usr_cast_202']),
      );
    });

    test('Adjacent rehearsals do not conflict when one ends exactly when next begins', () async {
      final existingRehearsal = dataService.getRehearsalById('reh_101')!;

      // Case A: Proposed ends exactly when existing begins
      final beforeStart = existingRehearsal.startAt.subtract(
        const Duration(hours: 2),
      );
      final beforeEnd = existingRehearsal.startAt;

      final conflictsBefore = await conflictService.checkConflicts(
        productionId: 'prod_101',
        venueId: existingRehearsal.venueId,
        date: beforeStart,
        startTime: beforeStart,
        endTime: beforeEnd,
        participantIds: ['usr_cast_201'],
      );
      expect(
        conflictsBefore,
        isEmpty,
        reason: 'Rehearsal ending at existing start time must not conflict',
      );

      // Case B: Proposed starts exactly when existing ends
      final afterStart = existingRehearsal.endAt;
      final afterEnd = existingRehearsal.endAt.add(const Duration(hours: 2));

      final conflictsAfter = await conflictService.checkConflicts(
        productionId: 'prod_101',
        venueId: existingRehearsal.venueId,
        date: afterStart,
        startTime: afterStart,
        endTime: afterEnd,
        participantIds: ['usr_cast_201'],
      );
      expect(
        conflictsAfter,
        isEmpty,
        reason: 'Rehearsal starting at existing end time must not conflict',
      );
    });

    test('Cancelled rehearsals do not block scheduling', () async {
      final cancelledRehearsal = dataService.getRehearsalById(
        'reh_105_cancelled',
      )!;
      expect(cancelledRehearsal.status, equals(RehearsalStatus.cancelled));

      final proposedStart = cancelledRehearsal.startAt;
      final proposedEnd = cancelledRehearsal.endAt;

      final conflicts = await conflictService.checkConflicts(
        productionId: 'prod_101',
        venueId: cancelledRehearsal.venueId,
        date: proposedStart,
        startTime: proposedStart,
        endTime: proposedEnd,
        participantIds: cancelledRehearsal.participantIds,
      );

      // Cancelled rehearsal must not produce blocking conflicts
      expect(
        conflicts.any(
          (c) =>
              c.conflictingRehearsalId == 'reh_105_cancelled' && c.isBlocking,
        ),
        isFalse,
      );
    });

    test('Self-rehearsal (excludeRehearsalId) does not conflict with itself during edit/revalidation', () async {
      final existingRehearsal = dataService.getRehearsalById('reh_101')!;

      final conflicts = await conflictService.checkConflicts(
        productionId: existingRehearsal.productionId,
        venueId: existingRehearsal.venueId,
        date: existingRehearsal.startAt,
        startTime: existingRehearsal.startAt,
        endTime: existingRehearsal.endAt,
        participantIds: existingRehearsal.participantIds,
        excludeRehearsalId: 'reh_101', // Excluding self
      );

      expect(conflicts, isEmpty);
    });

    test(
      'Different calendar dates do not cause same-day scheduling conflicts',
      () async {
        final existingRehearsal = dataService.getRehearsalById('reh_101')!;
        final differentDate = existingRehearsal.startAt.add(
          const Duration(days: 10),
        );

        final proposedStart = DateTime(
          differentDate.year,
          differentDate.month,
          differentDate.day,
          14,
          0,
        );
        final proposedEnd = DateTime(
          differentDate.year,
          differentDate.month,
          differentDate.day,
          17,
          0,
        );

        final conflicts = await conflictService.checkConflicts(
          productionId: 'prod_101',
          venueId: existingRehearsal.venueId,
          date: proposedStart,
          startTime: proposedStart,
          endTime: proposedEnd,
          participantIds: existingRehearsal.participantIds,
        );

        expect(conflicts, isEmpty);
      },
    );

    test(
      'Different venues with no shared cast members are conflict-free',
      () async {
        final existingRehearsal = dataService.getRehearsalById('reh_101')!;
        final conflicts = await conflictService.check(
          venueId: 'ven_101',
          startAt: existingRehearsal.startAt.add(const Duration(minutes: 30)),
          endAt: existingRehearsal.endAt,
          participantIds: ['usr_cast_999'],
        );

        expect(conflicts, isEmpty);
      },
    );

    test('Proposed rehearsals do not block confirmed scheduling', () async {
      final proposed = dataService.getRehearsalById('reh_103')!;
      final conflicts = await conflictService.check(
        venueId: proposed.venueId,
        startAt: proposed.startAt,
        endAt: proposed.endAt,
        participantIds: proposed.participantIds,
      );

      expect(conflicts, isEmpty);
    });

    test('Overlaps spanning midnight are detected', () async {
      final start = DateTime(2030, 1, 10, 23, 30);
      final end = DateTime(2030, 1, 11, 1, 30);
      await dataService.createRehearsal(
        input: RehearsalInput(
          productionId: 'prod_101',
          venueId: 'ven_103',
          startAt: start,
          endAt: end,
          participantIds: ['usr_cast_201'],
        ),
        createdBy: directorUser.userId,
      );

      final conflicts = await conflictService.check(
        venueId: 'ven_103',
        startAt: DateTime(2030, 1, 11, 0, 30),
        endAt: DateTime(2030, 1, 11, 2),
        participantIds: ['usr_cast_201'],
      );

      expect(
        conflicts.where((c) => c.type == ConflictType.venue),
        hasLength(1),
      );
      expect(conflicts.where((c) => c.type == ConflictType.cast), hasLength(1));
    });

    test('Invalid intervals are rejected by the conflict service', () async {
      final existing = dataService.getRehearsalById('reh_101')!;

      expect(
        () => conflictService.check(
          venueId: existing.venueId,
          startAt: existing.endAt,
          endAt: existing.startAt,
          participantIds: existing.participantIds,
        ),
        throwsA(
          isA<RevoException>().having(
            (error) => error.code,
            'code',
            RevoErrorCode.invalidInput,
          ),
        ),
      );
    });
  });

  group('Phase 7 & 8: Mock Rehearsal Repository & Role Permissions Tests', () {
    test(
      'Director can schedule rehearsal for authorized assigned production',
      () async {
        final scheduleDate = DateTime.now().add(const Duration(days: 5));
        final start = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day,
          9,
          0,
        );
        final end = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day,
          12,
          0,
        );

        final input = RehearsalInput(
          productionId: 'prod_101', // assigned to usr_dir_101
          title: 'Act I Blocking & Movement',
          startAt: start,
          endAt: end,
          venueId: 'ven_101',
          participantIds: ['usr_cast_201'],
          notes: 'Bring character scripts.',
        );

        final result = await rehearsalRepo.createRehearsal(
          input,
          user: directorUser,
        );

        expect(result.confirmed, isTrue);
        expect(result.rehearsal, isNotNull);
        final created = result.rehearsal!;
        expect(created.rehearsalId, startsWith('reh_'));
        expect(created.productionId, equals('prod_101'));
        expect(created.title, equals('Act I Blocking & Movement'));
        expect(created.status, equals(RehearsalStatus.confirmed));

        // Verify reflected in repository and MockDataService
        final fetched = await rehearsalRepo.getRehearsalById(
          created.rehearsalId,
        );
        expect(fetched, isNotNull);
        expect(fetched!.title, equals('Act I Blocking & Movement'));
      },
    );

    test('Director cannot schedule rehearsal for unassigned unauthorized production', () async {
      final scheduleDate = DateTime.now().add(const Duration(days: 6));
      final start = DateTime(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
        9,
        0,
      );
      final end = DateTime(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
        12,
        0,
      );

      final input = RehearsalInput(
        productionId: 'prod_102', // not assigned to usr_dir_101
        title: 'Unauthorized Rehearsal',
        startAt: start,
        endAt: end,
        venueId: 'ven_101',
        participantIds: ['usr_cast_201'],
      );

      expect(
        () => rehearsalRepo.createRehearsal(input, user: otherDirector),
        throwsA(
          isA<RevoException>().having(
            (e) => e.code,
            'code',
            RevoErrorCode.permissionDenied,
          ),
        ),
      );
    });

    test(
      'Admin can schedule rehearsal across any authorized production',
      () async {
        final scheduleDate = DateTime.now().add(const Duration(days: 7));
        final start = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day,
          10,
          0,
        );
        final end = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day,
          13,
          0,
        );

        // prod_102 has cast assignment for usr_cast_202 (Maya Lin)
        final input = RehearsalInput(
          productionId: 'prod_102',
          title: 'Admin Scheduled Session',
          startAt: start,
          endAt: end,
          venueId: 'ven_103',
          participantIds: ['usr_cast_202'],
        );

        final result = await rehearsalRepo.createRehearsal(
          input,
          user: adminUser,
        );
        expect(result.confirmed, isTrue);
        expect(result.rehearsal!.productionId, equals('prod_102'));
      },
    );

    test('Cast Member is rejected from scheduling rehearsals', () async {
      final scheduleDate = DateTime.now().add(const Duration(days: 8));
      final start = DateTime(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
        10,
        0,
      );
      final end = DateTime(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
        13,
        0,
      );

      final input = RehearsalInput(
        productionId: 'prod_101',
        title: 'Cast Attempted Scheduling',
        startAt: start,
        endAt: end,
        venueId: 'ven_101',
        participantIds: ['usr_cast_201'],
      );

      expect(
        () => rehearsalRepo.createRehearsal(input, user: castUser),
        throwsA(
          isA<RevoException>().having(
            (e) => e.code,
            'code',
            RevoErrorCode.permissionDenied,
          ),
        ),
      );
    });

    test(
      'Rejects rehearsal when end time is before or equal to start time',
      () async {
        final scheduleDate = DateTime.now().add(const Duration(days: 5));
        final start = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day,
          14,
          0,
        );
        final end = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day,
          13,
          0,
        ); // before start

        final input = RehearsalInput(
          productionId: 'prod_101',
          title: 'Invalid Timespan',
          startAt: start,
          endAt: end,
          venueId: 'ven_101',
          participantIds: ['usr_cast_201'],
        );

        expect(
          () => rehearsalRepo.createRehearsal(input, user: directorUser),
          throwsA(
            isA<RevoException>().having(
              (e) => e.code,
              'code',
              RevoErrorCode.invalidInput,
            ),
          ),
        );
      },
    );

    test('Rejects rehearsal with invalid venue reference', () async {
      final scheduleDate = DateTime.now().add(const Duration(days: 5));
      final start = DateTime(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
        10,
        0,
      );
      final end = DateTime(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
        12,
        0,
      );

      final badVenueInput = RehearsalInput(
        productionId: 'prod_101',
        title: 'Non-existent Venue',
        startAt: start,
        endAt: end,
        venueId: 'ven_does_not_exist',
        participantIds: ['usr_cast_201'],
      );

      expect(
        () => rehearsalRepo.createRehearsal(badVenueInput, user: directorUser),
        throwsA(
          isA<RevoException>().having(
            (e) => e.code,
            'code',
            RevoErrorCode.referenceMissing,
          ),
        ),
      );
    });

    test('Rejects rehearsal confirmation when blocking conflict exists at submission time', () async {
      final existingRehearsal = dataService.getRehearsalById('reh_101')!;

      // Collides with reh_101 at ven_102
      final conflictingInput = RehearsalInput(
        productionId: 'prod_101',
        title: 'Conflicting Booking',
        startAt: existingRehearsal.startAt.add(const Duration(minutes: 30)),
        endAt: existingRehearsal.endAt.add(const Duration(minutes: 30)),
        venueId: existingRehearsal.venueId,
        participantIds: ['usr_cast_201'],
      );

      final result = await rehearsalRepo.createRehearsal(
        conflictingInput,
        user: directorUser,
      );
      expect(result.confirmed, isFalse);
      expect(result.rehearsal, isNull);
      expect(result.conflicts.isNotEmpty, isTrue);
      expect(result.conflicts.any((c) => c.isBlocking), isTrue);
    });

    test(
      'Cancelling rehearsal marks it cancelled and frees up the slot',
      () async {
        final rehearsal = dataService.getRehearsalById('reh_101')!;
        expect(rehearsal.status, equals(RehearsalStatus.confirmed));

        await rehearsalRepo.cancelRehearsal('reh_101', user: directorUser);

        final updated = await rehearsalRepo.getRehearsalById('reh_101');
        expect(updated!.status, equals(RehearsalStatus.cancelled));

        // After cancellation, the same slot should now be conflict-free!
        final conflicts = await conflictService.checkConflicts(
          productionId: 'prod_101',
          venueId: rehearsal.venueId,
          date: rehearsal.startAt,
          startTime: rehearsal.startAt,
          endTime: rehearsal.endAt,
          participantIds: rehearsal.participantIds,
        );
        expect(conflicts, isEmpty);
      },
    );
  });
}
