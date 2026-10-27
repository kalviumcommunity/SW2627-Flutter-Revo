## Summary
Implements GitHub Issue #21 (FR-05: Rehearsal Scheduling, FR-08: Conflict Resolution).
Provides end-to-end rehearsal scheduling, deterministic conflict detection, interactive resolution, rehearsal details, and authorized cancellation.

## Key Changes
- **Conflict Detection Engine (`MockConflictService`)**: Deterministic interval-overlap checking (`start1 < end2 && start2 < end1`) on the same calendar day. Differentiates venue vs cast conflicts, excludes cancelled rehearsals (`RehearsalStatus.cancelled`), and ignores self-rehearsal (`excludeRehearsalId`).
- **Rehearsal Creation (`RehearsalCreationScreen`)**: Scoped to assigned productions for Directors (all for Admins, denied for Actors). Includes date/time pickers, venue selection, participant checklist, and pre-confirmation conflict validation.
- **Interactive Conflict Resolution (`ConflictResolutionScreen`)**: Allows selecting an alternative available venue, adjusting time slots, or removing conflicting cast members, with real-time re-validation.
- **Rehearsal Details & Cancellation (`RehearsalDetailScreen`)**: Displays full metadata, venue details, participant roster, and role-authorized rehearsal cancellation (`BR-08`).
- **Data & Architecture**: Added `RehearsalRepository` interface and `MockRehearsalRepository` implementation with validation rules. Enhanced `MockDataService` with reactive streams and cancelled seed rehearsal (`reh_105_cancelled`).
- **Integrations**: Integrated with `DirectorDashboard` and `DirectorProductionScheduleScreen`.

## Verification & Tests
- `flutter analyze`: 0 issues
- `flutter test`: 77/77 tests passed (16 conflict unit tests, 8 workflow widget tests)
