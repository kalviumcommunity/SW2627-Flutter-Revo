import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/core/theme/revo_theme.dart';
import 'package:sw2627_flutter_revo_1/features/admin/admin_dashboard.dart';
import 'package:sw2627_flutter_revo_1/features/admin/venue_management_screen.dart';
import 'package:sw2627_flutter_revo_1/features/common/production_detail_screen.dart';
import 'package:sw2627_flutter_revo_1/features/common/production_list_screen.dart';
import 'package:sw2627_flutter_revo_1/features/director/director_dashboard.dart';
import 'package:sw2627_flutter_revo_1/features/director/director_interview_screen.dart';
import 'package:sw2627_flutter_revo_1/models/app_user.dart';
import 'package:sw2627_flutter_revo_1/services/mock_data_service.dart';
import 'package:sw2627_flutter_revo_1/services/mock_production_repository.dart';
import 'package:sw2627_flutter_revo_1/services/mock_venue_repository.dart';
import 'package:sw2627_flutter_revo_1/services/production_repository.dart';
import 'package:sw2627_flutter_revo_1/services/venue_repository.dart';

void main() {
  late ProductionRepository productionRepository;
  late VenueRepository venueRepository;

  final directorUser = AppUser(
    userId: 'usr_dir_101',
    name: 'Sarah Jenkins',
    email: 'director@revo.com',
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

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: RevoTheme.lightTheme,
      home: child,
    );
  }

  setUp(() {
    MockDataService().reset();
    productionRepository = MockProductionRepository();
    venueRepository = MockVenueRepository();
  });

  group('AdminDashboard Widget Tests (Issue #13)', () {
    testWidgets('Renders Admin identity and derived metrics tiles', (tester) async {
      await tester.pumpWidget(createTestWidget(AdminDashboard(user: adminUser)));
      await tester.pumpAndSettle();

      expect(find.text('Theatre Admin Portal'), findsOneWidget);
      expect(find.text('Administrator: Theatre Admin'), findsOneWidget);
      expect(find.text('Productions'), findsOneWidget);
      expect(find.text('Venues'), findsOneWidget);
      expect(find.text('Rehearsals'), findsOneWidget);
      expect(find.text('Cast Assigned'), findsOneWidget);

      // Verify management navigation cards
      expect(find.text('Productions Catalog & Scheduling'), findsOneWidget);
      expect(find.text('Venue Catalog & Availability'), findsOneWidget);
      expect(find.text('PRD Baseline Evidence & Interview'), findsOneWidget);
    });
  });

  group('DirectorDashboard Widget Tests (Issue #13)', () {
    testWidgets('Renders assigned production overview and upcoming rehearsals', (tester) async {
      await tester.pumpWidget(createTestWidget(DirectorDashboard(user: directorUser)));
      await tester.pumpAndSettle();

      expect(find.text('Director Portal'), findsOneWidget);
      expect(find.text('Welcome back, Sarah Jenkins!'), findsOneWidget);
      expect(find.text('ASSIGNED TO 2 PRODUCTIONS'), findsOneWidget);

      // Primary production feature
      expect(find.text('The Crucible'), findsWidgets);
      expect(find.text('0 Schedule Conflicts (BR-01..05)'), findsOneWidget);

      // Director workflow cards
      expect(find.text('Auditions & Casting'), findsOneWidget);
      expect(find.text('Role Assignments'), findsOneWidget);
      expect(find.text('Production Schedule (FR-09, FR-10)'), findsOneWidget);
    });
  });

  group('ProductionListScreen Widget Tests (Issue #13)', () {
    testWidgets('Director sees only their assigned productions', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ProductionListScreen(
          user: directorUser,
          productionRepository: productionRepository,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('The Crucible'), findsOneWidget);
      expect(find.text('A Midsummer Night’s Dream'), findsOneWidget);
      // Hamlet belongs to Marcus Vance (usr_dir_102), so it must NOT be visible to Sarah
      expect(find.text('Hamlet'), findsNothing);
    });

    testWidgets('Admin browses all productions in theatre catalog', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ProductionListScreen(
          user: adminUser,
          productionRepository: productionRepository,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('The Crucible'), findsOneWidget);
      expect(find.text('A Midsummer Night’s Dream'), findsOneWidget);
      expect(find.text('Hamlet'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('The Glass Menagerie'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('The Glass Menagerie'), findsOneWidget);
    });
  });

  group('ProductionDetailScreen Widget Tests (Issue #13)', () {
    testWidgets('Displays production details, cast assignments, and rehearsals', (tester) async {
      final crucible = await productionRepository.getProduction('prod_101');
      expect(crucible, isNotNull);

      await tester.pumpWidget(
        createTestWidget(
          ProductionDetailScreen(
            production: crucible!,
            user: directorUser,
            productionRepository: productionRepository,
            venueRepository: venueRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('The Crucible'), findsWidgets);
      expect(find.text('DIRECTOR'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsWidgets);

      // Cast roles
      expect(find.text('John Proctor'), findsOneWidget);
      expect(find.text('Abigail Williams'), findsOneWidget);
      expect(find.text('Alex Rivera'), findsWidgets);

      // Upcoming rehearsals
      expect(find.text('Upcoming Rehearsals'), findsOneWidget);
      expect(find.text('Associated Venues'), findsOneWidget);
    });
  });

  group('VenueManagementScreen Widget Tests (Issue #13)', () {
    testWidgets('Displays venue catalog with capacity and status', (tester) async {
      await tester.pumpWidget(createTestWidget(
        VenueManagementScreen(
          user: adminUser,
          venueRepository: venueRepository,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Venue Catalog & Management'), findsOneWidget);
      expect(find.text('Main Stage Auditorium'), findsOneWidget);
      expect(find.text('Studio A Rehearsal Hall'), findsOneWidget);
      expect(find.text('Studio B Black Box'), findsOneWidget);
      expect(find.text('Green Room Lab'), findsOneWidget);

      // Admin has Add Venue button
      expect(find.text('Add Venue'), findsWidgets);
    });
  });

  group('DirectorInterviewScreen Widget Tests (Issue #13)', () {
    testWidgets('Displays 3 tabs and evidence integrity notice', (tester) async {
      await tester.pumpWidget(createTestWidget(const DirectorInterviewScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Baseline & Director Interview'), findsOneWidget);
      expect(find.text('PRD Targets'), findsOneWidget);
      expect(find.text('Record Data'), findsOneWidget);
      expect(find.text('Current Record'), findsOneWidget);

      // Verify PRD target cards
      expect(find.text('Coordination Time Reduction'), findsOneWidget);
      expect(find.text('≥ 30%'), findsOneWidget);
      expect(find.text('Venue Double-Bookings'), findsOneWidget);
      expect(find.text('0 Conflicts'), findsOneWidget);

      // Switch to Current Record tab
      await tester.tap(find.text('Current Record'));
      await tester.pumpAndSettle();

      expect(find.text('RECORD VALIDATION STATUS'), findsOneWidget);
      expect(find.text('NOT STARTED (OUTSTANDING)'), findsWidgets);
      expect(find.textContaining('Uncollected'), findsWidgets);
    });
  });
}
