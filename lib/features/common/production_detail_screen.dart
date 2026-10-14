import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/enums/revo_enums.dart';
import '../../core/widgets/app_status_state.dart';
import '../../models/app_user.dart';
import '../../models/cast_assignment.dart';
import '../../models/production.dart';
import '../../models/production_role.dart';
import '../../models/rehearsal.dart';
import '../../models/venue.dart';
import '../../services/mock_data_service.dart';
import '../admin/venue_management_screen.dart';

/// FR-02 & Issue #13: Production Details Screen.
/// Displays comprehensive production metadata, cast assignments,
/// rehearsal schedule, and utilized venues with role-sensitive actions.
class ProductionDetailScreen extends StatefulWidget {
  final Production? production;
  final String? productionId;
  final AppUser user;

  const ProductionDetailScreen({
    super.key,
    this.production,
    this.productionId,
    required this.user,
  }) : assert(
          production != null || productionId != null,
          'Either production or productionId must be provided',
        );

  @override
  State<ProductionDetailScreen> createState() => _ProductionDetailScreenState();
}

class _ProductionDetailScreenState extends State<ProductionDetailScreen> {
  final MockDataService _dataService = MockDataService();
  Production? _production;

  @override
  void initState() {
    super.initState();
    _loadProduction();
  }

  void _loadProduction() {
    if (widget.production != null) {
      _production = widget.production;
    } else if (widget.productionId != null) {
      _production = _dataService.getProductionById(widget.productionId!);
    }
  }

  void _refresh() {
    if (_production != null) {
      final updated = _dataService.getProductionById(_production!.productionId);
      if (updated != null) {
        setState(() {
          _production = updated;
        });
      }
    }
  }

  Color _getStatusColor(ProductionStatus status) {
    switch (status) {
      case ProductionStatus.rehearsing:
        return RevoColors.primary;
      case ProductionStatus.casting:
        return RevoColors.warningAmber;
      case ProductionStatus.planning:
        return const Color(0xFF5B6BBF);
      case ProductionStatus.completed:
        return RevoColors.successGreen;
      case ProductionStatus.cancelled:
        return RevoColors.errorCrimson;
    }
  }

  String _formatStatusLabel(ProductionStatus status) {
    switch (status) {
      case ProductionStatus.rehearsing:
        return 'REHEARSING';
      case ProductionStatus.casting:
        return 'CASTING';
      case ProductionStatus.planning:
        return 'PLANNING';
      case ProductionStatus.completed:
        return 'COMPLETED';
      case ProductionStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final prod = _production;
    if (prod == null) {
      return Scaffold(
        backgroundColor: RevoColors.surfaceContainerLowest,
        appBar: AppBar(title: const Text('Production Not Found')),
        body: Center(
          child: AppStatusState.error(
            title: 'Production Unavailable',
            message: 'The requested production record could not be found.',
          ),
        ),
      );
    }

    final directorName = _dataService.getDirectorName(prod.directorId);
    final roles = _dataService.getRolesForProduction(prod.productionId);
    final assignments =
        _dataService.getCastAssignmentsForProduction(prod.productionId);
    final rehearsals =
        _dataService.getRehearsalsForProduction(prod.productionId);
    final venues = _dataService.getVenuesForProduction(prod.productionId);

    // Map roleId -> CastAssignment for quick lookup
    final assignmentByRoleId = <String, CastAssignment>{};
    for (final a in assignments) {
      assignmentByRoleId[a.roleId] = a;
    }

    final isDirector = widget.user.role == UserRole.director;
    final isAssignedDirector = isDirector && prod.directorId == widget.user.userId;

    return Scaffold(
      backgroundColor: RevoColors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          prod.name,
          overflow: TextOverflow.ellipsis,
          style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: RevoSpacing.lg,
          vertical: RevoSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning banner if a Director is viewing another director's production
            if (isDirector && !isAssignedDirector)
              Container(
                margin: const EdgeInsets.only(bottom: RevoSpacing.md),
                padding: const EdgeInsets.all(RevoSpacing.md),
                decoration: BoxDecoration(
                  color: RevoColors.surfaceContainerHigh,
                  borderRadius: RevoSpacing.borderRadiusCard,
                  border: Border.all(color: RevoColors.borderDefault),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: RevoColors.textSecondary, size: 20),
                    const SizedBox(width: RevoSpacing.sm),
                    Expanded(
                      child: Text(
                        'Read-only view: You are not the assigned director for this production.',
                        style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Section A: Production Overview Card ──────────────────────────
            _buildOverviewCard(prod, directorName),
            const SizedBox(height: RevoSpacing.xl),

            // ── Section B: Cast & Role Assignments ───────────────────────────
            _buildCastSection(roles, assignmentByRoleId),
            const SizedBox(height: RevoSpacing.xl),

            // ── Section C: Upcoming Rehearsals ───────────────────────────────
            _buildRehearsalSection(rehearsals),
            const SizedBox(height: RevoSpacing.xl),

            // ── Section D: Venue Information ─────────────────────────────────
            _buildVenueSection(venues),
            const SizedBox(height: RevoSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(Production prod, String directorName) {
    final statusColor = _getStatusColor(prod.status);

    return Container(
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
                  prod.name,
                  style: RevoTypography.headline2.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: RevoSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _formatStatusLabel(prod.status),
                  style: RevoTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RevoSpacing.md),
          Text(
            prod.description,
            style: RevoTypography.bodyLarge.copyWith(
              color: RevoColors.textSecondary,
              height: 1.45,
            ),
          ),
          const Divider(height: RevoSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIRECTOR',
                      style: RevoTypography.caption.copyWith(
                        color: RevoColors.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_pin_circle_outlined, size: 16, color: RevoColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          directorName,
                          style: RevoTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: RevoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRODUCTION RUN',
                      style: RevoTypography.caption.copyWith(
                        color: RevoColors.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 16, color: RevoColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_formatDate(prod.startDate)} – ${_formatDate(prod.endDate)}',
                            style: RevoTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: RevoColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCastSection(
    List<ProductionRole> roles,
    Map<String, CastAssignment> assignmentMap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cast & Roles',
              style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: RevoColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${roles.length} roles',
                style: RevoTypography.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: RevoSpacing.md),
        if (roles.isEmpty)
          AppStatusState.empty(
            title: 'No Cast Roles Yet',
            message: 'No roles have been created for this production.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: roles.length,
            separatorBuilder: (_, _) => const SizedBox(height: RevoSpacing.sm),
            itemBuilder: (context, index) {
              final role = roles[index];
              final assignment = assignmentMap[role.roleId];
              final isAssigned = assignment != null || role.status == RoleStatus.assigned;
              final actorName = assignment != null
                  ? _dataService.getUserName(assignment.castMemberId)
                  : null;

              return Container(
                padding: const EdgeInsets.all(RevoSpacing.md),
                decoration: BoxDecoration(
                  color: RevoColors.cardBackground,
                  borderRadius: RevoSpacing.borderRadiusCard,
                  border: Border.all(color: RevoColors.borderDefault),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isAssigned
                          ? RevoColors.successGreen.withValues(alpha: 0.15)
                          : RevoColors.warningAmber.withValues(alpha: 0.15),
                      child: Icon(
                        isAssigned ? Icons.person : Icons.person_outline,
                        color: isAssigned ? RevoColors.successGreen : RevoColors.warningAmber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: RevoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                role.name,
                                style: RevoTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAssigned
                                      ? RevoColors.successGreen.withValues(alpha: 0.1)
                                      : RevoColors.warningAmber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isAssigned ? 'ASSIGNED' : 'OPEN',
                                  style: RevoTypography.caption.copyWith(
                                    color: isAssigned
                                        ? RevoColors.successGreen
                                        : RevoColors.warningAmber,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role.description,
                            style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
                          ),
                          if (actorName != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Cast to: ',
                                  style: RevoTypography.caption.copyWith(color: RevoColors.textMuted),
                                ),
                                Text(
                                  actorName,
                                  style: RevoTypography.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: RevoColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRehearsalSection(List<Rehearsal> rehearsals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Rehearsals',
              style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: RevoColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${rehearsals.length} scheduled',
                style: RevoTypography.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: RevoSpacing.md),
        if (rehearsals.isEmpty)
          AppStatusState.empty(
            title: 'No Upcoming Rehearsals',
            message: 'No rehearsals are currently scheduled for this production.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rehearsals.length,
            separatorBuilder: (_, _) => const SizedBox(height: RevoSpacing.sm),
            itemBuilder: (context, index) {
              final r = rehearsals[index];
              final venue = _dataService.getVenueById(r.venueId);
              final isConfirmed = r.status == RehearsalStatus.confirmed;

              return Container(
                padding: const EdgeInsets.all(RevoSpacing.md),
                decoration: BoxDecoration(
                  color: RevoColors.cardBackground,
                  borderRadius: RevoSpacing.borderRadiusCard,
                  border: Border.all(color: RevoColors.borderDefault),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isConfirmed
                          ? RevoColors.primary.withValues(alpha: 0.15)
                          : RevoColors.warningAmber.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.event_note,
                        color: isConfirmed ? RevoColors.primary : RevoColors.warningAmber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: RevoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_formatDate(r.startAt)} · ${_formatTime(r.startAt)} – ${_formatTime(r.endAt)}',
                                style: RevoTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isConfirmed
                                      ? RevoColors.primary.withValues(alpha: 0.1)
                                      : RevoColors.warningAmber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isConfirmed ? 'CONFIRMED' : 'PROPOSED',
                                  style: RevoTypography.caption.copyWith(
                                    color: isConfirmed ? RevoColors.primary : RevoColors.warningAmber,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: RevoColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  venue != null ? '${venue.name} (${venue.location})' : 'Venue TBD',
                                  style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.people_outline, size: 14, color: RevoColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${r.participantIds.length} cast participants scheduled',
                                style: RevoTypography.caption.copyWith(color: RevoColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildVenueSection(List<Venue> venues) {
    final isAdmin = widget.user.role == UserRole.admin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Associated Venues',
              style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            if (isAdmin)
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VenueManagementScreen(user: widget.user),
                    ),
                  );
                },
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Manage'),
              ),
          ],
        ),
        const SizedBox(height: RevoSpacing.sm),
        if (venues.isEmpty)
          Container(
            padding: const EdgeInsets.all(RevoSpacing.md),
            decoration: BoxDecoration(
              color: RevoColors.cardBackground,
              borderRadius: RevoSpacing.borderRadiusCard,
              border: Border.all(color: RevoColors.borderDefault),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: RevoColors.textMuted),
                const SizedBox(width: RevoSpacing.md),
                Expanded(
                  child: Text(
                    'No venues have been booked for rehearsals yet.',
                    style: RevoTypography.bodyMedium.copyWith(color: RevoColors.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: venues.length,
            separatorBuilder: (_, _) => const SizedBox(height: RevoSpacing.sm),
            itemBuilder: (context, index) {
              final v = venues[index];
              final isActive = v.status == VenueStatus.active;

              return Container(
                padding: const EdgeInsets.all(RevoSpacing.md),
                decoration: BoxDecoration(
                  color: RevoColors.cardBackground,
                  borderRadius: RevoSpacing.borderRadiusCard,
                  border: Border.all(color: RevoColors.borderDefault),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: RevoColors.surfaceContainerHigh,
                      child: const Icon(Icons.theater_comedy, color: RevoColors.primary, size: 20),
                    ),
                    const SizedBox(width: RevoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                v.name,
                                style: RevoTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? RevoColors.successGreen.withValues(alpha: 0.1)
                                      : RevoColors.errorCrimson.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE' : 'MAINTENANCE',
                                  style: RevoTypography.caption.copyWith(
                                    color: isActive ? RevoColors.successGreen : RevoColors.errorCrimson,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${v.location} · Capacity: ${v.capacity} persons',
                            style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
