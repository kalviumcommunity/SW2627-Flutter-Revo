import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/application.dart';
import '../../models/audition.dart';
import '../../services/firebase_audition_repository.dart';

class DirectorAuditionManagementScreen extends StatefulWidget {
  final String productionId;

  const DirectorAuditionManagementScreen({
    super.key,
    this.productionId = 'prod_1',
  });

  @override
  State<DirectorAuditionManagementScreen> createState() =>
      _DirectorAuditionManagementScreenState();
}

class _DirectorAuditionManagementScreenState
    extends State<DirectorAuditionManagementScreen> {
  final FirebaseAuditionRepository _auditionRepo = FirebaseAuditionRepository();

  void _showCreateAuditionDialog(BuildContext context) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 3));
    final rolesController = TextEditingController(text: 'role_101, role_102');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Audition Posting (FR-03)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAlignment.start,
          children: [
            const Text('Production ID: prod_1 (Hamlet)'),
            const SizedBox(height: 12),
            TextField(
              controller: rolesController,
              decoration: const InputDecoration(
                labelText: 'Available Role IDs (comma separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date: ${selectedDate.toLocal().toString().split(' ')[0]}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final roles = rolesController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              await _auditionRepo.createAudition(
                AuditionInput(
                  productionId: widget.productionId,
                  startAt: selectedDate,
                  endAt: selectedDate.add(const Duration(hours: 3)),
                  venueId: 'ven_1',
                  availableRoles: roles,
                ),
              );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Audition posting created successfully!'),
                  ),
                );
              }
            },
            child: const Text('Create Audition'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audition & Applications (FR-03)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAuditionDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Audition'),
      ),
      body: StreamBuilder<List<Audition>>(
        stream: _auditionRepo.watchAuditions(productionId: widget.productionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final auditions = snapshot.data ?? [];
          if (auditions.isEmpty) {
            return const Center(
              child: Text('No auditions found for this production.'),
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
                            'Audition ID: ${audition.auditionId}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Chip(
                            label: Text(audition.status.name.toUpperCase()),
                            backgroundColor: audition.status == AuditionStatus.open
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.errorContainer,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Start: ${audition.startAt.toLocal().toString().split('.')[0]}'),
                      Text('End:   ${audition.endAt.toLocal().toString().split('.')[0]}'),
                      const SizedBox(height: 8),
                      Text(
                        'Available Roles: ${audition.availableRoles.join(', ')}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Divider(height: 24),

                      // Stream of Applicants for this audition (FR-03)
                      Text(
                        'Applicant Submissions (FR-03):',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Application>>(
                        stream: _auditionRepo.watchApplicants(audition.auditionId),
                        builder: (context, appSnapshot) {
                          final apps = appSnapshot.data ?? [];
                          if (apps.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('No applications submitted yet.'),
                            );
                          }

                          return Column(
                            children: apps.map((app) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAlignment.start,
                                        children: [
                                          Text(
                                            'Cast ID: ${app.castMemberId}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text('Status: ${app.status.name}'),
                                        ],
                                      ),
                                    ),
                                    // Director Action to update application status
                                    DropdownButton<ApplicationStatus>(
                                      value: app.status,
                                      underline: const SizedBox(),
                                      onChanged: (newStatus) async {
                                        if (newStatus != null) {
                                          await _auditionRepo.updateApplicationStatus(
                                            app.applicationId,
                                            newStatus,
                                          );
                                        }
                                      },
                                      items: ApplicationStatus.values.map((st) {
                                        return DropdownMenuItem(
                                          value: st,
                                          child: Text(st.name),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
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
