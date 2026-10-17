import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/app_user.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/mock_data_service.dart';
import '../../services/mock_production_repository.dart';
import '../../services/mock_venue_repository.dart';
import '../../services/production_repository.dart';
import '../../services/venue_repository.dart';
import '../common/production_list_screen.dart';
import '../director/director_interview_screen.dart';
import '../profile/screens/profile_screen.dart';
import 'venue_management_screen.dart';

/// FR-06, FR-17 & Issue #13: Theatre Administrator Portal Dashboard.
/// Provides organization-wide operational metrics derived from the live mock
/// dataset, and centralized routing to production catalog, venue management,
/// and PRD baseline evidence recording.
class AdminDashboard extends StatefulWidget {
  final AppUser user;
  final ProductionRepository? productionRepository;
  final VenueRepository? venueRepository;

  const AdminDashboard({
    super.key,
    required this.user,
    this.productionRepository,
    this.venueRepository,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = FirebaseAuthService();
    final metrics = _dataService.getAdminMetrics();

    final totalProds = metrics['totalProductions'] as int? ?? 0;
    final activeProds = metrics['activeProductions'] as int? ?? 0;
    final totalVenues = metrics['totalVenues'] as int? ?? 0;
    final activeVenues = metrics['activeVenues'] as int? ?? 0;
    final upcomingRehearsals = metrics['upcomingRehearsals'] as int? ?? 0;
    final totalCastMembers = metrics['totalCastMembers'] as int? ?? 0;

    return Scaffold(
      backgroundColor: RevoColors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Theatre Admin Portal'),
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
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: RevoSpacing.borderRadiusCard,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.tertiary,
                      child: Text(
                        widget.user.name.isNotEmpty
                            ? widget.user.name[0].toUpperCase()
                            : 'A',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: RevoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Administrator: ${widget.user.name}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings,
                                  size: 14,
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'THEATRE EXECUTIVE ACCESS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onTertiaryContainer,
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

              // Section: Organization Operational Metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Organization Overview',
                    style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Live Derived Metrics',
                    style: RevoTypography.caption.copyWith(
                      color: RevoColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RevoSpacing.md),

              // Metric Cards Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Productions',
                      value: '$totalProds',
                      subtext: '$activeProds active in run',
                      icon: Icons.movie_creation_outlined,
                      color: RevoColors.primary,
                      onTap: () {
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
                    ),
                  ),
                  const SizedBox(width: RevoSpacing.md),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Venues',
                      value: '$totalVenues',
                      subtext: '$activeVenues available',
                      icon: Icons.location_city_outlined,
                      color: const Color(0xFF5B6BBF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VenueManagementScreen(
                              user: widget.user,
                              venueRepository: _venueRepository,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RevoSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Rehearsals',
                      value: '$upcomingRehearsals',
                      subtext: 'Upcoming scheduled',
                      icon: Icons.event_note_outlined,
                      color: RevoColors.warningAmber,
                    ),
                  ),
                  const SizedBox(width: RevoSpacing.md),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Cast Assigned',
                      value: '$totalCastMembers',
                      subtext: 'Active cast actors',
                      icon: Icons.people_alt_outlined,
                      color: RevoColors.successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RevoSpacing.xl),

              // Section: Management Workflows
              Text(
                'Theatre Operations & Management',
                style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: RevoSpacing.md),

              // Productions Card
              _buildNavigationCard(
                icon: Icons.movie_filter_outlined,
                title: 'Productions Catalog & Scheduling',
                subtitle: 'Browse all $totalProds productions, inspect details, cast & rehearsals.',
                badgeText: '$activeProds ACTIVE',
                badgeColor: RevoColors.primary,
                onTap: () {
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
              ),
              const SizedBox(height: RevoSpacing.sm),

              // Venues Card
              _buildNavigationCard(
                icon: Icons.theater_comedy_outlined,
                title: 'Venue Catalog & Availability',
                subtitle: 'Manage capacity, book rehearsal slots, and toggle maintenance.',
                badgeText: '$activeVenues ONLINE',
                badgeColor: RevoColors.successGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VenueManagementScreen(
                        user: widget.user,
                        venueRepository: _venueRepository,
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
              ),
              const SizedBox(height: RevoSpacing.sm),

              // PRD Baseline Evidence Card
              _buildNavigationCard(
                icon: Icons.assessment_outlined,
                title: 'PRD Baseline Evidence & Interview',
                subtitle: 'Record quantitative baseline metrics from director interviews.',
                badgeText: 'INTEGRITY GATE',
                badgeColor: RevoColors.warningAmber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DirectorInterviewScreen(),
                    ),
                  ).then((_) => setState(() {}));
                },
              ),
              const SizedBox(height: RevoSpacing.sm),

              // User Access Controls Card
              _buildNavigationCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'User Access Controls & System Roles',
                subtitle: 'Verify Director, Cast, and Admin permissions across the theatre system.',
                badgeText: 'SECURITY GUARD',
                badgeColor: const Color(0xFF5B6BBF),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Role guards verified. Use switch icon in top bar to test role switching.'),
                      backgroundColor: RevoColors.primary,
                    ),
                  );
                },
              ),
              const SizedBox(height: RevoSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(RevoSpacing.md),
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
                label,
                style: RevoTypography.caption.copyWith(
                  color: RevoColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: RevoSpacing.sm),
          Text(
            value,
            style: RevoTypography.headline1.copyWith(
              fontWeight: FontWeight.w800,
              color: RevoColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: RevoTypography.caption.copyWith(
              color: RevoColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: RevoSpacing.borderRadiusCard,
        child: content,
      );
    }
    return content;
  }

  Widget _buildNavigationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: RevoColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: RevoSpacing.borderRadiusCard,
        side: const BorderSide(color: RevoColors.borderDefault),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RevoSpacing.md,
          vertical: RevoSpacing.xs,
        ),
        leading: CircleAvatar(
          backgroundColor: badgeColor.withValues(alpha: 0.12),
          child: Icon(icon, color: badgeColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: RevoTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: RevoTypography.caption.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: RevoColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
