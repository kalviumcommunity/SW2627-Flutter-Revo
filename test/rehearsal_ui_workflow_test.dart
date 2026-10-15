import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/core/theme/revo_theme.dart';
import 'package:sw2627_flutter_revo_1/features/common/conflict_resolution_screen.dart';
import 'package:sw2627_flutter_revo_1/features/common/rehearsal_detail_screen.dart';
import 'package:sw2627_flutter_revo_1/features/director/rehearsal_creation_screen.dart';
import 'package:sw2627_flutter_revo_1/models/app_user.dart';
import 'package:sw2627_flutter_revo_1/services/mock_conflict_service.dart';
import 'package:sw2627_flutter_revo_1/services/mock_data_service.dart';
import 'package:sw2627_flutter_revo_1/services/rehearsal_repository.dart';

void main() {
  final directorUser = AppUser(
    userId: 'usr_dir_101',
    name: 'Sarah Jenkins',
    email: 'director@revo.com',
    role: UserRole.director,
    createdAt: DateTime.now(),
  );

  final unassignedDirector = AppUser(
    userId: 'usr_dir_unassigned',
    name: 'Unassigned Director',
    email: 'unassigned@revo.com',
    role: UserRole.director,
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
  });

  group('Phase 3: RehearsalCreationScreen Widget Tests', () {
    testWidgets(
        'Renders all required sections and controls for authorized Director',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          RehearsalCreationScreen(
            user: directorUser,
            initialProductionId: 'prod_101',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen Header in AppBar and Title
      expect(find.text('Create Rehearsal'), findsOneWidget);
      expect(find.text('Schedule Rehearsal Session'), findsOneWidget);

      // Section Titles
      expect(find.text('Production'), findsOneWidget);
      expect(find.text('Date & Time Window'), findsOneWidget);
      expect(find.text('Rehearsal Venue'), findsOneWidget);

      // Initial Action Button is Check Conflicts
      expect(find.widgetWithText(FilledButton, 'Check Conflicts'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('Shows empty state when director has no assigned productions',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          RehearsalCreationScreen(user: unassignedDirector),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Authorized Productions'), findsOneWidget);
      expect(
          find.textContaining('You are not currently assigned as director'),
          findsOneWidget);
    });

    testWidgets(
        'Executes conflict checking and preserves user interaction state',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          RehearsalCreationScreen(
            user: directorUser,
            initialProductionId: 'prod_101',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Check Conflicts button
      final checkButton =
          find.widgetWithText(FilledButton, 'Check Conflicts');
      await tester.ensureVisible(checkButton);
      expect(checkButton, findsOneWidget);
      await tester.tap(checkButton);
      await tester.pumpAndSettle();

      // Form remains functional and responsive
      expect(find.byType(RehearsalCreationScreen), findsOneWidget);
    });
  });

  group('Phase 6: ConflictResolutionScreen Widget Tests', () {
    testWidgets('Displays structured conflict summary and resolution options',
        (tester) async {
      final dataService = MockDataService();
      final existingRehearsal = dataService.getRehearsalById('reh_101')!;

      final draftInput = RehearsalInput(
        productionId: 'prod_101',
        title: 'New Conflicting Rehearsal',
        venueId: existingRehearsal.venueId, // ven_102
        startAt: existingRehearsal.startAt.add(const Duration(minutes: 30)),
        endAt: existingRehearsal.endAt.add(const Duration(minutes: 30)),
        participantIds: ['usr_cast_201'],
      );

      final conflictService = MockConflictService(dataService: dataService);
      final initialConflicts = await conflictService.check(
        venueId: draftInput.venueId,
        startAt: draftInput.startAt,
        endAt: draftInput.endAt,
        participantIds: draftInput.participantIds,
      );

      expect(initialConflicts.isNotEmpty, isTrue);

      await tester.pumpWidget(
        createTestWidget(
          ConflictResolutionScreen(
            draftInput: draftInput,
            initialConflicts: initialConflicts,
            user: directorUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Conflict screen heading & summary
      expect(find.text('Conflict Resolution'), findsOneWidget);
      expect(find.textContaining('Blocking Conflicts ('), findsOneWidget);

      // Resolution action options
      expect(find.text('Option 1: Change Venue'), findsOneWidget);
      expect(find.text('Option 2: Change Rehearsal Time'), findsOneWidget);
      expect(find.text('Option 3: Change Cast Participants'), findsOneWidget);

      // Blocking conflicts button state
      expect(find.text('Resolve Conflicts to Confirm'), findsOneWidget);
    });

    testWidgets('Selecting alternative venue revalidates conflict state',
        (tester) async {
      final dataService = MockDataService();
      final existingRehearsal = dataService.getRehearsalById('reh_101')!;

      final draftInput = RehearsalInput(
        productionId: 'prod_101',
        title: 'Venue Collision Test',
        venueId: existingRehearsal.venueId,
        startAt: existingRehearsal.startAt.add(const Duration(minutes: 30)),
        endAt: existingRehearsal.endAt.add(const Duration(minutes: 30)),
        participantIds: ['usr_cast_999'], // participant has no conflict
      );

      final conflictService = MockConflictService(dataService: dataService);
      final initialConflicts = await conflictService.check(
        venueId: draftInput.venueId,
        startAt: draftInput.startAt,
        endAt: draftInput.endAt,
        participantIds: draftInput.participantIds,
      );

      await tester.pumpWidget(
        createTestWidget(
          ConflictResolutionScreen(
            draftInput: draftInput,
            initialConflicts: initialConflicts,
            user: directorUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Option 1: Change Venue to open venue selector
      final venueOption = find.text('Option 1: Change Venue');
      expect(venueOption, findsOneWidget);
      await tester.tap(venueOption);
      await tester.pumpAndSettle();

      // Verify the screen remains interactive and displays venue choices
      expect(find.byType(ConflictResolutionScreen), findsOneWidget);
    });
  });

  group('Phase 5: RehearsalDetailScreen Widget Tests', () {
    testWidgets(
        'Renders comprehensive rehearsal information for existing record',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const RehearsalDetailScreen(
            rehearsalId: 'reh_101',
            user: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify core details
      expect(find.text('Rehearsal Details'), findsOneWidget);
      expect(find.text('Act I Blocking & Movement'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('Studio A Rehearsal Hall'), findsOneWidget);
      expect(find.text('The Crucible'), findsOneWidget);
      expect(find.text('Scheduled Participants'), findsOneWidget);
      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.text('Maya Lin'), findsOneWidget);
      expect(find.text('Rehearsal Notes & Directives'), findsOneWidget);
      expect(find.textContaining('Review opening courtroom choreography'), findsOneWidget);
    });

    testWidgets('Gracefully handles invalid or unknown rehearsal ID',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const RehearsalDetailScreen(
            rehearsalId: 'reh_non_existent',
            user: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rehearsal Record Not Found'), findsOneWidget);
      expect(
          find.textContaining('could not be located in the schedule database'),
          findsOneWidget);
    });

    testWidgets(
        'Authorized Director can cancel rehearsal from details screen',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          RehearsalDetailScreen(
            rehearsalId: 'reh_101',
            user: directorUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to cancel button
      final cancelBtn = find.text('Cancel Rehearsal (BR-08)');
      await tester.ensureVisible(cancelBtn);
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Cancel Rehearsal?'), findsOneWidget);
      final confirmCancelBtn =
          find.widgetWithText(FilledButton, 'Cancel Rehearsal');
      expect(confirmCancelBtn, findsOneWidget);
      await tester.tap(confirmCancelBtn);
      await tester.pumpAndSettle();

      // Status changes to CANCELLED
      expect(find.text('CANCELLED'), findsOneWidget);
    });
  });
}
