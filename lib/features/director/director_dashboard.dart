import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/app_user.dart';
import '../../services/firebase_auth_service.dart';
import 'director_interview_screen.dart';

class DirectorDashboard extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onNavigateToAuditions;
  final VoidCallback? onNavigateToRoles;

  const DirectorDashboard({
    super.key,
    required this.user,
    this.onNavigateToAuditions,
    this.onNavigateToRoles,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = FirebaseAuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Director Portal'),
        actions: [
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            // User Greeting Card
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'D',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${user.name}!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            avatar: const Icon(Icons.movie_creation, size: 16),
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

            // Quick Actions Title
            Text(
              'Director Quick Actions (FR-02, FR-03, FR-04)',
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
                      onTap: onNavigateToAuditions,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.record_voice_over_outlined,
                              size: 36,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Auditions & Applications',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'FR-03 Workflow',
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
                      onTap: onNavigateToRoles,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 36,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Roles & Cast Assignment',
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
            const SizedBox(height: 16),

            // PRD Evidence Banner Card
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.verified),
                title: const Text(
                  'PRD Baseline Evidence & Interview',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('View empirical evidence from Director interviews.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DirectorInterviewScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
