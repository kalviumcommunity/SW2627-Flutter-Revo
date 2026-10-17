import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/core/errors/revo_exception.dart';
import 'package:sw2627_flutter_revo_1/models/app_user.dart';
import 'package:sw2627_flutter_revo_1/models/production.dart';
import 'package:sw2627_flutter_revo_1/models/venue.dart';
import 'package:sw2627_flutter_revo_1/services/mock_data_service.dart';
import 'package:sw2627_flutter_revo_1/services/mock_production_repository.dart';
import 'package:sw2627_flutter_revo_1/services/mock_venue_repository.dart';
import 'package:sw2627_flutter_revo_1/services/production_repository.dart';
import 'package:sw2627_flutter_revo_1/services/venue_repository.dart';

void main() {
  late ProductionRepository productionRepo;
  late VenueRepository venueRepo;

  final directorSarah = AppUser(
    userId: 'usr_dir_101',
    name: 'Sarah Jenkins',
    email: 'sarah@revo.com',
    role: UserRole.director,
    createdAt: DateTime(2026, 1, 1),
  );

  final directorMarcus = AppUser(
    userId: 'usr_dir_102',
    name: 'Marcus Vance',
    email: 'marcus@revo.com',
    role: UserRole.director,
    createdAt: DateTime(2026, 1, 1),
  );

  final adminUser = AppUser(
    userId: 'usr_admin_301',
    name: 'Theatre Admin',
    email: 'admin@revo.com',
    role: UserRole.admin,
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    MockDataService().reset();
    productionRepo = MockProductionRepository();
    venueRepo = MockVenueRepository();
  });

  group('ProductionRepository Tests (Issue #13 / Review #3)', () {
    test('getProductions returns all productions for Admin', () async {
      final productions = await productionRepo.getProductions(
        userId: adminUser.userId,
        role: adminUser.role,
      );
      expect(productions.length, 4);
      expect(productions.map((p) => p.name), containsAll([
        'The Crucible',
        'A Midsummer Night’s Dream',
        'Hamlet',
        'The Glass Menagerie',
      ]));
    });

    test('getProductions filters by directorId for Director', () async {
      final sarahProductions = await productionRepo.getProductions(
        userId: directorSarah.userId,
        role: directorSarah.role,
      );
      expect(sarahProductions.length, 2);
      expect(sarahProductions.every((p) => p.directorId == directorSarah.userId), isTrue);

      final marcusProductions = await productionRepo.getProductions(
        userId: directorMarcus.userId,
        role: directorMarcus.role,
      );
      expect(marcusProductions.length, 1);
      expect(marcusProductions.first.name, 'Hamlet');
    });

    test('getProduction returns production when found, null when missing', () async {
      final prod = await productionRepo.getProduction('prod_101');
      expect(prod, isNotNull);
      expect(prod!.name, 'The Crucible');

      final missing = await productionRepo.getProduction('prod_nonexistent_999');
      expect(missing, isNull);
    });

    test('createProduction adds a production and emits via watchProductions', () async {
      final initialCount = (await productionRepo.getProductions(
        userId: adminUser.userId,
        role: adminUser.role,
      )).length;

      final input = ProductionInput(
        name: 'Macbeth 2026',
        startDate: DateTime.now().add(const Duration(days: 30)),
        endDate: DateTime.now().add(const Duration(days: 90)),
        description: 'New Scottish play staging',
        status: ProductionStatus.planning,
      );

      final created = await productionRepo.createProduction(
        input,
        directorId: directorSarah.userId,
      );
      expect(created.name, 'Macbeth 2026');
      expect(created.directorId, directorSarah.userId);

      final updatedProductions = await productionRepo.getProductions(
        userId: adminUser.userId,
        role: adminUser.role,
      );
      expect(updatedProductions.length, initialCount + 1);
      expect(updatedProductions.any((p) => p.productionId == created.productionId), isTrue);
    });

    test('createProduction rejects empty name or invalid date range', () async {
      expect(
        productionRepo.createProduction(
          ProductionInput(
            name: '   ',
            description: 'Test',
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 5)),
          ),
          directorId: directorSarah.userId,
        ),
        throwsA(isA<RevoException>().having(
          (e) => e.code,
          'code',
          RevoErrorCode.invalidInput,
        )),
      );

      expect(
        productionRepo.createProduction(
          ProductionInput(
            name: 'Invalid Dates Play',
            description: 'Test',
            startDate: DateTime.now().add(const Duration(days: 10)),
            endDate: DateTime.now(), // End before start
          ),
          directorId: directorSarah.userId,
        ),
        throwsA(isA<RevoException>().having(
          (e) => e.code,
          'code',
          RevoErrorCode.invalidInput,
        )),
      );
    });

    test('updateProduction modifies fields and preserves integrity', () async {
      final updateInput = ProductionInput(
        name: 'The Crucible (Updated Title)',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 12, 1),
        description: 'Updated Description',
        status: ProductionStatus.rehearsing,
      );

      await productionRepo.updateProduction('prod_101', updateInput);
      final updated = await productionRepo.getProduction('prod_101');
      expect(updated, isNotNull);
      expect(updated!.name, 'The Crucible (Updated Title)');
      expect(updated.description, 'Updated Description');
      expect(updated.status, ProductionStatus.rehearsing);

      // Throws if production does not exist
      expect(
        productionRepo.updateProduction('invalid_id', updateInput),
        throwsA(isA<RevoException>().having(
          (e) => e.code,
          'code',
          RevoErrorCode.notFound,
        )),
      );
    });

    test('setStatus modifies status correctly', () async {
      await productionRepo.setStatus('prod_101', ProductionStatus.completed);
      final prod = await productionRepo.getProduction('prod_101');
      expect(prod!.status, ProductionStatus.completed);

      expect(
        productionRepo.setStatus('invalid_prod', ProductionStatus.planning),
        throwsA(isA<RevoException>().having(
          (e) => e.code,
          'code',
          RevoErrorCode.notFound,
        )),
      );
    });

    test('metadata queries return associated domain entities', () async {
      final directorName = await productionRepo.getDirectorName('usr_dir_101');
      expect(directorName, 'Sarah Jenkins');

      final unknownDirector = await productionRepo.getDirectorName('unknown');
      expect(unknownDirector, 'Team Member (unknown)');

      final roles = await productionRepo.getRolesForProduction('prod_101');
      expect(roles.isNotEmpty, isTrue);
      expect(roles.map((r) => r.name), contains('John Proctor'));

      final cast = await productionRepo.getCastAssignmentsForProduction('prod_101');
      expect(cast.isNotEmpty, isTrue);

      final rehearsals = await productionRepo.getRehearsalsForProduction('prod_101');
      expect(rehearsals.isNotEmpty, isTrue);

      final venues = await productionRepo.getVenuesForProduction('prod_101');
      expect(venues.isNotEmpty, isTrue);

      final userName = await productionRepo.getUserName('usr_cast_201');
      expect(userName, 'Alex Rivera');

      final venue = await productionRepo.getVenueById('ven_101');
      expect(venue, isNotNull);
      expect(venue!.name, 'Main Stage Auditorium');
    });
  });

  group('VenueRepository Tests (Issue #13 / Review #3)', () {
    test('getVenues returns all venues, activeOnly filters inactive', () async {
      final allVenues = await venueRepo.getVenues();
      expect(allVenues.length, 4);

      // Initially ven_101, 102, 103 are active; ven_104 is inactive
      final initialActive = await venueRepo.getVenues(activeOnly: true);
      expect(initialActive.length, 3);

      // Toggle ven_101 to inactive
      await venueRepo.toggleStatus('ven_101');
      final activeVenues = await venueRepo.getVenues(activeOnly: true);
      expect(activeVenues.any((v) => v.venueId == 'ven_101'), isFalse);
      expect(activeVenues.length, 2);
    });

    test('getVenue returns venue when found, null when missing', () async {
      final venue = await venueRepo.getVenue('ven_101');
      expect(venue, isNotNull);
      expect(venue!.name, 'Main Stage Auditorium');
      expect(venue.capacity, 350);

      final missing = await venueRepo.getVenue('nonexistent_ven');
      expect(missing, isNull);
    });

    test('createVenue creates new venue with active status', () async {
      final input = VenueInput(
        name: 'Annex Studio C',
        location: 'Basement Wing',
        capacity: 40,
        availability: {'days': 'Mon-Sun', 'hours': '8am-10pm'},
      );

      final created = await venueRepo.createVenue(input);
      expect(created.name, 'Annex Studio C');
      expect(created.status, VenueStatus.active);
      expect(created.capacity, 40);

      final allVenues = await venueRepo.getVenues();
      expect(allVenues.length, 5);
    });

    test('createVenue validates required fields', () async {
      expect(
        venueRepo.createVenue(
          VenueInput(
            name: '',
            location: 'Somewhere',
            capacity: 10,
            availability: {},
          ),
        ),
        throwsA(isA<RevoException>().having(
          (e) => e.code,
          'code',
          RevoErrorCode.invalidInput,
        )),
      );
    });

    test('updateVenue modifies venue properties', () async {
      final input = VenueInput(
        name: 'Main Stage Renovated',
        location: 'Building A, 1st Floor',
        capacity: 300,
        availability: {'hours': 'Mon-Sun'},
      );

      await venueRepo.updateVenue('ven_101', input);
      final updated = await venueRepo.getVenue('ven_101');
      expect(updated!.name, 'Main Stage Renovated');
      expect(updated.capacity, 300);

      expect(
        venueRepo.updateVenue('invalid_venue', input),
        throwsA(isA<RevoException>().having(
          (e) => e.code,
          'code',
          RevoErrorCode.notFound,
        )),
      );
    });

    test('toggleStatus switches active and inactive states', () async {
      final initial = await venueRepo.getVenue('ven_101');
      expect(initial!.status, VenueStatus.active);

      await venueRepo.toggleStatus('ven_101');
      final toggled = await venueRepo.getVenue('ven_101');
      expect(toggled!.status, VenueStatus.inactive);

      await venueRepo.toggleStatus('ven_101');
      final restored = await venueRepo.getVenue('ven_101');
      expect(restored!.status, VenueStatus.active);

      expect(
        venueRepo.toggleStatus('invalid_venue'),
        throwsA(isA<RevoException>().having(
          (e) => e.code,
          'code',
          RevoErrorCode.notFound,
        )),
      );
    });

    test('metadata queries return rehearsals, production names, and bookings', () async {
      final rehearsals = await venueRepo.getRehearsalsForVenue('ven_101');
      expect(rehearsals.isNotEmpty, isTrue);

      final prodName = await venueRepo.getProductionName('prod_101');
      expect(prodName, 'The Crucible');

      final unknownProd = await venueRepo.getProductionName('unknown');
      expect(unknownProd, 'Unknown Production');

      final today = DateTime.now();
      final bookings = await venueRepo.getBookings('ven_101', today);
      expect(bookings, isA<List>());
    });
  });

  group('Cross-screen Shared Consistency', () {
    test('Updates in ProductionRepository are seen across all repository consumers', () async {
      final repoInstance1 = MockProductionRepository();
      final repoInstance2 = MockProductionRepository();

      final original = await repoInstance1.getProduction('prod_101');
      expect(original!.name, 'The Crucible');

      await repoInstance1.updateProduction(
        'prod_101',
        ProductionInput(
          name: 'The Crucible - Special Edition',
          description: original.description,
          startDate: original.startDate,
          endDate: original.endDate,
        ),
      );

      final updatedInRepo2 = await repoInstance2.getProduction('prod_101');
      expect(updatedInRepo2!.name, 'The Crucible - Special Edition');
    });

    test('Updates in VenueRepository are seen across all repository consumers', () async {
      final venueRepo1 = MockVenueRepository();
      final venueRepo2 = MockVenueRepository();

      await venueRepo1.toggleStatus('ven_102');
      final v2 = await venueRepo2.getVenue('ven_102');
      expect(v2!.status, VenueStatus.inactive);
    });
  });
}
