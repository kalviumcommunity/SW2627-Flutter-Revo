import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/app_user.dart';
import '../../services/firebase_auth_service.dart';

class AdminDashboard extends StatelessWidget {
  final AppUser user;

  const AdminDashboard({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = FirebaseAuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theatre Admin Portal'),
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
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.tertiary,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAlignment.start,
                        children: [
                          Text(
                            'Administrator: ${user.name}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            avatar: const Icon(Icons.admin_panel_settings, size: 16),
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
              'Theatre Administration (FR-06, FR-17)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.location_city_outlined),
                title: const Text('Venue Catalog & Availability Management'),
                subtitle: const Text('Configure venue capacity and time bounds (FR-06).'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('User Access Controls & System Roles'),
                subtitle: const Text('Assign & verify user roles across the platform (FR-01, FR-17).'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
