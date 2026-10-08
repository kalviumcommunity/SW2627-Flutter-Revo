import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/cast_assignment.dart';
import '../../models/production_role.dart';
import '../../services/firebase_cast_repository.dart';

class RoleCastAssignmentScreen extends StatefulWidget {
  final String productionId;

  const RoleCastAssignmentScreen({
    super.key,
    this.productionId = 'prod_1',
  });

  @override
  State<RoleCastAssignmentScreen> createState() =>
      _RoleCastAssignmentScreenState();
}

class _RoleCastAssignmentScreenState extends State<RoleCastAssignmentScreen> {
  final FirebaseCastRepository _castRepo = FirebaseCastRepository();

  void _showCreateRoleDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Define Production Role (FR-04)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Role Name (e.g. Laertes)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
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
              if (nameController.text.trim().isEmpty) return;

              await _castRepo.createRole(
                RoleInput(
                  productionId: widget.productionId,
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                ),
              );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Production Role created! Status: OPEN (FR-04)'),
                  ),
                );
              }
            },
            child: const Text('Create Role'),
          ),
        ],
      ),
    );
  }

  void _showAssignCastDialog(BuildContext context, ProductionRole role) {
    final castIdController = TextEditingController(text: 'cast_201');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Cast Member to ${role.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAlignment.start,
          children: [
            const Text(
              'BR-06 Rule: Assigning a cast member will automatically set role status to ASSIGNED.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: castIdController,
              decoration: const InputDecoration(
                labelText: 'Cast Member User ID',
                border: OutlineInputBorder(),
              ),
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
              final castId = castIdController.text.trim();
              if (castId.isEmpty) return;

              try {
                await _castRepo.assign(
                  roleId: role.roleId,
                  castMemberId: castId,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Assigned $castId to ${role.name}! Status -> ASSIGNED (BR-06)',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Assignment'),
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
        title: const Text('Roles & Cast Assignment (FR-04, BR-06)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRoleDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Role'),
      ),
      body: StreamBuilder<List<ProductionRole>>(
        stream: _castRepo.watchRoles(widget.productionId),
        builder: (context, roleSnapshot) {
          if (roleSnapshot.connectionState == ConnectionState.waiting &&
              !roleSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final roles = roleSnapshot.data ?? [];
          if (roles.isEmpty) {
            return const Center(child: Text('No roles defined for this production.'));
          }

          return StreamBuilder<List<CastAssignment>>(
            stream: _castRepo.watchAssignments(widget.productionId),
            builder: (context, asgnSnapshot) {
              final assignments = asgnSnapshot.data ?? [];

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: roles.length,
                itemBuilder: (context, index) {
                  final role = roles[index];
                  final matchingAsgns = assignments
                      .where((a) => a.roleId == role.roleId && a.status == AssignmentStatus.active)
                      .toList();

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
                              Expanded(
                                child: Text(
                                  role.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(role.status.name.toUpperCase()),
                                backgroundColor: role.status == RoleStatus.open
                                    ? theme.colorScheme.secondaryContainer
                                    : theme.colorScheme.primaryContainer,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(role.description),
                          const Divider(height: 24),

                          // Active Assignments List
                          Text(
                            'Active Cast Assignment (BR-06):',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (matchingAsgns.isEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('No cast member assigned yet.'),
                                ElevatedButton.icon(
                                  onPressed: () => _showAssignCastDialog(context, role),
                                  icon: const Icon(Icons.person_add, size: 16),
                                  label: const Text('Assign Cast'),
                                ),
                              ],
                            )
                          ] else ...[
                            Column(
                              children: matchingAsgns.map((asgn) {
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.green),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Cast ID: ${asgn.castMemberId}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        tooltip: 'Revoke Assignment (BR-06 revert to OPEN)',
                                        onPressed: () async {
                                          await _castRepo.removeAssignment(asgn.assignmentId);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Assignment revoked! Role status reverted to OPEN (BR-06).',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
