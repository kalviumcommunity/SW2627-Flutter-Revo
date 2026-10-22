import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/enums/revo_enums.dart';
import '../../core/widgets/app_status_state.dart';
import '../../models/app_user.dart';
import '../../models/rehearsal.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/mock_data_service.dart';
import '../../services/mock_production_repository.dart';
import '../../services/mock_rehearsal_repository.dart';
import '../../services/sync/sync_timestamp_formatter.dart';
import '../../services/sync_status_service.dart';
import 'production_detail_screen.dart';
import 'widgets/sync_status_indicators.dart';

/// FR-05, FR-08 & Phase 5: Rehearsal Details Screen (Issue #21).
/// Displays comprehensive rehearsal scheduling data, production attribution,
/// venue specifications, cast participation roster, and operational status.
class RehearsalDetailScreen extends StatefulWidget {
  final String rehearsalId;
  final Rehearsal? rehearsal;
  final AppUser? user;

  const RehearsalDetailScreen({
    super.key,
    required this.rehearsalId,
    this.rehearsal,
    this.user,
  });

  @override
  State<RehearsalDetailScreen> createState() => _RehearsalDetailScreenState();
}

class _RehearsalDetailScreenState extends State<RehearsalDetailScreen> {
  final MockDataService _dataService = MockDataService();
  final MockRehearsalRepository _rehearsalRepo = MockRehearsalRepository();
  final FirebaseAuthService _authService = FirebaseAuthService();

  Rehearsal? _rehearsal;
  AppUser? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rehearsal =
        widget.rehearsal ?? _dataService.getRehearsalById(widget.rehearsalId);
    _currentUser = widget.user;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_currentUser == null) {
      _currentUser = await _authService.currentUser();
      if (mounted) setState(() {});
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _calculateDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (minutes == 0) {
      return '$hours hr${hours != 1 ? 's' : ''}';
    }
    return '$hours hr${hours != 1 ? 's' : ''} $minutes min';
  }

  Color _getStatusColor(RehearsalStatus status) {
    switch (status) {
      case RehearsalStatus.confirmed:
        return RevoColors.successGreen;
      case RehearsalStatus.proposed:
        return RevoColors.warningAmber;
      case RehearsalStatus.cancelled:
        return RevoColors.errorCrimson;
    }
  }

  Future<void> _handleCancelRehearsal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Rehearsal?'),
        content: const Text(
          'This will mark the rehearsal as cancelled (BR-08) and release all venue '
          'and cast member reservations. Cancelled rehearsals will no longer cause scheduling conflicts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Rehearsal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: RevoColors.errorCrimson,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Rehearsal'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _rehearsalRepo.cancelRehearsal(widget.rehearsalId,
            user: _currentUser);
        final updated = _dataService.getRehearsalById(widget.rehearsalId);
        if (mounted) {
          setState(() {
            _rehearsal = updated;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rehearsal has been cancelled successfully.'),
              backgroundColor: RevoColors.errorCrimson,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel rehearsal: $e'),
              backgroundColor: RevoColors.errorCrimson,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rehearsal = _rehearsal;

    if (rehearsal == null) {
      return Scaffold(
        backgroundColor: RevoColors.surfaceContainerLowest,
        appBar: AppBar(title: const Text('Rehearsal Details')),
        body: Center(
          child: AppStatusState.error(
            title: 'Rehearsal Record Not Found',
            message:
                'The rehearsal record for ID "${widget.rehearsalId}" could not be located in the schedule database.',
          ),
        ),
      );
    }

    final prod = _dataService.getProductionById(rehearsal.productionId);
    final venue = _dataService.getVenueById(rehearsal.venueId);
    final statusColor = _getStatusColor(rehearsal.status);
    final isConfirmed = rehearsal.status == RehearsalStatus.confirmed;
    final isCancelled = rehearsal.status == RehearsalStatus.cancelled;

    final isDirector = _currentUser?.role == UserRole.director;
    final isAdmin = _currentUser?.role == UserRole.admin;
    final canManage = isAdmin || (isDirector && prod?.directorId == _currentUser?.userId);

    return Scaffold(
      backgroundColor: RevoColors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Rehearsal Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _rehearsal = _dataService.getRehearsalById(widget.rehearsalId);
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(RevoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── FR-12 / FR-13: Write Synchronization State & Freshness ───────
            StreamBuilder<WriteSyncStatus>(
              stream: SyncStatusService.instance
                  .watchEntityStatus(rehearsal.rehearsalId),
              builder: (context, syncSnap) {
                final writeStatus = syncSnap.data ??
                    (rehearsal.clientPending
                        ? WriteSyncStatus.pending
                        : WriteSyncStatus.confirmed);

                if (writeStatus == WriteSyncStatus.pending) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: RevoSpacing.md),
                    padding: const EdgeInsets.all(RevoSpacing.md),
                    decoration: BoxDecoration(
                      color: RevoColors.warningSurface,
                      borderRadius: RevoSpacing.borderRadiusCard,
                      border: Border.all(color: RevoColors.warningAmber),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.upload_outlined,
                            color: RevoColors.warningText, size: 20),
                        const SizedBox(width: RevoSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pending Synchronization (FR-13)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: RevoColors.warningText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'This change is stored locally on your device and will be confirmed once connected to the server.',
                                style: RevoTypography.caption.copyWith(
                                  color: RevoColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const EntitySyncBadge(status: WriteSyncStatus.pending),
                      ],
                    ),
                  );
                } else if (writeStatus == WriteSyncStatus.failed) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: RevoSpacing.md),
                    padding: const EdgeInsets.all(RevoSpacing.md),
                    decoration: BoxDecoration(
                      color: RevoColors.errorSurface,
                      borderRadius: RevoSpacing.borderRadiusCard,
                      border: Border.all(color: RevoColors.errorCrimson),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: RevoColors.errorCrimson, size: 20),
                        const SizedBox(width: RevoSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Synchronization Failed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: RevoColors.errorCrimson,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Could not synchronize this rehearsal with the server. Tap retry to attempt persistence again.',
                                style: RevoTypography.caption.copyWith(
                                  color: RevoColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: RevoColors.errorCrimson),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                          ),
                          onPressed: () =>
                              SyncStatusService.instance.reconcilePending(),
                          child: const Text('Retry',
                              style:
                                  TextStyle(color: RevoColors.errorCrimson)),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // ── Status Banner ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(RevoSpacing.md),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: RevoSpacing.borderRadiusCard,
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    isConfirmed
                        ? Icons.check_circle_outline
                        : (isCancelled
                            ? Icons.cancel_outlined
                            : Icons.schedule_outlined),
                    color: statusColor,
                    size: 22,
                  ),
                  const SizedBox(width: RevoSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConfirmed
                              ? 'CONFIRMED SCHEDULE COMMITMENT'
                              : (isCancelled
                                  ? 'CANCELLED REHEARSAL'
                                  : 'PROPOSED CALL — PENDING RESOLUTION'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isConfirmed
                              ? 'This rehearsal is finalized and reserves both the venue and participant calendars.'
                              : (isCancelled
                                  ? 'This rehearsal has been cancelled and does not block venue or cast schedules.'
                                  : 'This rehearsal call is proposed and must be validated before becoming final.'),
                          style: RevoTypography.caption.copyWith(
                            color: RevoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RevoSpacing.lg),

            // ── Header Card ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(RevoSpacing.lg),
              decoration: BoxDecoration(
                color: RevoColors.cardBackground,
                borderRadius: RevoSpacing.borderRadiusCard,
                border: Border.all(color: RevoColors.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          rehearsal.title ?? 'Production Rehearsal Call',
                          style: RevoTypography.headline2.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          rehearsal.status.name.toUpperCase(),
                          style: RevoTypography.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Rehearsal ID: ${rehearsal.rehearsalId}',
                        style: RevoTypography.caption
                            .copyWith(color: RevoColors.textMuted),
                      ),
                      const Spacer(),
                      Text(
                        SyncTimestampFormatter.formatWithPrefix(
                            SyncStatusService.instance.lastSyncedAt),
                        style: RevoTypography.caption
                            .copyWith(color: RevoColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: RevoSpacing.md),

            // ── Production Card (Link to Production Details) ───────────────
            Container(
              padding: const EdgeInsets.all(RevoSpacing.md),
              decoration: BoxDecoration(
                color: RevoColors.cardBackground,
                borderRadius: RevoSpacing.borderRadiusCard,
                border: Border.all(color: RevoColors.borderDefault),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: RevoColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.movie_creation_outlined,
                        color: RevoColors.primary, size: 20),
                  ),
                  const SizedBox(width: RevoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRODUCTION',
                          style: RevoTypography.caption.copyWith(
                            color: RevoColors.textMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          prod?.name ?? 'Assigned Production',
                          style: RevoTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (prod != null)
                    TextButton(
                      onPressed: () {
                        if (_currentUser != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductionDetailScreen(
                                production: prod,
                                user: _currentUser!,
                                productionRepository: MockProductionRepository(),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('View Production'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: RevoSpacing.md),

            // ── Schedule & Venue Information ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(RevoSpacing.lg),
              decoration: BoxDecoration(
                color: RevoColors.cardBackground,
                borderRadius: RevoSpacing.borderRadiusCard,
                border: Border.all(color: RevoColors.borderDefault),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: RevoColors.primary),
                      const SizedBox(width: RevoSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DATE & TIME WINDOW',
                              style: RevoTypography.caption.copyWith(
                                color: RevoColors.textMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(rehearsal.startAt),
                              style: RevoTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_formatTime(rehearsal.startAt)} – ${_formatTime(rehearsal.endAt)}  (${_calculateDuration(rehearsal.startAt, rehearsal.endAt)})',
                              style: RevoTypography.caption.copyWith(
                                color: RevoColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: RevoSpacing.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: Color(0xFF5B6BBF)),
                      const SizedBox(width: RevoSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BOOKED VENUE',
                              style: RevoTypography.caption.copyWith(
                                color: RevoColors.textMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              venue?.name ?? rehearsal.venueId,
                              style: RevoTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (venue != null)
                              Text(
                                '${venue.location} · Capacity ${venue.capacity}',
                                style: RevoTypography.caption.copyWith(
                                  color: RevoColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: RevoSpacing.md),

            // ── Participating Cast Members ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(RevoSpacing.lg),
              decoration: BoxDecoration(
                color: RevoColors.cardBackground,
                borderRadius: RevoSpacing.borderRadiusCard,
                border: Border.all(color: RevoColors.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scheduled Participants',
                        style: RevoTypography.title2
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: RevoColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${rehearsal.participantIds.length} cast members',
                          style: RevoTypography.caption
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RevoSpacing.md),
                  if (rehearsal.participantIds.isEmpty)
                    Text(
                      'No individual cast members specifically assigned to this rehearsal call.',
                      style: RevoTypography.caption
                          .copyWith(color: RevoColors.textSecondary),
                    )
                  else
                    ...rehearsal.participantIds.map((userId) {
                      final actorName = _dataService.getUserName(userId);
                      final assignments = _dataService
                          .getCastAssignmentsForProduction(
                              rehearsal.productionId)
                          .where((a) => a.castMemberId == userId)
                          .toList();

                      final role = assignments.isNotEmpty
                          ? _dataService.getRoleById(assignments.first.roleId)
                          : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: RevoSpacing.sm),
                        padding: const EdgeInsets.all(RevoSpacing.sm),
                        decoration: BoxDecoration(
                          color: RevoColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  RevoColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                actorName.isNotEmpty ? actorName[0] : 'C',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: RevoColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: RevoSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    actorName,
                                    style: RevoTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (role != null)
                                    Text(
                                      'Role: ${role.name}',
                                      style: RevoTypography.caption.copyWith(
                                        color: RevoColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: RevoSpacing.md),

            // ── Notes Section ─────────────────────────────────────────────
            if (rehearsal.notes != null && rehearsal.notes!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(RevoSpacing.lg),
                decoration: BoxDecoration(
                  color: RevoColors.cardBackground,
                  borderRadius: RevoSpacing.borderRadiusCard,
                  border: Border.all(color: RevoColors.borderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rehearsal Notes & Directives',
                      style: RevoTypography.title2
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: RevoSpacing.sm),
                    Text(
                      rehearsal.notes!,
                      style: RevoTypography.bodyMedium.copyWith(
                        color: RevoColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RevoSpacing.md),
            ],

            // ── Audit Metadata ────────────────────────────────────────────
            Container(
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
                    'AUDIT TRAIL',
                    style: RevoTypography.caption.copyWith(
                      color: RevoColors.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: RevoSpacing.xs),
                  Text(
                    'Created By: ${_dataService.getUserName(rehearsal.createdBy)} (${rehearsal.createdBy})',
                    style: RevoTypography.caption
                        .copyWith(color: RevoColors.textSecondary),
                  ),
                  Text(
                    'Created At: ${_formatDate(rehearsal.createdAt)}',
                    style: RevoTypography.caption
                        .copyWith(color: RevoColors.textSecondary),
                  ),
                  Text(
                    'Last Updated: ${_formatDate(rehearsal.updatedAt)}',
                    style: RevoTypography.caption
                        .copyWith(color: RevoColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RevoSpacing.xl),

            // ── Management Actions (Director / Admin) ─────────────────────
            if (canManage && !isCancelled) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: RevoColors.errorCrimson,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: RevoSpacing.borderRadiusButton,
                  ),
                ),
                onPressed: _isLoading ? null : _handleCancelRehearsal,
                icon: const Icon(Icons.cancel_outlined),
                label: Text(
                  _isLoading ? 'Processing...' : 'Cancel Rehearsal (BR-08)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: RevoSpacing.xxl),
            ],
          ],
        ),
      ),
    );
  }
}
