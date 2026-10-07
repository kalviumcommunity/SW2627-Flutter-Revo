import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/cast_assignment.dart';
import '../../services/firebase_cast_repository.dart';

class MyAssignmentsScreen extends StatelessWidget {
  const MyAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final castRepo = FirebaseCastRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cast Assignments (FR-04, BR-06)'),
      ),
      body: StreamBuilder<List<CastAssignment>>(
        stream: castRepo.watchMyAssignments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final assignments = snapshot.data ?? [];
          if (assignments.isEmpty) {
            return const Center(
              child: Text('You have no active cast assignments.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final asgn = assignments[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.star, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: Text(
                    'Role ID: ${asgn.roleId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      Text('Production: ${asgn.productionId}'),
                      Text('Assigned Date: ${asgn.assignedAt.toLocal().toString().split(' ')[0]}'),
                    ],
                  ),
                  trailing: const Chip(
                    label: Text('ACTIVE'),
                    backgroundColor: Colors.lightGreenAccent,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
