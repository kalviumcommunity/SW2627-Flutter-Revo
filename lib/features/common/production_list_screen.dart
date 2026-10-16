import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/enums/revo_enums.dart';
import '../../core/widgets/app_status_state.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/cast_assignment.dart';
import '../../models/production.dart';
import '../../models/rehearsal.dart';
import '../../services/production_repository.dart';
import 'production_detail_screen.dart';

/// FR-02 & Issue #13: Reusable Production List Screen.
/// Accessible by Director and Admin users with strict role-based data scoping:
/// - Director: sees only assigned productions.
/// - Admin: browses all productions in theatre catalog.
/// Depends on [ProductionRepository] interface rather than concrete mock services.
class ProductionListScreen extends StatefulWidget {
  final AppUser user;
  final ProductionRepository productionRepository;

  const ProductionListScreen({
    super.key,
    required this.user,
    required this.productionRepository,
  });

  @override
  State<ProductionListScreen> createState() => _ProductionListScreenState();
}

class _ProductionListScreenState extends State<ProductionListScreen> {
  ProductionStatus? _selectedFilter;

  Color _getStatusColor(ProductionStatus status) {
    switch (status) {
      case ProductionStatus.rehearsing:
        return RevoColors.primary;
      case ProductionStatus.casting:
        return RevoColors.warningAmber;
      case ProductionStatus.planning:
        return const Color(0xFF5B6BBF);
      case ProductionStatus.completed:
        return RevoColors.successGreen;
      case ProductionStatus.cancelled:
        return RevoColors.errorCrimson;
    }
  }

  String _formatStatusLabel(ProductionStatus status) {
    switch (status) {
      case ProductionStatus.rehearsing:
        return 'REHEARSING';
      case ProductionStatus.casting:
        return 'CASTING';
      case ProductionStatus.planning:
        return 'PLANNING';
      case ProductionStatus.completed:
        return 'COMPLETED';
      case ProductionStatus.cancelled:
        return 'CANCELLED';
    }
  }

  void _openCreateProductionSheet() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    ProductionStatus selectedStatus = ProductionStatus.planning;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RevoColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: RevoSpacing.borderRadiusModal,
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: RevoSpacing.xl,
                right: RevoSpacing.xl,
                top: RevoSpacing.xl,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + RevoSpacing.xl,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Production',
                          style: RevoTypography.title2.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Production Name',
                      hint: 'e.g., The Tempest',
                      controller: titleController,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a production name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Description',
                      hint: 'Synopsis and production vision...',
                      controller: descController,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a description.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Initial Status',
                      style: RevoTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ProductionStatus>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ProductionStatus.planning,
                          child: Text('Planning'),
                        ),
                        DropdownMenuItem(
                          value: ProductionStatus.casting,
                          child: Text('Casting'),
                        ),
                        DropdownMenuItem(
                          value: ProductionStatus.rehearsing,
                          child: Text('Rehearsing'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedStatus = val);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Create Production',
                      icon: Icons.add_rounded,
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          final messenger = ScaffoldMessenger.of(context);
                          final now = DateTime.now();
                          await widget.productionRepository.createProduction(
                            ProductionInput(
                              name: titleController.text.trim(),
                              description: descController.text.trim(),
                              startDate: now,
                              endDate: now.add(const Duration(days: 60)),
                              status: selectedStatus,
                            ),
                            directorId: widget.user.userId,
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            setState(() {});
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: RevoColors.successGreen,
                                content: Text('Production created successfully.'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDirector = widget.user.role == UserRole.director;

    return Scaffold(
      backgroundColor: RevoColors.surfaceBase,
      appBar: AppBar(
        title: Text(isDirector ? 'My Assigned Productions' : 'All Productions Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create Production',
            onPressed: _openCreateProductionSheet,
          ),
        ],
      ),
      body: StreamBuilder<List<Production>>(
        stream: widget.productionRepository.watchProductions(
          userId: widget.user.userId,
          role: widget.user.role,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: AppStatusState.error(
                title: 'Error Loading Productions',
                message: snapshot.error.toString(),
                actionLabel: 'Retry',
                onAction: () => setState(() {}),
              ),
            );
          }

          final allForUser = snapshot.data ?? [];
          final filtered = _selectedFilter == null
              ? allForUser
              : allForUser.where((p) => p.status == _selectedFilter).toList();

          return Column(
            children: [
              // Filter Chips
              _buildFilterBar(),

              // List or Empty State
              Expanded(
                child: filtered.isEmpty
                    ? AppStatusState.empty(
                        title: 'No Productions Found',
                        message: isDirector
                            ? 'You currently have no assigned productions matching this filter.'
                            : 'No productions registered under this status category.',
                        actionLabel: 'Create Production',
                        onAction: _openCreateProductionSheet,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(RevoSpacing.lg),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final prod = filtered[index];
                          return _buildProductionCard(prod);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: RevoColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Add Production',
        onPressed: _openCreateProductionSheet,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: RevoSpacing.lg, vertical: 8),
      child: Row(
        children: [
          _filterChip('All', null),
          const SizedBox(width: 8),
          _filterChip('Rehearsing', ProductionStatus.rehearsing),
          const SizedBox(width: 8),
          _filterChip('Planning', ProductionStatus.planning),
          const SizedBox(width: 8),
          _filterChip('Casting', ProductionStatus.casting),
          const SizedBox(width: 8),
          _filterChip('Completed', ProductionStatus.completed),
        ],
      ),
    );
  }

  Widget _filterChip(String label, ProductionStatus? status) {
    final isSelected = _selectedFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: RevoColors.primarySubtle,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? RevoColors.primary : RevoColors.textPrimary,
      ),
      onSelected: (_) => setState(() => _selectedFilter = status),
    );
  }

  Widget _buildProductionCard(Production prod) {
    final statusColor = _getStatusColor(prod.status);

    return InkWell(
      borderRadius: RevoSpacing.borderRadiusCard,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductionDetailScreen(
              production: prod,
              user: widget.user,
              productionRepository: widget.productionRepository,
            ),
          ),
        ).then((_) => setState(() {}));
      },
      child: Container(
        padding: const EdgeInsets.all(RevoSpacing.lg),
        decoration: BoxDecoration(
          color: RevoColors.surfaceContainerLowest,
          borderRadius: RevoSpacing.borderRadiusCard,
          border: Border.all(color: RevoColors.surfaceDim),
          boxShadow: RevoSpacing.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Date Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: RevoSpacing.borderRadiusPill,
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _formatStatusLabel(prod.status),
                    style: RevoTypography.captionBadge.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${prod.startDate.year}-${prod.startDate.month.toString().padLeft(2, '0')}-${prod.startDate.day.toString().padLeft(2, '0')}',
                  style: RevoTypography.captionBadge.copyWith(
                    color: RevoColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Production Name
            Text(
              prod.name,
              style: RevoTypography.title2.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),

            // Description
            Text(
              prod.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RevoTypography.bodyMedium.copyWith(
                color: RevoColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),

            // Metadata Row: Cast Count + Rehearsals Count + Arrow
            Row(
              children: [
                FutureBuilder<List<CastAssignment>>(
                  future: widget.productionRepository.getCastAssignmentsForProduction(prod.productionId),
                  builder: (context, snap) {
                    final count = snap.data?.length ?? 0;
                    return _metaPill(
                      icon: Icons.groups_outlined,
                      text: '$count Cast',
                    );
                  },
                ),
                const SizedBox(width: 8),
                FutureBuilder<List<Rehearsal>>(
                  future: widget.productionRepository.getRehearsalsForProduction(prod.productionId),
                  builder: (context, snap) {
                    final count = snap.data?.length ?? 0;
                    return _metaPill(
                      icon: Icons.event_note_outlined,
                      text: '$count Rehearsals',
                    );
                  },
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: RevoColors.textTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: RevoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: RevoColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: RevoTypography.captionBadge.copyWith(
              color: RevoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
