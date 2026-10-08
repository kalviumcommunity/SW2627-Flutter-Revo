import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/app_user.dart';
import '../../services/firebase_auth_service.dart';
import 'my_schedule_screen.dart';

class CastDashboard extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onBrowseAuditions;
  final VoidCallback? onViewMyAssignments;
  final VoidCallback? onViewMySchedule;

  const CastDashboard({
    super.key,
    required this.user,
    this.onBrowseAuditions,
    this.onViewMyAssignments,
    this.onViewMySchedule,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = FirebaseAuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cast Member Portal'),
        actions: [
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            // User Banner
            Card(
              elevation: 0,
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.secondary,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'C',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user.name}!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            avatar: const Icon(Icons.groups, size: 16),
                            label: Text(
                              'Role: ${user.role.name.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Cast Member Features (FR-03, FR-09, FR-10, FR-16)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Card(
                    child: InkWell(
                      onTap: onBrowseAuditions,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.how_to_reg_outlined,
                              size: 36,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Browse & Apply Auditions',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'FR-03 Auditions',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: InkWell(
                      onTap: onViewMyAssignments,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_ind_outlined,
                              size: 36,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'My Cast Assignments',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'FR-04 / BR-06',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // My Schedule Card (FR-09, FR-10)
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyScheduleScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.calendar_month_outlined,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Schedule',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'FR-09 · Personalized chronological view',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Live real-time stream (FR-10)',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
