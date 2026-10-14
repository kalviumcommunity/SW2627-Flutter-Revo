import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/enums/revo_enums.dart';
import '../../core/widgets/app_status_state.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/rehearsal.dart';
import '../../models/venue.dart';
import '../../services/mock_data_service.dart';

/// FR-06 & Issue #13: Venue Management and Catalog Screen.
/// Accessible by Theatre Admin for full venue lifecycle management (create,
/// edit, toggle active/maintenance status), and by Directors for read-only
/// operational availability verification.
class VenueManagementScreen extends StatefulWidget {
  final AppUser user;

  const VenueManagementScreen({
    super.key,
    required this.user,
  });

  @override
  State<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _VenueManagementScreenState extends State<VenueManagementScreen> {
  final MockDataService _dataService = MockDataService();
  VenueStatus? _statusFilter;

  bool get _isAdmin => widget.user.role == UserRole.admin;

  void _openCreateVenueSheet() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final capacityController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RevoColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: RevoSpacing.borderRadiusModal,
      ),
      builder: (ctx) {
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
                      'Add New Venue',
                      style: RevoTypography.title2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: RevoSpacing.md),
                AppTextField(
                  controller: nameController,
                  label: 'Venue Name',
                  hint: 'e.g. Studio C Dance Lab',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Venue name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: RevoSpacing.md),
                AppTextField(
                  controller: locationController,
                  label: 'Location / Room Number',
                  hint: 'e.g. Arts Wing — Room 301',
                  prefixIcon: const Icon(Icons.place_outlined),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Location is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: RevoSpacing.md),
                AppTextField(
                  controller: capacityController,
                  label: 'Capacity (Persons)',
                  hint: 'e.g. 50',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.people_outline),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Capacity is required';
                    }
                    final num = int.tryParse(val.trim());
                    if (num == null || num <= 0) {
                      return 'Enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: RevoSpacing.md),
                AppTextField(
                  controller: notesController,
                  label: 'Features / Notes (Optional)',
                  hint: 'e.g. Sprung wood floor, piano',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                ),
                const SizedBox(height: RevoSpacing.xl),
                PrimaryButton(
                  label: 'Create Venue',
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final input = VenueInput(
                        name: nameController.text.trim(),
                        location: locationController.text.trim(),
                        capacity: int.parse(capacityController.text.trim()),
                        availability: {
                          'status': 'active',
                          if (notesController.text.trim().isNotEmpty)
                            'notes': notesController.text.trim(),
                        },
                      );
                      await _dataService.createVenue(input);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Venue "${input.name}" registered successfully.',
                            ),
                            backgroundColor: RevoColors.primary,
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
  }

  void _showVenueDetailSheet(Venue venue, List<Rehearsal> venueRehearsals) {
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
            final currentVenue =
                _dataService.getVenueById(venue.venueId) ?? venue;
            final currentIsActive = currentVenue.status == VenueStatus.active;
            final updatedRehearsals =
                _dataService.getRehearsalsForVenue(currentVenue.venueId);

            return Padding(
              padding: const EdgeInsets.all(RevoSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          currentVenue.name,
                          style: RevoTypography.title2.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentIsActive
                              ? RevoColors.successGreen.withValues(alpha: 0.12)
                              : RevoColors.errorCrimson.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: currentIsActive
                                ? RevoColors.successGreen.withValues(alpha: 0.4)
                                : RevoColors.errorCrimson.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          currentIsActive ? 'ACTIVE' : 'MAINTENANCE',
                          style: RevoTypography.caption.copyWith(
                            color: currentIsActive
                                ? RevoColors.successGreen
                                : RevoColors.errorCrimson,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RevoSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 16, color: RevoColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        currentVenue.location,
                        style: RevoTypography.bodyMedium.copyWith(
                          color: RevoColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: RevoSpacing.lg),
                      const Icon(Icons.people_outline,
                          size: 16, color: RevoColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Capacity: ${currentVenue.capacity}',
                        style: RevoTypography.bodyMedium.copyWith(
                          color: RevoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (currentVenue.availability.containsKey('notes')) ...[
                    const SizedBox(height: RevoSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(RevoSpacing.sm),
                      decoration: BoxDecoration(
                        color: RevoColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Notes: ${currentVenue.availability['notes']}',
                        style: RevoTypography.caption.copyWith(
                          color: RevoColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: RevoSpacing.xl),
                  Text(
                    'Upcoming Bookings (${updatedRehearsals.length})',
                    style: RevoTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: RevoSpacing.sm),
                  if (updatedRehearsals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: RevoSpacing.md),
                      child: Text(
                        'No upcoming rehearsals scheduled at this venue.',
                        style: RevoTypography.caption.copyWith(
                          color: RevoColors.textMuted,
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: updatedRehearsals.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: RevoSpacing.xs),
                        itemBuilder: (ctx, idx) {
                          final reh = updatedRehearsals[idx];
                          final prod = _dataService
                              .getProductionById(reh.productionId);
                          return Container(
                            padding: const EdgeInsets.all(RevoSpacing.sm),
                            decoration: BoxDecoration(
                              color: RevoColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prod?.name ?? 'Production',
                                        style: RevoTypography.caption.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${reh.startAt.month}/${reh.startAt.day} · ${reh.startAt.hour}:${reh.startAt.minute.toString().padLeft(2, '0')}',
                                        style: RevoTypography.caption.copyWith(
                                          color: RevoColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  reh.status.name.toUpperCase(),
                                  style: RevoTypography.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: RevoColors.primary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (_isAdmin) ...[
                    const Divider(height: RevoSpacing.xl),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: currentIsActive
                            ? RevoColors.errorCrimson
                            : RevoColors.successGreen,
                        side: BorderSide(
                          color: currentIsActive
                              ? RevoColors.errorCrimson
                              : RevoColors.successGreen,
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: RevoSpacing.md),
                      ),
                      icon: Icon(currentIsActive
                          ? Icons.build_circle_outlined
                          : Icons.check_circle_outline),
                      label: Text(
                        currentIsActive
                            ? 'Mark Venue Inactive / Under Maintenance'
                            : 'Restore Venue to Active Status',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () async {
                        await _dataService
                            .toggleVenueStatus(currentVenue.venueId);
                        setSheetState(() {});
                        setState(() {});
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RevoColors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          _isAdmin ? 'Venue Catalog & Management' : 'Theatre Venues',
          style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Venue',
              onPressed: _openCreateVenueSheet,
            ),
        ],
      ),
      body: StreamBuilder<List<Venue>>(
        stream: _dataService.watchVenues(),
        initialData: _dataService.getVenuesSync(),
        builder: (context, snapshot) {
          final allVenues = snapshot.data ?? [];
          final filteredVenues = _statusFilter == null
              ? allVenues
              : allVenues.where((v) => v.status == _statusFilter).toList();

          return Column(
            children: [
              // ── Filter Chips Bar ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RevoSpacing.lg,
                  vertical: RevoSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  color: RevoColors.cardBackground,
                  border: Border(
                    bottom: BorderSide(color: RevoColors.borderDefault),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Status: ',
                      style: RevoTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: RevoColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: RevoSpacing.xs),
                    FilterChip(
                      label: const Text('All'),
                      selected: _statusFilter == null,
                      onSelected: (_) =>
                          setState(() => _statusFilter = null),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: RevoSpacing.xs),
                    FilterChip(
                      label: const Text('Active'),
                      selected: _statusFilter == VenueStatus.active,
                      onSelected: (_) => setState(
                          () => _statusFilter = VenueStatus.active),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: RevoSpacing.xs),
                    FilterChip(
                      label: const Text('Maintenance'),
                      selected: _statusFilter == VenueStatus.inactive,
                      onSelected: (_) => setState(
                          () => _statusFilter = VenueStatus.inactive),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              // ── Venue Cards List ──────────────────────────────────────────
              Expanded(
                child: filteredVenues.isEmpty
                    ? Center(
                        child: AppStatusState.empty(
                          title: 'No Venues Found',
                          message:
                              'No theatre spaces match the current status filter.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(RevoSpacing.lg),
                        itemCount: filteredVenues.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: RevoSpacing.md),
                        itemBuilder: (context, index) {
                          final venue = filteredVenues[index];
                          final isActive =
                              venue.status == VenueStatus.active;
                          final venueRehearsals = _dataService
                              .getRehearsalsForVenue(venue.venueId);

                          return InkWell(
                            onTap: () => _showVenueDetailSheet(
                                venue, venueRehearsals),
                            borderRadius: RevoSpacing.borderRadiusCard,
                            child: Container(
                              padding: const EdgeInsets.all(RevoSpacing.lg),
                              decoration: BoxDecoration(
                                color: RevoColors.cardBackground,
                                borderRadius: RevoSpacing.borderRadiusCard,
                                border:
                                    Border.all(color: RevoColors.borderDefault),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          venue.name,
                                          style: RevoTypography.title2.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? RevoColors.successGreen
                                                  .withValues(alpha: 0.1)
                                              : RevoColors.errorCrimson
                                                  .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          isActive
                                              ? 'AVAILABLE'
                                              : 'MAINTENANCE',
                                          style:
                                              RevoTypography.caption.copyWith(
                                            color: isActive
                                                ? RevoColors.successGreen
                                                : RevoColors.errorCrimson,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: RevoSpacing.sm),
                                  Row(
                                    children: [
                                      const Icon(Icons.place_outlined,
                                          size: 14,
                                          color: RevoColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        venue.location,
                                        style:
                                            RevoTypography.caption.copyWith(
                                          color: RevoColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: RevoSpacing.md),
                                      const Icon(Icons.people_outline,
                                          size: 14,
                                          color: RevoColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Cap: ${venue.capacity}',
                                        style:
                                            RevoTypography.caption.copyWith(
                                          color: RevoColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: RevoSpacing.sm),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${venueRehearsals.length} upcoming bookings',
                                        style:
                                            RevoTypography.caption.copyWith(
                                          color: venueRehearsals.isNotEmpty
                                              ? RevoColors.primary
                                              : RevoColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          size: 18,
                                          color: RevoColors.textMuted),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openCreateVenueSheet,
              backgroundColor: RevoColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add Venue'),
            )
          : null,
    );
  }
}
