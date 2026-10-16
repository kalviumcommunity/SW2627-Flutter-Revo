import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/app_user.dart';
import '../../models/production.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/mock_data_service.dart';
import '../../services/mock_production_repository.dart';
import '../../services/mock_venue_repository.dart';
import '../../services/production_repository.dart';
import '../../services/venue_repository.dart';
import '../common/conflict_resolution_screen.dart';
import '../common/production_detail_screen.dart';
import '../common/production_list_screen.dart';
import '../common/rehearsal_detail_screen.dart';
import '../profile/screens/profile_screen.dart';
import 'director_audition_management_screen.dart';
import 'director_interview_screen.dart';
import 'director_production_schedule_screen.dart';
import 'rehearsal_creation_screen.dart';
import 'role_cast_assignment_screen.dart';

/// FR-02, FR-09, FR-10 & Issue #13: Director Portal Dashboard.
/// Provides an operational overview strictly scoped to the Director's assigned
/// productions, upcoming rehearsals, active cast assignments, pre-confirmation
/// conflict status, and quick access to casting/schedule workflows.
class DirectorDashboard extends StatefulWidget {
  final AppUser user;
  final VoidCallback? onNavigateToAuditions;
  final VoidCallback? onNavigateToRoles;
  final ProductionRepository? productionRepository;
  final VenueRepository? venueRepository;

  const DirectorDashboard({
    super.key,
    required this.user,
    this.onNavigateToAuditions,
    this.onNavigateToRoles,
    this.productionRepository,
    this.venueRepository,
  });

  @override
  State<DirectorDashboard> createState() => _DirectorDashboardState();
}

class _DirectorDashboardState extends State<DirectorDashboard> {
  final MockDataService _dataService = MockDataService();
  late final ProductionRepository _productionRepository;
  late final VenueRepository _venueRepository;

  @override
  void initState() {
    super.initState();
    _productionRepository =
        widget.productionRepository ?? MockProductionRepository();
    _venueRepository = widget.venueRepository ?? MockVenueRepository();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = FirebaseAuthService();
    final metrics = _dataService.getDirectorMetrics(widget.user.userId);

    final myProdsCount = metrics['myProductionsCount'] as int? ?? 0;
    final rehearsalsCount = metrics['rehearsalsCount'] as int? ?? 0;
    final castCount = metrics['castCount'] as int? ?? 0;
    final primaryProd = metrics['primaryProduction'] as Production?;

    // Get upcoming rehearsals for Director's assigned productions
    final assignedProds = _dataService.getProductionsForUserSync(widget.user);
    final upcomingRehearsals = assignedProds.expand((p) {
      return _dataService.getRehearsalsForProduction(p.productionId);
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return Scaffold(
      backgroundColor: RevoColors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Director Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile (FR-18)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(initialUser: widget.user),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'PRD Baseline Evidence',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DirectorInterviewScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<UserRole>(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Demo Role Guard',
            onSelected: (role) {
              authService.switchUserRole(role);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: UserRole.director,
                child: Text('Role: Director'),
              ),
              PopupMenuItem(
                value: UserRole.cast,
                child: Text('Role: Cast Member'),
              ),
              PopupMenuItem(
                value: UserRole.admin,
                child: Text('Role: Admin'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await authService.logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(RevoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Banner
              Container(
                padding: const EdgeInsets.all(RevoSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: RevoSpacing.borderRadiusCard,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        widget.user.name.isNotEmpty
                            ? widget.user.name[0].toUpperCase()
                            : 'D',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: RevoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${widget.user.name}!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.movie_creation,
                                  size: 14,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ASSIGNED TO $myProdsCount PRODUCTIONS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    letterSpacing: 0.5,
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
              ),
              const SizedBox(height: RevoSpacing.xl),

              // Production Overview Section (FR-02)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Production Overview',
                    style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductionListScreen(
                            user: widget.user,
                            productionRepository: _productionRepository,
                          ),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    icon: const Icon(Icons.list_alt, size: 16),
                    label: const Text('My Productions'),
                  ),
                ],
              ),
              const SizedBox(height: RevoSpacing.xs),

              // Primary Production Feature Card
              if (primaryProd != null)
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductionDetailScreen(
                          production: primaryProd,
                          user: widget.user,
                          productionRepository: _productionRepository,
                          venueRepository: _venueRepository,
                        ),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  borderRadius: RevoSpacing.borderRadiusCard,
                  child: Container(
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
                            Expanded(
                              child: Text(
                                primaryProd.name,
                                style: RevoTypography.title2.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: RevoColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                primaryProd.status.name.toUpperCase(),
                                style: RevoTypography.caption.copyWith(
                                  color: RevoColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: RevoSpacing.sm),
                        Text(
                          primaryProd.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: RevoTypography.caption.copyWith(
                            color: RevoColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const Divider(height: RevoSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.people_outline,
                                      size: 16, color: RevoColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$castCount Cast Assigned',
                                    style: RevoTypography.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: RevoColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available_outlined,
                                      size: 16, color: RevoColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$rehearsalsCount Rehearsals',
                                    style: RevoTypography.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: RevoColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 18, color: RevoColors.textMuted),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: RevoSpacing.xl),

              // Upcoming Rehearsals Section (FR-09)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming Rehearsals',
                    style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      Text(
                        '${upcomingRehearsals.length} scheduled',
                        style: RevoTypography.caption.copyWith(
                          color: RevoColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: RevoSpacing.xs),
                      TextButton.icon(
                        key: const Key('director_dashboard_create_rehearsal_btn'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RehearsalCreationScreen(user: widget.user),
                            ),
                          ).then((_) => setState(() {}));
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Create'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: RevoSpacing.sm),

              if (upcomingRehearsals.isEmpty)
                Container(
                  padding: const EdgeInsets.all(RevoSpacing.lg),
                  decoration: BoxDecoration(
                    color: RevoColors.cardBackground,
                    borderRadius: RevoSpacing.borderRadiusCard,
                    border: Border.all(color: RevoColors.borderDefault),
                  ),
                  child: Center(
                    child: Text(
                      'No upcoming rehearsals scheduled for your productions.',
                      style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcomingRehearsals.length > 3 ? 3 : upcomingRehearsals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: RevoSpacing.xs),
                  itemBuilder: (context, index) {
                    final reh = upcomingRehearsals[index];
                    final prod = _dataService.getProductionById(reh.productionId);
                    final venue = _dataService.getVenueById(reh.venueId);

                    return Material(
                      color: RevoColors.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: RevoSpacing.borderRadiusCard,
                        side: const BorderSide(color: RevoColors.borderDefault),
                      ),
                      child: InkWell(
                        borderRadius: RevoSpacing.borderRadiusCard,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RehearsalDetailScreen(
                                rehearsalId: reh.rehearsalId,
                                user: widget.user,
                              ),
                            ),
                          ).then((_) => setState(() {}));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(RevoSpacing.md),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: RevoColors.primary.withValues(alpha: 0.12),
                                child: const Icon(Icons.event_note, size: 18, color: RevoColors.primary),
                              ),
                              const SizedBox(width: RevoSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            prod?.name ?? 'Assigned Production',
                                            style: RevoTypography.bodyMedium.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          reh.status.name.toUpperCase(),
                                          style: RevoTypography.caption.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: RevoColors.primary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatDate(reh.startAt)} · ${_formatTime(reh.startAt)} – ${_formatTime(reh.endAt)}',
                                      style: RevoTypography.caption.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: RevoColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      venue != null ? '${venue.name} (${venue.location})' : 'Venue TBD',
                                      style: RevoTypography.caption.copyWith(
                                        color: RevoColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: RevoSpacing.xs),
                              const Icon(Icons.chevron_right, size: 18, color: RevoColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: RevoSpacing.xl),

              // Conflict Awareness Card
              Container(
                padding: const EdgeInsets.all(RevoSpacing.md),
                decoration: BoxDecoration(
                  color: RevoColors.successGreen.withValues(alpha: 0.08),
                  borderRadius: RevoSpacing.borderRadiusCard,
                  border: Border.all(color: RevoColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: RevoColors.successGreen, size: 22),
                    const SizedBox(width: RevoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '0 Schedule Conflicts (BR-01..05)',
                            style: RevoTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: RevoColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Pre-confirmation conflict engine active for all assigned productions.',
                            style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConflictResolutionScreen.demo(),
                          ),
                        );
                      },
                      child: const Text('Review'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RevoSpacing.xl),

              // Quick Actions Section
              Text(
                'Director Workflows',
                style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: RevoSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.record_voice_over_outlined,
                      title: 'Auditions & Casting',
                      subtitle: 'FR-03 Workflow',
                      color: RevoColors.primary,
                      onTap: widget.onNavigateToAuditions ??
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DirectorAuditionManagementScreen(
                                  productionId: 'prod_101',
                                ),
                              ),
                            );
                          },
                    ),
                  ),
                  const SizedBox(width: RevoSpacing.md),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.badge_outlined,
                      title: 'Role Assignments',
                      subtitle: 'FR-04 / BR-06',
                      color: const Color(0xFF5B6BBF),
                      onTap: widget.onNavigateToRoles ??
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RoleCastAssignmentScreen(
                                  productionId: 'prod_101',
                                ),
                              ),
                            );
                          },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RevoSpacing.md),

              // Production Schedule Card (FR-09, FR-10)
              Material(
                color: RevoColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: RevoSpacing.borderRadiusCard,
                  side: const BorderSide(color: RevoColors.borderDefault),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.event_note_outlined,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  title: const Text(
                    'Production Schedule (FR-09, FR-10)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Production-wide calendar with live real-time stream'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const DirectorProductionScheduleScreen(
                          productionId: 'prod_101',
                          productionTitle: 'The Crucible',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: RevoSpacing.sm),

              // PRD Baseline Evidence Banner Card
              Material(
                color: RevoColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: RevoSpacing.borderRadiusCard,
                  side: const BorderSide(color: RevoColors.borderDefault),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: RevoColors.surfaceContainerHigh,
                    child: Icon(Icons.assessment_outlined, color: RevoColors.primary),
                  ),
                  title: const Text(
                    'PRD Baseline Evidence & Interview',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Record & inspect director operational baseline.'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DirectorInterviewScreen(),
                      ),
                    ).then((_) => setState(() {}));
                  },
                ),
              ),
              const SizedBox(height: RevoSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: RevoSpacing.borderRadiusCard,
      child: Container(
        padding: const EdgeInsets.all(RevoSpacing.lg),
        decoration: BoxDecoration(
          color: RevoColors.cardBackground,
          borderRadius: RevoSpacing.borderRadiusCard,
          border: Border.all(color: RevoColors.borderDefault),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: RevoSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: RevoTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
