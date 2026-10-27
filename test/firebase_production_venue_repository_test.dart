import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/core/errors/revo_exception.dart';
import 'package:sw2627_flutter_revo_1/models/production.dart';
import 'package:sw2627_flutter_revo_1/models/venue.dart';
import 'package:sw2627_flutter_revo_1/services/firebase_auth_service.dart';
import 'package:sw2627_flutter_revo_1/data/firebase/firebase_production_repository.dart';
import 'package:sw2627_flutter_revo_1/data/firebase/firebase_venue_repository.dart';

void main() {
  final authService = FirebaseAuthService.demo();

setUp(() async {
  await authService.logout();
});

  Future<void> loginAs(String email) =>
      authService.login(email: email, password: 'password123').then((_) {});

  ProductionInput productionInput() => ProductionInput(
    name: 'Hamlet',
    description: 'A production',
    startDate: DateTime.utc(2026, 10, 1),
    endDate: DateTime.utc(2026, 10, 3),
    status: ProductionStatus.planning,
  );

  test('creates, updates, and deletes an assigned production', () async {
    await loginAs('director@revo.com');
    final firestore = FakeFirebaseFirestore();
    final repository = FirebaseProductionRepository(
      firestore: firestore,
      authService: authService,
    );

    final created = await repository.createProduction(productionInput());
    expect(created.directorId, 'dir_101');

    await repository.updateProduction(
      created.productionId,
      ProductionInput(
        name: 'Hamlet Updated',
        description: 'Updated',
        startDate: created.startDate,
        endDate: created.endDate,
        status: ProductionStatus.rehearsing,
      ),
    );
    expect(
      (await repository.getProduction(created.productionId))!.name,
      'Hamlet Updated',
    );

    await repository.deleteProduction(created.productionId);
    expect(await repository.getProduction(created.productionId), isNull);
  });

  test('rejects a director changing another director production', () async {
    await loginAs('director@revo.com');
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('productions').doc('other').set({
      'name': 'Other production',
      'description': 'A production',
      'startDate': '2026-10-01T00:00:00.000Z',
      'endDate': '2026-10-03T00:00:00.000Z',
      'createdAt': '2026-09-01T00:00:00.000Z',
      'updatedAt': '2026-09-01T00:00:00.000Z',
      'status': 'planning',
      'directorId': 'usr_dir_102',
    });
    final repository = FirebaseProductionRepository(
      firestore: firestore,
      authService: authService,
    );

    await expectLater(
      repository.updateProduction('other', productionInput()),
      throwsA(
        isA<RevoException>().having(
          (error) => error.code,
          'code',
          RevoErrorCode.permissionDenied,
        ),
      ),
    );
  });

  test('enforces venue admin authorization and validation', () async {
    final repository = FirebaseVenueRepository(
      firestore: FakeFirebaseFirestore(),
      authService: authService,
    );
    await loginAs('director@revo.com');
    await expectLater(
      repository.createVenue(
        VenueInput(
          name: 'Stage',
          location: 'Theatre',
          capacity: 20,
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

    await loginAs('admin@revo.com');
    await expectLater(
      repository.createVenue(
        VenueInput(
          name: '',
          location: 'Theatre',
          capacity: 20,
          availability: const {},
        ),
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

  test(
    'reads Timestamp and string booking dates and protects deletion',
    () async {
      await loginAs('admin@revo.com');
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('venues').doc('venue-1').set({
        'name': 'Main Stage',
        'location': 'Theatre',
        'capacity': 100,
        'availability': const {},
        'status': 'active',
      });
      await firestore.collection('rehearsals').doc('timestamp-rehearsal').set({
        'venueId': 'venue-1',
        'productionId': 'production-1',
        'startAt': Timestamp.fromDate(DateTime.utc(2026, 10, 15, 10)),
        'endAt': Timestamp.fromDate(DateTime.utc(2026, 10, 15, 12)),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
        'status': 'confirmed',
      });
      await firestore.collection('rehearsals').doc('string-rehearsal').set({
        'venueId': 'venue-1',
        'productionId': 'production-1',
        'startAt': '2026-10-15T14:00:00.000Z',
        'endAt': '2026-10-15T16:00:00.000Z',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
        'status': 'confirmed',
      });

      final repository = FirebaseVenueRepository(
        firestore: firestore,
        authService: authService,
      );
      final bookings = await repository.getBookings(
        'venue-1',
        DateTime.utc(2026, 10, 15),
      );
      expect(bookings, hasLength(2));

      await expectLater(
        repository.deleteVenue('venue-1'),
        throwsA(
          isA<RevoException>().having(
            (error) => error.code,
            'code',
            RevoErrorCode.invalidInput,
          ),
        ),
      );
    },
  );

  test('reports not found for missing production and venue', () async {
    await loginAs('admin@revo.com');
    final firestore = FakeFirebaseFirestore();
    final productions = FirebaseProductionRepository(
      firestore: firestore,
      authService: authService,
    );
    final venues = FirebaseVenueRepository(
      firestore: firestore,
      authService: authService,
    );

    expect(await productions.getProduction('missing'), isNull);
    expect(await venues.getVenue('missing'), isNull);
    await expectLater(
      productions.deleteProduction('missing'),
      throwsA(isA<RevoException>()),
    );
    await expectLater(
      venues.deleteVenue('missing'),
      throwsA(isA<RevoException>()),
    );
  });
}
