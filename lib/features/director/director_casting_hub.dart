import 'package:flutter/material.dart';
import 'director_audition_management_screen.dart';
import 'role_cast_assignment_screen.dart';

class DirectorCastingHub extends StatelessWidget {
  const DirectorCastingHub({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Director Audition & Casting Hub'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.record_voice_over, color: theme.colorScheme.onPrimaryContainer),
                ),
                title: const Text(
                  'Audition Postings & Applications (FR-03)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Post auditions, review cast applicants, and update statuses.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DirectorAuditionManagementScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(Icons.badge, color: theme.colorScheme.onSecondaryContainer),
                ),
                title: const Text(
                  'Roles & Cast Assignment Engine (FR-04, BR-06)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Define roles, assign cast members, and auto-sync role status.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RoleCastAssignmentScreen(),
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
