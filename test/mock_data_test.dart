import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/models/app_user.dart';
import 'package:sw2627_flutter_revo_1/models/director_interview_record.dart';
import 'package:sw2627_flutter_revo_1/models/production.dart';
import 'package:sw2627_flutter_revo_1/services/mock_data_service.dart';

void main() {
  group('MockDataService Unit Tests (Issue #13)', () {
    late MockDataService dataService;

    final directorUser = AppUser(
      userId: 'usr_dir_101',
      name: 'Sarah Jenkins',
      email: 'director@revo.com',
      role: UserRole.director,
      createdAt: DateTime.now(),
    );

    final otherDirectorUser = AppUser(
      userId: 'usr_dir_102',
      name: 'Marcus Vance',
      email: 'marcus@revo.com',
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

    setUp(() {
      dataService = MockDataService();
      dataService.reset();
    });

    test('Initial seeded productions dataset has cross-referential integrity', () {
      final allProds = dataService.getProductionsForUserSync(adminUser);
      expect(allProds.length, 4);

      final prodIds = allProds.map((p) => p.productionId).toSet();
      expect(prodIds, containsAll(['prod_101', 'prod_102', 'prod_103', 'prod_104']));

      final crucible = dataService.getProductionById('prod_101');
      expect(crucible, isNotNull);
      expect(crucible!.name, 'The Crucible');
      expect(crucible.directorId, 'usr_dir_101');
      expect(crucible.status, ProductionStatus.rehearsing);
    });

    test('Role-based scoping enforces Director sees only assigned productions', () {
      final sarahProds = dataService.getProductionsForUserSync(directorUser);
      expect(sarahProds.length, 2);
      expect(
        sarahProds.map((p) => p.productionId).toSet(),
        {'prod_101', 'prod_102'},
      );

      final marcusProds = dataService.getProductionsForUserSync(otherDirectorUser);
      expect(marcusProds.length, 1);
      expect(marcusProds.first.productionId, 'prod_103');

      // Admin browses all productions
      final adminProds = dataService.getProductionsForUserSync(adminUser);
      expect(adminProds.length, 4);
    });

    test('Production creation adds new production and reflects in user query', () async {
      final input = ProductionInput(
        name: 'The Tempest',
        description: 'Shakespearean fantasy island play.',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 60)),
        status: ProductionStatus.planning,
      );

      final created = await dataService.createProduction(
        input: input,
        directorId: directorUser.userId,
      );

      expect(created.name, 'The Tempest');
      expect(created.directorId, directorUser.userId);

      final sarahProds = dataService.getProductionsForUserSync(directorUser);
      expect(sarahProds.length, 3);
      expect(sarahProds.any((p) => p.name == 'The Tempest'), isTrue);
    });

    test('Venue queries and status toggling behave consistently', () async {
      final venues = dataService.getVenuesSync();
      expect(venues.length, 4);

      final mainStage = dataService.getVenueById('ven_101');
      expect(mainStage, isNotNull);
      expect(mainStage!.name, 'Main Stage Auditorium');
      expect(mainStage.status, VenueStatus.active);

      // Toggle venue status
      await dataService.toggleVenueStatus('ven_101');
      final updated = dataService.getVenueById('ven_101');
      expect(updated!.status, VenueStatus.inactive);

      // Restore
      await dataService.toggleVenueStatus('ven_101');
      expect(dataService.getVenueById('ven_101')!.status, VenueStatus.active);
    });

    test('Admin metrics derive dynamically from underlying mock records', () {
      final metrics = dataService.getAdminMetrics();

      expect(metrics['totalProductions'], 4);
      // Active = rehearsing (1) + planning (1) + casting (1) = 3
      expect(metrics['activeProductions'], 3);
      expect(metrics['totalVenues'], 4);
      // 3 active, 1 maintenance
      expect(metrics['activeVenues'], 3);
      expect(metrics['upcomingRehearsals'], greaterThanOrEqualTo(3));
      // Alex Rivera & Maya Lin
      expect(metrics['totalCastMembers'], 2);
    });

    test('Director metrics derive scoped counts for assigned productions', () {
      final sarahMetrics = dataService.getDirectorMetrics('usr_dir_101');

      expect(sarahMetrics['myProductionsCount'], 2);
      expect(sarahMetrics['rehearsalsCount'], 3);
      expect(sarahMetrics['castCount'], 2);
      expect(sarahMetrics['primaryProduction'], isNotNull);
      expect((sarahMetrics['primaryProduction'] as Production).name, 'The Crucible');
    });

    test('Related entities lookup (roles, cast, venues, names) resolves cleanly', () {
      final roles = dataService.getRolesForProduction('prod_101');
      expect(roles.length, 3);
      expect(roles.map((r) => r.name), containsAll(['John Proctor', 'Abigail Williams', 'Elizabeth Proctor']));

      final assignments = dataService.getCastAssignmentsForProduction('prod_101');
      expect(assignments.length, 2);

      final venues = dataService.getVenuesForProduction('prod_101');
      expect(venues.length, 2);

      expect(dataService.getUserName('usr_dir_101'), 'Sarah Jenkins');
      expect(dataService.getUserName('usr_cast_201'), 'Alex Rivera');
      expect(dataService.getDirectorName('usr_dir_102'), 'Marcus Vance');
    });

    test('Director interview record template enforces evidence integrity', () {
      final template = dataService.getInterviewRecord();

      expect(template.status, InterviewValidationStatus.notStarted);
      expect(template.simultaneousProductions, isNull);
      expect(template.coordinationHoursPerWeek, isNull);
      expect(template.monetaryEstimate, isNull);
      expect(template.hasUncollectedFields, isTrue);

      // Save a draft
      final updated = template.copyWith(
        intervieweeName: 'Director John Doe',
        simultaneousProductions: 3,
        rehearsalsPerWeek: 10,
        status: InterviewValidationStatus.draft,
      );

      dataService.saveInterviewRecord(updated);
      final retrieved = dataService.getInterviewRecord();

      expect(retrieved.intervieweeName, 'Director John Doe');
      expect(retrieved.simultaneousProductions, 3);
      expect(retrieved.status, InterviewValidationStatus.draft);
      // Still has uncollected fields
      expect(retrieved.hasUncollectedFields, isTrue);
    });
  });
}
