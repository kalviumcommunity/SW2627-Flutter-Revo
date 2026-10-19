import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/enums/revo_enums.dart';
import '../../core/errors/revo_exception.dart';
import '../../core/widgets/app_status_state.dart';
import '../../models/app_user.dart';
import '../../models/production.dart';
import '../../services/mock_conflict_service.dart';
import '../../services/mock_data_service.dart';
import '../../services/mock_rehearsal_repository.dart';
import '../../services/rehearsal_repository.dart';
import '../common/conflict_resolution_screen.dart';
import '../common/rehearsal_detail_screen.dart';

/// FR-05, FR-08 & Phase 3: Rehearsal Creation Screen (Issue #21).
/// Enables Directors and Admins to configure and schedule rehearsals with
/// pre-confirmation conflict checking, venue availability inspection,
/// cast member assignment rosters, and direct conflict resolution routing.
class RehearsalCreationScreen extends StatefulWidget {
  final AppUser user;
  final String? initialProductionId;
  final RehearsalRepository? rehearsalRepository;

  const RehearsalCreationScreen({
    super.key,
    required this.user,
    this.initialProductionId,
    this.rehearsalRepository,
  });

  @override
  State<RehearsalCreationScreen> createState() =>
      _RehearsalCreationScreenState();
}

class _RehearsalCreationScreenState extends State<RehearsalCreationScreen> {
  final MockDataService _dataService = MockDataService();
  final MockConflictService _conflictService = MockConflictService();
  late final RehearsalRepository _rehearsalRepo;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  List<Production> _eligibleProductions = [];
  Production? _selectedProduction;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 13, minute: 0);

  String? _selectedVenueId;
  final Set<String> _selectedParticipantIds = {};

  // Conflict validation state
  bool _isCheckingConflicts = false;
  bool _isConfirming = false;
  bool _hasCheckedConflicts = false;
  List<Conflict> _detectedConflicts = [];
  String? _timeErrorMessage;

  @override
  void initState() {
    super.initState();
    _rehearsalRepo = widget.rehearsalRepository ?? MockRehearsalRepository();
    _loadProductions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadProductions() {
    final prods = _dataService.getProductionsForUserSync(widget.user);
    _eligibleProductions = prods;

    if (widget.initialProductionId != null) {
      final match = prods.where(
        (p) => p.productionId == widget.initialProductionId,
      );
      if (match.isNotEmpty) {
        _selectedProduction = match.first;
      }
    }

    if (_selectedProduction == null && _eligibleProductions.isNotEmpty) {
      _selectedProduction = _eligibleProductions.first;
    }

    // Auto-select first venue if available
    final venues = _dataService.getVenuesSync();
    final activeVenues =
        venues.where((v) => v.status == VenueStatus.active).toList();
    if (activeVenues.isNotEmpty) {
      _selectedVenueId = activeVenues.first.venueId;
    }
  }

  DateTime get _startDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

  DateTime get _endDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

  String _formatTime(TimeOfDay tod) {
    final hour = tod.hour == 0 ? 12 : (tod.hour > 12 ? tod.hour - 12 : tod.hour);
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _invalidateConflictState() {
    if (_hasCheckedConflicts) {
      setState(() {
        _hasCheckedConflicts = false;
        _detectedConflicts = [];
      });
    }
  }

  bool _validateTimes() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (endMinutes <= startMinutes) {
      setState(() {
        _timeErrorMessage = 'End time must be after start time.';
      });
      return false;
    } else {
      setState(() {
        _timeErrorMessage = null;
      });
      return true;
    }
  }

  RehearsalInput _buildCurrentInput() {
    return RehearsalInput(
      productionId: _selectedProduction?.productionId ?? '',
      venueId: _selectedVenueId ?? '',
      startAt: _startDateTime,
      endAt: _endDateTime,
      participantIds: _selectedParticipantIds.toList(),
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );
  }

  Future<void> _checkConflicts() async {
    if (!_validateTimes()) return;

    if (_selectedProduction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an authorized production.'),
          backgroundColor: RevoColors.errorCrimson,
        ),
      );
      return;
    }

    if (_selectedVenueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rehearsal venue.'),
          backgroundColor: RevoColors.errorCrimson,
        ),
      );
      return;
    }

    setState(() {
      _isCheckingConflicts = true;
    });

    final conflicts = await _conflictService.check(
      venueId: _selectedVenueId!,
      startAt: _startDateTime,
      endAt: _endDateTime,
      participantIds: _selectedParticipantIds.toList(),
    );

    if (mounted) {
      setState(() {
        _isCheckingConflicts = false;
        _hasCheckedConflicts = true;
        _detectedConflicts =
            conflicts.where((c) => c.isBlocking).toList();
      });
    }
  }

  void _openConflictResolutionScreen() {
    final input = _buildCurrentInput();

    Navigator.push<RehearsalInput>(
      context,
      MaterialPageRoute(
        builder: (context) => ConflictResolutionScreen(
          draftInput: input,
          initialConflicts: _detectedConflicts,
          user: widget.user,
          onResolutionApplied: (updatedInput) {
            _applyResolvedInputs(updatedInput);
          },
        ),
      ),
    ).then((resolvedInput) {
      if (resolvedInput != null && mounted) {
        _applyResolvedInputs(resolvedInput);
      }
    });
  }

  void _applyResolvedInputs(RehearsalInput updated) {
    setState(() {
      _selectedVenueId = updated.venueId;
      _selectedDate = DateTime(
        updated.startAt.year,
        updated.startAt.month,
        updated.startAt.day,
      );
      _startTime = TimeOfDay(
        hour: updated.startAt.hour,
        minute: updated.startAt.minute,
      );
      _endTime = TimeOfDay(
        hour: updated.endAt.hour,
        minute: updated.endAt.minute,
      );
      _selectedParticipantIds.clear();
      _selectedParticipantIds.addAll(updated.participantIds);
      if (updated.title != null) _titleController.text = updated.title!;
      if (updated.notes != null) _notesController.text = updated.notes!;
    });
    // Immediately re-check conflicts with updated inputs
    _checkConflicts();
  }

  Future<void> _confirmRehearsal() async {
    if (!_validateTimes() || _isConfirming || _isCheckingConflicts) return;

    if (_selectedProduction == null || _selectedVenueId == null) return;

    setState(() => _isConfirming = true);

    // Final safety revalidation immediately before persistence (FR-08, Phase 4 E)
    final freshConflicts = await _conflictService.check(
      venueId: _selectedVenueId!,
      startAt: _startDateTime,
      endAt: _endDateTime,
      participantIds: _selectedParticipantIds.toList(),
    );

    final blocking = freshConflicts.where((c) => c.isBlocking).toList();
    if (blocking.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
          _hasCheckedConflicts = true;
          _detectedConflicts = blocking;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Scheduling blocked: Active conflicts detected. Please resolve them first.'),
            backgroundColor: RevoColors.errorCrimson,
          ),
        );
      }
      return;
    }

    try {
      final input = _buildCurrentInput();
      final result =
          await _rehearsalRepo.createRehearsal(input, user: widget.user);

      if (mounted) {
        setState(() => _isConfirming = false);

        if (result.confirmed && result.rehearsal != null) {
          final isPending = result.rehearsal!.clientPending;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: isPending
                  ? const Color(0xFF946300)
                  : RevoColors.successGreen,
              content: Row(
                children: [
                  Icon(
                      isPending ? Icons.upload_outlined : Icons.check_circle,
                      color: Colors.white,
                      size: 20),
                  const SizedBox(width: RevoSpacing.sm),
                  Expanded(
                    child: Text(isPending
                        ? 'Rehearsal saved locally (Pending sync — awaiting connection).'
                        : 'Rehearsal successfully scheduled and confirmed!'),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );

          // Phase 2 Workflow: Confirm Rehearsal → Rehearsal Details
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

  @override
  Widget build(BuildContext context) {
    final isRoleDirector = widget.user.role == UserRole.director;

    if (_eligibleProductions.isEmpty) {
      return Scaffold(
        backgroundColor: RevoColors.surfaceContainerLowest,
        appBar: AppBar(title: const Text('Create Rehearsal')),
        body: Center(
          child: AppStatusState.empty(
            title: 'No Authorized Productions',
            message: isRoleDirector
                ? 'You are not currently assigned as director to any productions. You must be assigned to a production before scheduling rehearsals.'
                : 'No active productions found in the theatre catalog.',
          ),
        ),
      );
    }

    final allVenues = _dataService.getVenuesSync();
    final eligibleAssignments = _selectedProduction != null
        ? _dataService.getCastAssignmentsForProduction(
            _selectedProduction!.productionId)
        : [];

    final hasBlockingConflicts =
        _hasCheckedConflicts && _detectedConflicts.isNotEmpty;
    final isSafeToConfirm =
        _hasCheckedConflicts && _detectedConflicts.isEmpty;

    return Scaffold(
      backgroundColor: RevoColors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Create Rehearsal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(RevoSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Screen Header & Context ──────────────────────────────────
              Text(
                'Schedule Rehearsal Session',
                style: RevoTypography.headline2
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Configure production, venue, timing, and participants with automated conflict checking.',
                style: RevoTypography.bodyMedium
                    .copyWith(color: RevoColors.textSecondary),
              ),
              const SizedBox(height: RevoSpacing.lg),

              // ── Conflict Engine Status Banner ────────────────────────────
              if (hasBlockingConflicts) ...[
                _buildConflictAlertBanner(),
                const SizedBox(height: RevoSpacing.lg),
              ] else if (isSafeToConfirm) ...[
                _buildConflictSafeBanner(),
                const SizedBox(height: RevoSpacing.lg),
              ],

              // ── Section 1: Production Selection ─────────────────────────
              _buildSectionCard(
                title: 'Production',
                icon: Icons.movie_creation_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Production>(
                      initialValue: _selectedProduction,
                      decoration: const InputDecoration(
                        labelText: 'Select Production *',
                        prefixIcon: Icon(Icons.theater_comedy),
                        border: OutlineInputBorder(),
                      ),
                      items: _eligibleProductions.map((prod) {
                        return DropdownMenuItem<Production>(
                          value: prod,
                          child: Text(
                            prod.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (newProd) {
                        if (newProd != null &&
                            newProd.productionId !=
                                _selectedProduction?.productionId) {
                          setState(() {
                            _selectedProduction = newProd;
                            // Clean up participants not in the new production
                            final newValidAssignments = _dataService
                                .getCastAssignmentsForProduction(
                                    newProd.productionId);
                            final validCastIds = newValidAssignments
                                .map((a) => a.castMemberId)
                                .toSet();
                            _selectedParticipantIds
                                .removeWhere((id) => !validCastIds.contains(id));
                          });
                          _invalidateConflictState();
                        }
                      },
                    ),
                    if (isRoleDirector) ...[
                      const SizedBox(height: RevoSpacing.xs),
                      Text(
                        'Filtered to productions you are assigned to direct.',
                        style: RevoTypography.caption
                            .copyWith(color: RevoColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: RevoSpacing.md),

              // ── Section 2: Date & Timing ─────────────────────────────────
              _buildSectionCard(
                title: 'Date & Time Window',
                icon: Icons.calendar_month_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Picker Tile
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                          _invalidateConflictState();
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(RevoSpacing.md),
                        decoration: BoxDecoration(
                          color: RevoColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: RevoColors.borderDefault),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, color: RevoColors.primary),
                            const SizedBox(width: RevoSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rehearsal Date *',
                                    style: RevoTypography.caption.copyWith(
                                      color: RevoColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(_selectedDate),
                                    style: RevoTypography.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_calendar, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: RevoSpacing.md),

                    // Time Window Selectors
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (picked != null) {
                                setState(() => _startTime = picked);
                                _validateTimes();
                                _invalidateConflictState();
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(RevoSpacing.sm),
                              decoration: BoxDecoration(
                                color: RevoColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: RevoColors.borderDefault),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Time *',
                                    style: RevoTypography.caption.copyWith(
                                      color: RevoColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTime(_startTime),
                                        style:
                                            RevoTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: RevoSpacing.md),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (picked != null) {
                                setState(() => _endTime = picked);
                                _validateTimes();
                                _invalidateConflictState();
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(RevoSpacing.sm),
                              decoration: BoxDecoration(
                                color: RevoColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: RevoColors.borderDefault),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Time *',
                                    style: RevoTypography.caption.copyWith(
                                      color: RevoColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTime(_endTime),
                                        style:
                                            RevoTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_timeErrorMessage != null) ...[
                      const SizedBox(height: RevoSpacing.xs),
                      Text(
                        _timeErrorMessage!,
                        style: RevoTypography.caption.copyWith(
                          color: RevoColors.errorCrimson,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: RevoSpacing.md),

              // ── Section 3: Venue Selection ──────────────────────────────
              _buildSectionCard(
                title: 'Rehearsal Venue',
                icon: Icons.location_on_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...allVenues.map((v) {
                      final isSelected = v.venueId == _selectedVenueId;
                      final isInactive = v.status != VenueStatus.active;
                      final isConflicted = _detectedConflicts.any(
                        (c) =>
                            c.type == ConflictType.venue &&
                            c.resourceId == v.venueId,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: RevoSpacing.xs),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? RevoColors.primary.withValues(alpha: 0.08)
                              : (isConflicted
                                  ? RevoColors.errorCrimson
                                      .withValues(alpha: 0.05)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? RevoColors.primary
                                : (isConflicted
                                    ? RevoColors.errorCrimson
                                        .withValues(alpha: 0.5)
                                    : RevoColors.borderDefault),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() => _selectedVenueId = v.venueId);
                            _invalidateConflictState();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isSelected
                                      ? RevoColors.primary
                                      : RevoColors.textTertiary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              v.name,
                                              style: RevoTypography.bodyMedium
                                                  .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (isInactive)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: RevoColors.errorCrimson
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'MAINTENANCE',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      RevoColors.errorCrimson,
                                                ),
                                              ),
                                            )
                                          else if (isConflicted)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: RevoColors.errorCrimson
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'CONFLICTING',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      RevoColors.errorCrimson,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${v.location} · Capacity ${v.capacity}',
                                        style: RevoTypography.caption.copyWith(
                                            color: RevoColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: RevoSpacing.md),

              // ── Section 4: Participant Selection ────────────────────────
              _buildSectionCard(
                title: 'Cast Participants',
                icon: Icons.people_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select cast members assigned to this production.',
                      style: RevoTypography.caption
                          .copyWith(color: RevoColors.textSecondary),
                    ),
                    const SizedBox(height: RevoSpacing.sm),
                    if (eligibleAssignments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(RevoSpacing.md),
                        decoration: BoxDecoration(
                          color: RevoColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 18, color: RevoColors.textMuted),
                            const SizedBox(width: RevoSpacing.sm),
                            Expanded(
                              child: Text(
                                'No cast members currently assigned to this production.',
                                style: RevoTypography.caption
                                    .copyWith(color: RevoColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Multi-select Checkboxes
                      ...eligibleAssignments.map((assignment) {
                        final userId = assignment.castMemberId as String;
                        final isSelected =
                            _selectedParticipantIds.contains(userId);
                        final actorName = _dataService.getUserName(userId);
                        final role = _dataService
                            .getRoleById(assignment.roleId as String);
                        final isConflicted = _detectedConflicts.any(
                          (c) =>
                              c.type == ConflictType.cast &&
                              c.resourceId == userId,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isConflicted
                                ? RevoColors.errorCrimson.withValues(alpha: 0.05)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isConflicted
                                  ? RevoColors.errorCrimson
                                      .withValues(alpha: 0.4)
                                  : RevoColors.borderDefault,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedParticipantIds.remove(userId);
                                } else {
                                  _selectedParticipantIds.add(userId);
                                }
                              });
                              _invalidateConflictState();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              actorName,
                                              style: RevoTypography.bodyMedium
                                                  .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (isConflicted) ...[
                                              const SizedBox(
                                                  width: RevoSpacing.xs),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: RevoColors.errorCrimson
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'COLLISION',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        RevoColors.errorCrimson,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          role != null
                                              ? 'Role: ${role.name}'
                                              : 'Cast Member',
                                          style: RevoTypography.caption
                                              .copyWith(
                                                  color:
                                                      RevoColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // Selected Chips with Clear/Delete
                      if (_selectedParticipantIds.isNotEmpty) ...[
                        const SizedBox(height: RevoSpacing.sm),
                        Text(
                          'Selected (${_selectedParticipantIds.length}):',
                          style: RevoTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: RevoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: RevoSpacing.xs),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _selectedParticipantIds.map((userId) {
                            final name = _dataService.getUserName(userId);
                            return Chip(
                              label: Text(name, style: const TextStyle(fontSize: 12)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () {
                                setState(() {
                                  _selectedParticipantIds.remove(userId);
                                });
                                _invalidateConflictState();
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: RevoSpacing.md),

              // ── Section 5: Optional Rehearsal Metadata ───────────────────
              _buildSectionCard(
                title: 'Optional Details',
                icon: Icons.notes_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Rehearsal Title / Objective',
                        hintText: 'e.g. Act I Blocking, Run-through',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: RevoSpacing.md),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Directives & Notes for Cast',
                        hintText: 'e.g. Please bring updated scripts and character shoes.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RevoSpacing.xl),

              // ── Section 6: Action Buttons ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: RevoSpacing.borderRadiusButton,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: RevoSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isSafeToConfirm
                            ? RevoColors.successGreen
                            : RevoColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: RevoSpacing.borderRadiusButton,
                        ),
                      ),
                      onPressed: (_isCheckingConflicts || _isConfirming)
                          ? null
                          : (isSafeToConfirm
                              ? _confirmRehearsal
                              : _checkConflicts),
                      icon: _isCheckingConflicts || _isConfirming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(isSafeToConfirm
                              ? Icons.check
                              : Icons.fact_check_outlined),
                      label: Text(
                        _isCheckingConflicts
                            ? 'Checking...'
                            : (_isConfirming
                                ? 'Confirming...'
                                : (isSafeToConfirm
                                    ? 'Confirm Rehearsal'
                                    : 'Check Conflicts')),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              if (hasBlockingConflicts) ...[
                const SizedBox(height: RevoSpacing.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: RevoColors.warningAmber,
                    foregroundColor: const Color(0xFF171B26),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: RevoSpacing.borderRadiusButton,
                    ),
                  ),
                  onPressed: _openConflictResolutionScreen,
                  icon: const Icon(Icons.build_outlined),
                  label: const Text(
                    'Resolve Blocking Conflicts',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: RevoSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper UI Components ───────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Material(
      color: RevoColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: RevoSpacing.borderRadiusCard,
        side: const BorderSide(color: RevoColors.borderDefault),
      ),
      child: Padding(
        padding: const EdgeInsets.all(RevoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: RevoColors.primary),
                const SizedBox(width: RevoSpacing.sm),
                Text(
                  title,
                  style: RevoTypography.title2
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: RevoSpacing.md),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildConflictAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(RevoSpacing.md),
      decoration: BoxDecoration(
        color: RevoColors.errorCrimson.withValues(alpha: 0.08),
        borderRadius: RevoSpacing.borderRadiusCard,
        border: Border.all(
          color: RevoColors.errorCrimson.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline,
                  color: RevoColors.errorCrimson, size: 22),
              const SizedBox(width: RevoSpacing.sm),
              Expanded(
                child: Text(
                  '${_detectedConflicts.length} Blocking Conflict${_detectedConflicts.length != 1 ? 's' : ''} Detected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: RevoColors.errorCrimson,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Confirmation is blocked because requested resources have double-bookings. Tap "Resolve Blocking Conflicts" to choose an alternative venue, time slot, or participant roster.',
            style: RevoTypography.caption.copyWith(
              color: RevoColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ..._detectedConflicts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• ${c.resourceName}: ${c.explanation}',
                style: RevoTypography.caption.copyWith(
                  color: RevoColors.errorCrimson,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictSafeBanner() {
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
        children: [
          const Icon(Icons.check_circle_outline,
              color: RevoColors.successGreen, size: 22),
          const SizedBox(width: RevoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '0 SCHEDULE CONFLICTS DETECTED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: RevoColors.successGreen,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All requested resources are free. Rehearsal is safe to confirm!',
                  style: RevoTypography.caption.copyWith(
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
}
