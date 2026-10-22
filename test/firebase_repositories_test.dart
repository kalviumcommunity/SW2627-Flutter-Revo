import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/core/errors/revo_exception.dart';
import 'package:sw2627_flutter_revo_1/data/firebase/firebase_production_repository.dart';
import 'package:sw2627_flutter_revo_1/data/firebase/firebase_venue_repository.dart';
import 'package:sw2627_flutter_revo_1/models/app_user.dart';
import 'package:sw2627_flutter_revo_1/models/venue.dart';
import 'package:sw2627_flutter_revo_1/services/auth_identity.dart';
import 'package:sw2627_flutter_revo_1/services/firebase_rehearsal_repository.dart';
import 'package:sw2627_flutter_revo_1/services/firebase_cast_repository.dart';
import 'package:sw2627_flutter_revo_1/services/firebase_auth_service.dart';
import 'package:sw2627_flutter_revo_1/services/firebase_schedule_service.dart';
import 'package:sw2627_flutter_revo_1/services/rehearsal_repository.dart';
import 'package:sw2627_flutter_revo_1/services/schedule_service.dart';

class TestIdentityProvider implements AuthIdentityProvider {
  TestIdentityProvider(this.identity);

  AuthIdentity? identity;

  @override
  Future<AuthIdentity?> currentIdentity() async => identity;
}

void main() {
  group('Firestore repository conversion', () {
    test('maps production timestamps and uppercase status values', () async {
      final firestore = FakeFirebaseFirestore();
      final start = DateTime.utc(2026, 10, 1);
      await firestore.collection('productions').doc('production-1').set({
        'name': 'Hamlet',
        'description': 'A production',
        'directorId': 'director-1',
        'startDate': Timestamp.fromDate(start),
        'endDate': Timestamp.fromDate(start.add(const Duration(days: 2))),
        'createdAt': Timestamp.fromDate(start),
        'updatedAt': Timestamp.fromDate(start),
        'status': 'PLANNED',
      });

      final production = await FirebaseProductionRepository(
        firestore: firestore,
        identityProvider: TestIdentityProvider(
          const AuthIdentity(userId: 'director-1', role: UserRole.director),
        ),
      ).getProduction('production-1');

      expect(production.productionId, 'production-1');
      expect(production.status, ProductionStatus.planning);
      expect(production.startDate.toUtc(), start);
    });

    test('rejects rehearsal documents with missing dates', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rehearsals').doc('rehearsal-1').set({
        'productionId': 'production-1',
        'status': 'CONFIRMED',
      });

      expect(
        () => FirebaseRehearsalRepository(
          firestore: firestore,
          identityProvider: TestIdentityProvider(
            const AuthIdentity(
              userId: 'director-1',
              role: UserRole.director,
              isFirebaseAuthenticated: true,
            ),
          ),
        ).getRehearsal('rehearsal-1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('maps Firestore rehearsal timestamps without changing them', () async {
      final firestore = FakeFirebaseFirestore();
      final start = DateTime.utc(2026, 10, 2, 10);
      await firestore.collection('rehearsals').doc('rehearsal-1').set({
        'productionId': 'production-1',
        'startAt': Timestamp.fromDate(start),
        'endAt': Timestamp.fromDate(start.add(const Duration(hours: 2))),
        'createdAt': Timestamp.fromDate(start),
        'updatedAt': Timestamp.fromDate(start),
        'status': 'CONFIRMED',
      });

      final rehearsal = await FirebaseRehearsalRepository(
        firestore: firestore,
        identityProvider: TestIdentityProvider(
          const AuthIdentity(userId: 'director-1', role: UserRole.director),
        ),
      ).getRehearsal('rehearsal-1');

      expect(rehearsal.startAt.toUtc(), start);
      expect(rehearsal.endAt.toUtc(), start.add(const Duration(hours: 2)));
    });
  });

  test('filters active venues through the Firestore query', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('venues').doc('active').set({
      'name': 'Main Stage',
      'location': 'Theatre',
      'capacity': 100,
      'availability': {'available': true},
      'status': 'active',
    });
    await firestore.collection('venues').doc('inactive').set({
      'name': 'Closed Room',
      'location': 'Theatre',
      'capacity': 20,
      'availability': {},
      'status': 'inactive',
    });

    final venues = await FirebaseVenueRepository(
      firestore: firestore,
      identityProvider: TestIdentityProvider(null),
    ).watchVenues().first;

    expect(venues.map((venue) => venue.venueId), ['active']);
  });

  test(
    'accepts lowercase mock roles and rejects cast management access',
    () async {
      final user = AppUser.fromMap({
        'name': 'Cast member',
        'email': 'cast@example.com',
        'role': 'cast',
      }, 'cast-1');
      expect(user.role, UserRole.cast);

      final firestore = FakeFirebaseFirestore();
      final repository = FirebaseVenueRepository(
        firestore: firestore,
        identityProvider: TestIdentityProvider(
          const AuthIdentity(
            userId: 'cast-1',
            role: UserRole.cast,
            isFirebaseAuthenticated: true,
          ),
        ),
      );

      await expectLater(
        repository.createVenue(
          VenueInput(
            name: 'Stage',
            location: 'Theatre',
            capacity: 50,
            availability: const {},
          ),
        ),
        throwsA(
          isA<RevoException>().having(
            (error) => error.code,
            'code',
            RevoErrorCode.permissionDenied,
          ),
        ),
      );
    },
  );

  test('rejects unauthenticated rehearsal writes', () async {
    final repository = FirebaseRehearsalRepository(
      firestore: FakeFirebaseFirestore(),
      identityProvider: TestIdentityProvider(null),
    );

    await expectLater(
      repository.createRehearsal(
        RehearsalInput(
          productionId: 'production-1',
          venueId: 'main-stage',
          startAt: DateTime.utc(2026, 10, 15, 10),
          endAt: DateTime.utc(2026, 10, 15, 12),
          participantIds: const [],
        ),
      ),
      throwsA(
        isA<RevoException>().having(
          (error) => error.code,
          'code',
          RevoErrorCode.unauthenticated,
        ),
      ),
    );

    final mockIdentityRepository = FirebaseRehearsalRepository(
      firestore: FakeFirebaseFirestore(),
      identityProvider: TestIdentityProvider(
        const AuthIdentity(userId: 'director-1', role: UserRole.director),
      ),
    );
    await expectLater(
      mockIdentityRepository.createRehearsal(
        RehearsalInput(
          productionId: 'production-1',
          venueId: 'main-stage',
          startAt: DateTime.utc(2026, 10, 15, 10),
          endAt: DateTime.utc(2026, 10, 15, 12),
          participantIds: const [],
        ),
      ),
      throwsA(
        isA<RevoException>().having(
          (error) => error.code,
          'code',
          RevoErrorCode.unauthenticated,
        ),
      ),
    );
  });

  test('does not query assignments for a mock identity', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('castAssignments').doc('assignment-1').set({
      'productionId': 'production-1',
      'roleId': 'role-1',
      'castMemberId': 'cast-1',
      'assignedAt': '2026-10-01T00:00:00.000Z',
      'status': 'active',
    });

    final assignments = await FirebaseCastRepository(
      firestore: firestore,
      identityProvider: TestIdentityProvider(
        const AuthIdentity(userId: 'cast-1', role: UserRole.cast),
      ),
    ).watchMyAssignments().first;

    expect(assignments, isEmpty);
  });

  test('public registration always creates a cast account', () async {
    final user = await FirebaseAuthService.demo().register(
      name: 'Public user',
      email: 'public@example.com',
      password: 'password123',
      role: UserRole.admin,
    );

    expect(user.role, UserRole.cast);
  });

  test('invalid profile roles fail closed', () {
    expect(userRoleFromValue('principal'), isNull);
    expect(
      () => AppUser.fromMap({
        'name': 'Invalid',
        'email': 'invalid@example.com',
        'role': 'principal',
      }, 'invalid-user'),
      throwsA(isA<FormatException>()),
    );
  });

  test('missing or invalid Firebase profiles cannot become identities', () {
    expect(
      () => firebaseIdentityFromProfile(
        userId: 'missing-user',
        exists: false,
        data: null,
      ),
      throwsA(isA<RevoException>()),
    );
    expect(
      () => firebaseIdentityFromProfile(
        userId: 'invalid-user',
        exists: true,
        data: {'role': 'principal'},
      ),
      throwsA(isA<RevoException>()),
    );
  });

  test('reports venue and cast conflicts for overlapping rehearsals', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('rehearsals').doc('existing').set({
      'productionId': 'production-1',
      'venueId': 'main-stage',
      'startAt': '2026-10-15T10:00:00.000Z',
      'endAt': '2026-10-15T12:00:00.000Z',
      'participantIds': ['cast-1'],
      'status': 'confirmed',
      'createdBy': 'director-1',
      'createdAt': '2026-10-01T00:00:00.000Z',
      'updatedAt': '2026-10-01T00:00:00.000Z',
    });

    final result =
        await FirebaseRehearsalRepository(
          firestore: firestore,
          identityProvider: TestIdentityProvider(
            const AuthIdentity(
              userId: 'director-1',
              role: UserRole.director,
              isFirebaseAuthenticated: true,
            ),
          ),
        ).createRehearsal(
          RehearsalInput(
            productionId: 'production-1',
            venueId: 'main-stage',
            startAt: DateTime.utc(2026, 10, 15, 11),
            endAt: DateTime.utc(2026, 10, 15, 13),
            participantIds: const ['cast-1'],
          ),
        );

    expect(result.rehearsal, isNull);
    expect(result.conflicts.map((conflict) => conflict.type), [
      ConflictType.venue,
      ConflictType.cast,
    ]);
  });

  test(
    'synchronizes rehearsal additions, updates, and cancellations',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = FirebaseScheduleService(
        firestore: firestore,
        identityProvider: TestIdentityProvider(
          const AuthIdentity(userId: 'director-1', role: UserRole.director),
        ),
      );
      final snapshots = <ScheduleSnapshot>[];
      final subscription = service
          .watchProductionSchedule('production-1')
          .listen(snapshots.add);

      final rehearsal = {
        'productionId': 'production-1',
        'venueId': 'main-stage',
        'startAt': '2026-10-15T10:00:00.000Z',
        'endAt': '2026-10-15T12:00:00.000Z',
        'participantIds': ['director-1'],
        'status': 'confirmed',
        'clientPending': false,
        'createdBy': 'director-1',
        'createdAt': '2026-10-01T00:00:00.000Z',
        'updatedAt': '2026-10-01T00:00:00.000Z',
      };
      await firestore
          .collection('rehearsals')
          .doc('rehearsal-1')
          .set(rehearsal);
      await pumpEventQueue();
      expect(snapshots.last.items.single.rehearsalId, 'rehearsal-1');

      await firestore.collection('rehearsals').doc('rehearsal-1').update({
        'startAt': '2026-10-15T13:00:00.000Z',
      });
      await pumpEventQueue();
      expect(
        snapshots.last.items.single.startAt,
        DateTime.utc(2026, 10, 15, 13),
      );

      await firestore.collection('rehearsals').doc('rehearsal-1').update({
        'status': 'cancelled',
      });
      await pumpEventQueue();
      expect(snapshots.last.items, isEmpty);

      await subscription.cancel();
      await service.dispose();
    },
  );

  test(
    'schedule service remains usable when Firebase is uninitialized',
    () async {
      final service = FirebaseScheduleService();

      final snapshot = await service
          .watchProductionSchedule('production-1')
          .first;

      expect(snapshot.items, isEmpty);
      expect(snapshot.syncState, SyncState.synced);
      await service.dispose();
    },
  );
}
