import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/application.dart';
import '../../models/audition.dart';
import '../../services/firebase_audition_repository.dart';

class AuditionApplicationScreen extends StatelessWidget {
  const AuditionApplicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auditionRepo = FirebaseAuditionRepository();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Auditions & Applications (FR-03)'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.search), text: 'Open Auditions'),
              Tab(icon: Icon(Icons.assignment), text: 'My Applications'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Browse Open Auditions
            StreamBuilder<List<Audition>>(
              stream: auditionRepo.watchAuditions(openOnly: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final auditions = snapshot.data ?? [];
                if (auditions.isEmpty) {
                  return const Center(
                    child: Text('No open auditions currently available.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: auditions.length,
                  itemBuilder: (context, index) {
                    final audition = auditions[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Audition #${audition.auditionId}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Chip(
                                  label: Text('OPEN'),
                                  backgroundColor: Colors.greenAccent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Production ID: ${audition.productionId}'),
                            Text('Date: ${audition.startAt.toLocal().toString().split('.')[0]}'),
                            const SizedBox(height: 8),
                            Text(
                              'Available Roles: ${audition.availableRoles.join(', ')}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 16),

                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    await auditionRepo.apply(audition.auditionId);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Application submitted successfully! (FR-03)',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.send),
                                label: const Text('Apply Now'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // Tab 2: My Applications Status
            StreamBuilder<List<Application>>(
              stream: auditionRepo.watchMyApplications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final apps = snapshot.data ?? [];
                if (apps.isEmpty) {
                  return const Center(
                    child: Text('You have not submitted any audition applications yet.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.assignment_turned_in_outlined),
                        title: Text('Application #${app.applicationId}'),
                        subtitle: Text('Submitted: ${app.submittedAt.toLocal().toString().split('.')[0]}'),
                        trailing: Chip(
                          label: Text(
                            app.status.name.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: app.status == ApplicationStatus.selected
                              ? Colors.greenContainer
                              : theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
