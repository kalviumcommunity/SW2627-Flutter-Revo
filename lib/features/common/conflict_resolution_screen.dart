import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/enums/revo_enums.dart';
import '../../core/errors/revo_exception.dart';
import '../../models/app_user.dart';
import '../../models/rehearsal.dart';
import '../../models/venue.dart';
import '../../services/mock_conflict_service.dart';
import '../../services/mock_data_service.dart';
import '../../services/mock_rehearsal_repository.dart';
import '../../services/rehearsal_repository.dart';
import 'rehearsal_detail_screen.dart';

/// Legacy adapter model for pre-existing Issue #8 / Issue #13 invocations.
class RehearsalConflict {
  final ConflictType type;
  final String conflictingRehearsalId;
  final String description;
  final DateTime conflictStart;
  final DateTime conflictEnd;
  final String location;

  const RehearsalConflict({
    required this.type,
    required this.conflictingRehearsalId,
    required this.description,
    required this.conflictStart,
    required this.conflictEnd,
    required this.location,
  });
}

/// FR-07 & FR-08: Conflict Resolution Screen (Issue #21).
/// Explains why rehearsal confirmation is blocked, surfaces affected venue and
/// cast collisions in a structured layout, and provides interactive resolution
/// options: change venue, change rehearsal time, or remove/replace participants.
/// Revalidates conflicts deterministically on every change. Confirmation is
/// strictly blocked until all conflicts are cleared.
class ConflictResolutionScreen extends StatefulWidget {
  final RehearsalInput? draftInput;
  final List<Conflict>? initialConflicts;
  final Rehearsal? conflictingRehearsal;
  final RehearsalConflict? conflict;
  final AppUser? user;
  final ValueChanged<RehearsalInput>? onResolutionApplied;
  final VoidCallback? onResolved;

  /// Default constructor for both new interactive flow and legacy single conflict calls.
  const ConflictResolutionScreen({
    super.key,
    this.draftInput,
    this.initialConflicts,
    this.conflictingRehearsal,
    this.conflict,
    this.user,
    this.onResolutionApplied,
    this.onResolved,
  });

  /// Compatibility constructor for existing legacy callers passing a single conflict.
  factory ConflictResolutionScreen.legacy({
    Key? key,
    required Rehearsal conflictingRehearsal,
    required RehearsalConflict conflict,
    VoidCallback? onResolved,
  }) {
    return ConflictResolutionScreen(
      key: key,
      conflictingRehearsal: conflictingRehearsal,
      conflict: conflict,
      onResolved: onResolved,
    );
  }

  /// Compatibility constructor matching the original positional signature.
  factory ConflictResolutionScreen.fromLegacy({
    Key? key,
    required Rehearsal conflictingRehearsal,
    required RehearsalConflict conflict,
    VoidCallback? onResolved,
  }) = ConflictResolutionScreen.legacy;

  /// Standalone demo factory for testing & UI preview.
  factory ConflictResolutionScreen.demo() {
    final now = DateTime.now();
    final demoRehearsal = Rehearsal(
      rehearsalId: 'reh_demo_conflict',
      productionId: 'prod_101',
      venueId: 'ven_102', // Studio A Rehearsal Hall
      startAt: now.add(const Duration(days: 1, hours: 2)),
      endAt: now.add(const Duration(days: 1, hours: 5)),
      participantIds: const ['usr_cast_201'], // Alex Rivera
      status: RehearsalStatus.proposed,
      clientPending: false,
      createdBy: 'usr_dir_101',
      createdAt: now,
      updatedAt: now,
      title: 'Act I Courtroom Scene Blocking',
    );

    final demoConflict = RehearsalConflict(
      type: ConflictType.venue,
      conflictingRehearsalId: 'reh_101',
      description:
          'Studio A Rehearsal Hall is double-booked by "The Crucible" during this time window.',
      conflictStart: demoRehearsal.startAt,
      conflictEnd: demoRehearsal.endAt,
      location: 'Studio A Rehearsal Hall',
    );

    return ConflictResolutionScreen.legacy(
      conflictingRehearsal: demoRehearsal,
      conflict: demoConflict,
    );
  }

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  final MockDataService _dataService = MockDataService();
  final MockConflictService _conflictService = MockConflictService();
  final MockRehearsalRepository _rehearsalRepo = MockRehearsalRepository();

  late String _productionId;
  late String _venueId;
  late DateTime _startAt;
  late DateTime _endAt;
  late List<String> _participantIds;
  String? _title;
  String? _notes;

  List<Conflict> _currentConflicts = [];
  bool _isValidating = false;
  bool _isConfirming = false;
  String? _activeResolutionMode; // 'venue', 'time', 'participants', or null

  @override
  void initState() {
    super.initState();
    final resolvedDraft = widget.draftInput ??
        (widget.conflictingRehearsal != null
            ? RehearsalInput(
                productionId: widget.conflictingRehearsal!.productionId,
                venueId: widget.conflictingRehearsal!.venueId,
                startAt: widget.conflictingRehearsal!.startAt,
                endAt: widget.conflictingRehearsal!.endAt,
                participantIds: widget.conflictingRehearsal!.participantIds,
                title: widget.conflictingRehearsal!.title,
                notes: widget.conflictingRehearsal!.notes,
              )
            : RehearsalInput(
                productionId: 'prod_101',
                venueId: 'ven_102',
                startAt: DateTime.now().add(const Duration(days: 1, hours: 2)),
                endAt: DateTime.now().add(const Duration(days: 1, hours: 5)),
                participantIds: const ['usr_cast_201'],
              ));

    _productionId = resolvedDraft.productionId;
    _venueId = resolvedDraft.venueId;
    _startAt = resolvedDraft.startAt;
    _endAt = resolvedDraft.endAt;
    _participantIds = List.from(resolvedDraft.participantIds);
    _title = resolvedDraft.title;
    _notes = resolvedDraft.notes;

    if (widget.initialConflicts != null) {
      _currentConflicts = List.from(widget.initialConflicts!);
    } else if (widget.conflict != null) {
      _currentConflicts = [
        Conflict(
          type: widget.conflict!.type,
          resourceId: widget.conflict!.type == ConflictType.venue
              ? _venueId
              : (_participantIds.isNotEmpty ? _participantIds.first : 'resource_1'),
          resourceName: widget.conflict!.location,
          conflictingRehearsalId: widget.conflict!.conflictingRehearsalId,
          conflictingStart: widget.conflict!.conflictStart,
          conflictingEnd: widget.conflict!.conflictEnd,
          proposedStart: _startAt,
          proposedEnd: _endAt,
          severity: ConflictSeverity.blocking,
          explanation: widget.conflict!.description,
        ),
      ];
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  RehearsalInput get _currentDraftInput => RehearsalInput(
        productionId: _productionId,
        venueId: _venueId,
        startAt: _startAt,
        endAt: _endAt,
        participantIds: _participantIds,
        title: _title,
        notes: _notes,
      );

  Future<void> _revalidateConflicts() async {
    setState(() => _isValidating = true);

    final results = await _conflictService.check(
      venueId: _venueId,
      startAt: _startAt,
      endAt: _endAt,
      participantIds: _participantIds,
    );

    if (mounted) {
      setState(() {
        _currentConflicts = results.where((c) => c.isBlocking).toList();
        _isValidating = false;
      });
    }
  }

  // ── Resolution Actions ─────────────────────────────────────────────────────

  void _selectAlternativeVenue(Venue venue) {
    setState(() {
      _venueId = venue.venueId;
      _activeResolutionMode = null;
    });
    _revalidateConflicts();
  }

  Future<void> _pickNewStartTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (pickedTime != null) {
      final newStart = DateTime(
        _startAt.year,
        _startAt.month,
        _startAt.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (newStart.isBefore(_endAt)) {
        setState(() {
          _startAt = newStart;
        });
        _revalidateConflicts();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Start time must be before end time.'),
              backgroundColor: RevoColors.errorCrimson,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickNewEndTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endAt),
    );
    if (pickedTime != null) {
      final newEnd = DateTime(
        _endAt.year,
        _endAt.month,
        _endAt.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (_startAt.isBefore(newEnd)) {
        setState(() {
          _endAt = newEnd;
        });
        _revalidateConflicts();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time.'),
              backgroundColor: RevoColors.errorCrimson,
            ),
          );
        }
      }
    }
  }

  void _shiftTimeHours(int deltaHours) {
    setState(() {
      _startAt = _startAt.add(Duration(hours: deltaHours));
      _endAt = _endAt.add(Duration(hours: deltaHours));
    });
    _revalidateConflicts();
  }

  void _toggleParticipant(String userId) {
    setState(() {
      if (_participantIds.contains(userId)) {
        _participantIds.remove(userId);
      } else {
        _participantIds.add(userId);
      }
    });
    _revalidateConflicts();
  }

  Future<void> _confirmResolvedRehearsal() async {
    if (_currentConflicts.isNotEmpty || _isValidating || _isConfirming) return;

    setState(() => _isConfirming = true);

    // Final safety revalidation immediately before persistence (FR-08)
    final freshConflicts = await _conflictService.check(
      venueId: _venueId,
      startAt: _startAt,
      endAt: _endAt,
      participantIds: _participantIds,
    );

    if (freshConflicts.isNotEmpty) {
      if (mounted) {
        setState(() {
          _currentConflicts = freshConflicts;
          _isConfirming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Scheduling blocked: Active conflicts still present. Resolve before confirming.'),
            backgroundColor: RevoColors.errorCrimson,
          ),
        );
      }
      return;
    }

    try {
      final result = await _rehearsalRepo.createRehearsal(_currentDraftInput,
          user: widget.user);

      if (mounted) {
        setState(() => _isConfirming = false);

        if (result.confirmed && result.rehearsal != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: RevoColors.successGreen,
              content: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 20),
                  const SizedBox(width: RevoSpacing.sm),
                  Expanded(
                    child: Text(
                      'Rehearsal confirmed with conflicts resolved!',
                      style: RevoTypography.bodyMedium
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );

          widget.onResolutionApplied?.call(_currentDraftInput);
          widget.onResolved?.call();

          // Navigate directly to Rehearsal Details (Phase 2 workflow)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RehearsalDetailScreen(
                rehearsalId: result.rehearsal!.rehearsalId,
                user: widget.user,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm rehearsal: $e'),
            backgroundColor: RevoColors.errorCrimson,
          ),
        );
      }
    }
  }

  void _applyAndReturn() {
    widget.onResolutionApplied?.call(_currentDraftInput);
    widget.onResolved?.call();
    Navigator.pop(context, _currentDraftInput);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasConflicts = _currentConflicts.isNotEmpty;
    final currentVenue = _dataService.getVenueById(_venueId);
    final allVenues = _dataService.getVenuesSync();
    final eligibleAssignments = _dataService
        .getCastAssignmentsForProduction(_productionId);

    return Scaffold(
      backgroundColor: RevoColors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Conflict Resolution'),
        leading: BackButton(
          onPressed: () {
            // User can go back, returning current inputs
            Navigator.pop(context, _currentDraftInput);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(RevoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Status Banner ──────────────────────────────────────────
            if (hasConflicts)
              _buildConflictDetectedBanner()
            else
              _buildConflictResolvedBanner(),

            const SizedBox(height: RevoSpacing.lg),

            // ── 2. Structured Conflict Cards ──────────────────────────────
            if (hasConflicts) ...[
              Text(
                'Blocking Conflicts (${_currentConflicts.length})',
                style:
                    RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: RevoSpacing.xs),
              Text(
                'Confirmation is blocked until every collision is resolved.',
                style: RevoTypography.caption
                    .copyWith(color: RevoColors.textSecondary),
              ),
              const SizedBox(height: RevoSpacing.md),
              ..._currentConflicts.map((c) => _buildConflictCard(c)),
              const SizedBox(height: RevoSpacing.xl),
            ],

            // ── 3. Resolution Controls Section ────────────────────────────
            Text(
              'Permitted Resolution Actions',
              style:
                  RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: RevoSpacing.xs),
            Text(
              'Select an option below to update parameters and revalidate conflicts.',
              style: RevoTypography.caption
                  .copyWith(color: RevoColors.textSecondary),
            ),
            const SizedBox(height: RevoSpacing.md),

            // Option 1: Change Venue Action Card
            _buildActionToggleCard(
              modeKey: 'venue',
              icon: Icons.location_on_outlined,
              title: 'Option 1: Change Venue',
              subtitle: 'Current: ${currentVenue?.name ?? _venueId}',
              consequence: 'Switches venue without altering schedule timing',
              isActive: _activeResolutionMode == 'venue',
              onTap: () {
                setState(() {
                  _activeResolutionMode =
                      _activeResolutionMode == 'venue' ? null : 'venue';
                });
              },
            ),
            if (_activeResolutionMode == 'venue') ...[
              const SizedBox(height: RevoSpacing.sm),
              _buildVenueSelector(allVenues),
            ],
            const SizedBox(height: RevoSpacing.md),

            // Option 2: Change Time Action Card
            _buildActionToggleCard(
              modeKey: 'time',
              icon: Icons.access_time_outlined,
              title: 'Option 2: Change Rehearsal Time',
              subtitle:
                  '${_formatDate(_startAt)} · ${_formatTime(_startAt)} – ${_formatTime(_endAt)}',
              consequence: 'Shift or adjust the rehearsal time window',
              isActive: _activeResolutionMode == 'time',
              onTap: () {
                setState(() {
                  _activeResolutionMode =
                      _activeResolutionMode == 'time' ? null : 'time';
                });
              },
            ),
            if (_activeResolutionMode == 'time') ...[
              const SizedBox(height: RevoSpacing.sm),
              _buildTimeSelector(),
            ],
            const SizedBox(height: RevoSpacing.md),

            // Option 3: Change Participants Action Card
            _buildActionToggleCard(
              modeKey: 'participants',
              icon: Icons.people_outline,
              title: 'Option 3: Change Cast Participants',
              subtitle: '${_participantIds.length} cast members selected',
              consequence: 'Remove or replace overlapping participants',
              isActive: _activeResolutionMode == 'participants',
              onTap: () {
                setState(() {
                  _activeResolutionMode =
                      _activeResolutionMode == 'participants'
                          ? null
                          : 'participants';
                });
              },
            ),
            if (_activeResolutionMode == 'participants') ...[
              const SizedBox(height: RevoSpacing.sm),
              _buildParticipantSelector(eligibleAssignments),
            ],
            const SizedBox(height: RevoSpacing.xxl),

            // ── 4. Confirmation / Return Action Bar ───────────────────────
            if (_isValidating)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: RevoSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: RevoSpacing.sm),
                      Text('Revalidating conflicts against schedule...'),
                    ],
                  ),
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _applyAndReturn,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: RevoSpacing.borderRadiusButton,
                      ),
                    ),
                    child: const Text('Apply & Return'),
                  ),
                ),
                const SizedBox(width: RevoSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: hasConflicts
                          ? theme.colorScheme.surfaceContainerHighest
                          : RevoColors.primary,
                      foregroundColor: hasConflicts
                          ? RevoColors.textMuted
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: RevoSpacing.borderRadiusButton,
                      ),
                    ),
                    onPressed: (!hasConflicts && !_isValidating && !_isConfirming)
                        ? _confirmResolvedRehearsal
                        : null,
                    icon: _isConfirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      hasConflicts
                          ? 'Resolve Conflicts to Confirm'
                          : (_isConfirming
                              ? 'Confirming...'
                              : 'Confirm Rehearsal'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RevoSpacing.sm),
            if (hasConflicts)
              Center(
                child: Text(
                  '⚠ Confirmation is disabled while blocking conflicts remain.',
                  style: RevoTypography.caption.copyWith(
                    color: RevoColors.errorCrimson,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildConflictDetectedBanner() {
    return Container(
      padding: const EdgeInsets.all(RevoSpacing.md),
      decoration: BoxDecoration(
        color: RevoColors.warningAmber.withValues(alpha: 0.1),
        borderRadius: RevoSpacing.borderRadiusCard,
        border: Border.all(
          color: RevoColors.warningAmber.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: RevoColors.warningAmber, size: 24),
          const SizedBox(width: RevoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCHEDULE CONFLICTS DETECTED',
                  style: RevoTypography.caption.copyWith(
                    color: const Color(0xFF946300),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currentConflicts.length} blocking collision${_currentConflicts.length != 1 ? 's' : ''} found. '
                  'A rehearsal cannot be confirmed while resources are double-booked.',
                  style: RevoTypography.bodyMedium.copyWith(
                    color: RevoColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictResolvedBanner() {
    return Container(
      padding: const EdgeInsets.all(RevoSpacing.md),
      decoration: BoxDecoration(
        color: RevoColors.successGreen.withValues(alpha: 0.1),
        borderRadius: RevoSpacing.borderRadiusCard,
        border: Border.all(
          color: RevoColors.successGreen.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle,
              color: RevoColors.successGreen, size: 24),
          const SizedBox(width: RevoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALL CONFLICTS RESOLVED',
                  style: RevoTypography.caption.copyWith(
                    color: RevoColors.successGreen,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All resource collisions have been cleared. This rehearsal is ready for confirmation.',
                  style: RevoTypography.bodyMedium.copyWith(
                    color: RevoColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictCard(Conflict conflict) {
    final isVenue = conflict.type == ConflictType.venue;
    final typeLabel = isVenue ? 'VENUE COLLISION' : 'CAST MEMBER OVERLAP';
    final typeColor =
        isVenue ? RevoColors.errorCrimson : const Color(0xFFB35A00);

    return Container(
      margin: const EdgeInsets.only(bottom: RevoSpacing.md),
      padding: const EdgeInsets.all(RevoSpacing.md),
      decoration: BoxDecoration(
        color: RevoColors.cardBackground,
        borderRadius: RevoSpacing.borderRadiusCard,
        border: Border.all(color: typeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: typeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'BLOCKING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: typeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: RevoSpacing.sm),
          Text(
            conflict.resourceName,
            style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w800),
          ),
          if (conflict.conflictingProductionName != null) ...[
            const SizedBox(height: 2),
            Text(
              'Conflicting Production: ${conflict.conflictingProductionName}',
              style: RevoTypography.caption
                  .copyWith(color: RevoColors.textSecondary),
            ),
          ],
          const SizedBox(height: RevoSpacing.sm),
          Text(
            conflict.explanation ?? 'Resource is double-booked.',
            style: RevoTypography.bodyMedium.copyWith(
              color: RevoColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: RevoSpacing.md),

          // Comparison Bar: Conflicting Booking vs Proposed Booking
          Container(
            padding: const EdgeInsets.all(RevoSpacing.sm),
            decoration: BoxDecoration(
              color: RevoColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXISTING BOOKING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatTime(conflict.conflictingStart)} – ${_formatTime(conflict.conflictingEnd)}',
                        style: RevoTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: RevoColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 24,
                  width: 1,
                  color: RevoColors.borderDefault,
                ),
                const SizedBox(width: RevoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROPOSED CALL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: RevoColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatTime(_startAt)} – ${_formatTime(_endAt)}',
                        style: RevoTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: RevoColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionToggleCard({
    required String modeKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required String consequence,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: RevoSpacing.borderRadiusCard,
      child: Container(
        padding: const EdgeInsets.all(RevoSpacing.md),
        decoration: BoxDecoration(
          color: isActive
              ? RevoColors.primary.withValues(alpha: 0.06)
              : RevoColors.cardBackground,
          borderRadius: RevoSpacing.borderRadiusCard,
          border: Border.all(
            color: isActive ? RevoColors.primary : RevoColors.borderDefault,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isActive
                  ? RevoColors.primary.withValues(alpha: 0.15)
                  : RevoColors.surfaceContainerHigh,
              child: Icon(
                icon,
                color: isActive ? RevoColors.primary : RevoColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: RevoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RevoTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? RevoColors.primary
                          : RevoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: RevoTypography.caption
                        .copyWith(color: RevoColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    consequence,
                    style: RevoTypography.caption.copyWith(
                      color: RevoColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isActive ? Icons.expand_less : Icons.expand_more,
              color: isActive ? RevoColors.primary : RevoColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueSelector(List<Venue> allVenues) {
    return Container(
      padding: const EdgeInsets.all(RevoSpacing.md),
      decoration: BoxDecoration(
        color: RevoColors.cardBackground,
        borderRadius: RevoSpacing.borderRadiusCard,
        border: Border.all(color: RevoColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Alternative Venue',
            style:
                RevoTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: RevoSpacing.sm),
          ...allVenues.map((v) {
            final isSelected = v.venueId == _venueId;
            final isCurrentConflicted = _currentConflicts.any(
                (c) => c.type == ConflictType.venue && c.resourceId == v.venueId);

            return InkWell(
              onTap: () => _selectAlternativeVenue(v),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: RevoSpacing.xs),
                padding: const EdgeInsets.all(RevoSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? RevoColors.primary.withValues(alpha: 0.1)
                      : (isCurrentConflicted
                          ? RevoColors.errorCrimson.withValues(alpha: 0.05)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? RevoColors.primary
                        : RevoColors.borderDefault,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? RevoColors.primary
                          : RevoColors.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: RevoSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                v.name,
                                style: RevoTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isCurrentConflicted) ...[
                                const SizedBox(width: RevoSpacing.xs),
                                const Text(
                                  '• Conflicting',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: RevoColors.errorCrimson,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${v.location} · Capacity ${v.capacity}',
                            style: RevoTypography.caption
                                .copyWith(color: RevoColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(RevoSpacing.md),
      decoration: BoxDecoration(
        color: RevoColors.cardBackground,
        borderRadius: RevoSpacing.borderRadiusCard,
        border: Border.all(color: RevoColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adjust Proposed Time Slot',
            style:
                RevoTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: RevoSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickNewStartTime,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text('Start: ${_formatTime(_startAt)}'),
                ),
              ),
              const SizedBox(width: RevoSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickNewEndTime,
                  icon: const Icon(Icons.timer_outlined, size: 16),
                  label: Text('End: ${_formatTime(_endAt)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: RevoSpacing.sm),
          Row(
            children: [
              Text(
                'Quick Shift: ',
                style: RevoTypography.caption
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () => _shiftTimeHours(1),
                child: const Text('+1 Hour'),
              ),
              TextButton(
                onPressed: () => _shiftTimeHours(2),
                child: const Text('+2 Hours'),
              ),
              TextButton(
                onPressed: () => _shiftTimeHours(3),
                child: const Text('+3 Hours'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantSelector(List dynamicAssignments) {
    return Container(
      padding: const EdgeInsets.all(RevoSpacing.md),
      decoration: BoxDecoration(
        color: RevoColors.cardBackground,
        borderRadius: RevoSpacing.borderRadiusCard,
        border: Border.all(color: RevoColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage Participating Cast Members',
            style:
                RevoTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: RevoSpacing.xs),
          Text(
            'Remove conflicting actors from this specific call.',
            style: RevoTypography.caption
                .copyWith(color: RevoColors.textSecondary),
          ),
          const SizedBox(height: RevoSpacing.md),
          ...dynamicAssignments.map((assignment) {
            final userId = assignment.castMemberId as String;
            final isSelected = _participantIds.contains(userId);
            final actorName = _dataService.getUserName(userId);
            final role = _dataService.getRoleById(assignment.roleId as String);
            final hasConflict = _currentConflicts.any(
                (c) => c.type == ConflictType.cast && c.resourceId == userId);

            return InkWell(
              onTap: () => _toggleParticipant(userId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: isSelected
                          ? RevoColors.primary
                          : RevoColors.textTertiary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                actorName,
                                style: RevoTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (hasConflict) ...[
                                const SizedBox(width: RevoSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: RevoColors.errorCrimson
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'COLLISION',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: RevoColors.errorCrimson,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            role != null ? 'Role: ${role.name}' : 'Cast Member',
                            style: RevoTypography.caption
                                .copyWith(color: RevoColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
