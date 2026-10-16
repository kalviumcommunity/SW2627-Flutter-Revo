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
import '../../services/venue_repository.dart';

/// FR-06 & Issue #13: Venue Management and Catalog Screen.
/// Accessible by Theatre Admin for full venue lifecycle management (create,
/// edit, toggle active/maintenance status), and by Directors for read-only
/// operational availability verification.
/// Depends on [VenueRepository] interface rather than concrete mock services.
class VenueManagementScreen extends StatefulWidget {
  final AppUser user;
  final VenueRepository venueRepository;

  const VenueManagementScreen({
    super.key,
    required this.user,
    required this.venueRepository,
  });

  @override
  State<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _VenueManagementScreenState extends State<VenueManagementScreen> {
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
                      'Add New Rehearsal Space',
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
                  hint: 'e.g. Studio C Dance Studio',
                  prefixIcon: const Icon(Icons.theater_comedy),
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
                          'notes': notesController.text.trim(),
                        },
                      );
                      await widget.venueRepository.createVenue(input);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: RevoColors.successGreen,
                            content: Text('${input.name} added successfully.'),
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

  void _showVenueBookingsModal(Venue venue) {
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
            return FutureBuilder<Venue?>(
              future: widget.venueRepository.getVenue(venue.venueId),
              builder: (context, venueSnap) {
                final currentVenue = venueSnap.data ?? venue;
                final currentIsActive =
                    currentVenue.status == VenueStatus.active;

                return FutureBuilder<List<Rehearsal>>(
                  future: widget.venueRepository
                      .getRehearsalsForVenue(currentVenue.venueId),
                  builder: (context, rehearsalsSnap) {
                    final updatedRehearsals = rehearsalsSnap.data ?? [];

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
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: RevoSpacing.xs),
                          Text(
                            '${currentVenue.location} · Maximum ${currentVenue.capacity} people',
                            style: RevoTypography.bodyMedium.copyWith(
                              color: RevoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: RevoSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: currentIsActive
                                  ? RevoColors.successGreen
                                      .withValues(alpha: 0.12)
                                  : RevoColors.errorCrimson
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              currentIsActive
                                  ? 'STATUS: OPERATIONAL & ACTIVE'
                                  : 'STATUS: UNDER MAINTENANCE / UNAVAILABLE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: currentIsActive
                                    ? RevoColors.successGreen
                                    : RevoColors.errorCrimson,
                              ),
                            ),
                          ),
                          const Divider(height: RevoSpacing.xl),
                          Text(
                            'UPCOMING REHEARSAL BOOKINGS',
                            style: RevoTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: RevoColors.textMuted,
                              letterSpacing: 0.6,
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
                              constraints:
                                  const BoxConstraints(maxHeight: 200),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: updatedRehearsals.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: RevoSpacing.xs),
                                itemBuilder: (ctx, idx) {
                                  final reh = updatedRehearsals[idx];
                                  return Container(
                                    padding:
                                        const EdgeInsets.all(RevoSpacing.sm),
                                    decoration: BoxDecoration(
                                      color:
                                          RevoColors.surfaceContainerHigh,
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
                                              FutureBuilder<String>(
                                                future: widget.venueRepository
                                                    .getProductionName(
                                                        reh.productionId),
                                                builder: (c, pSnap) => Text(
                                                  pSnap.data ?? 'Production',
                                                  style: RevoTypography.caption
                                                      .copyWith(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${reh.startAt.month}/${reh.startAt.day} · ${reh.startAt.hour.toString().padLeft(2, '0')}:${reh.startAt.minute.toString().padLeft(2, '0')} – ${reh.endAt.hour.toString().padLeft(2, '0')}:${reh.endAt.minute.toString().padLeft(2, '0')}',
                                                style: RevoTypography.caption
                                                    .copyWith(
                                                  color:
                                                      RevoColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: reh.status ==
                                                    RehearsalStatus.confirmed
                                                ? RevoColors.successGreen
                                                    .withValues(alpha: 0.1)
                                                : RevoColors.warningAmber
                                                    .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            reh.status.name.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: reh.status ==
                                                      RehearsalStatus.confirmed
                                                  ? RevoColors.successGreen
                                                  : RevoColors.warningAmber,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (_isAdmin) ...[
                            const SizedBox(height: RevoSpacing.lg),
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
                                    vertical: RevoSpacing.sm),
                              ),
                              icon: Icon(currentIsActive
                                  ? Icons.build_circle_outlined
                                  : Icons.check_circle_outline),
                              label: Text(
                                currentIsActive
                                    ? 'Mark Venue Inactive / Under Maintenance'
                                    : 'Restore Venue to Active Status',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              onPressed: () async {
                                await widget.venueRepository
                                    .toggleStatus(currentVenue.venueId);
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
          },
        );
      },
    );
  }

  void _showVenueDetailSheet(Venue venue, List<Rehearsal> rehearsals) {
    _showVenueBookingsModal(venue);
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
        stream: widget.venueRepository.watchVenues(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: AppStatusState.error(
                title: 'Error Loading Venues',
                message: snapshot.error.toString(),
                actionLabel: 'Retry',
                onAction: () => setState(() {}),
              ),
            );
          }

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

                          return FutureBuilder<List<Rehearsal>>(
                            future: widget.venueRepository
                                .getRehearsalsForVenue(venue.venueId),
                            builder: (context, snap) {
                              final venueRehearsals = snap.data ?? [];

                              return InkWell(
                                onTap: () => _showVenueDetailSheet(
                                    venue, venueRehearsals),
                                borderRadius: RevoSpacing.borderRadiusCard,
                                child: Container(
                                  padding:
                                      const EdgeInsets.all(RevoSpacing.lg),
                                  decoration: BoxDecoration(
                                    color: RevoColors.cardBackground,
                                    borderRadius:
                                        RevoSpacing.borderRadiusCard,
                                    border: Border.all(
                                        color: RevoColors.borderDefault),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              venue.name,
                                              style: RevoTypography.title2
                                                  .copyWith(
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
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isActive
                                                    ? RevoColors.successGreen
                                                        .withValues(alpha: 0.3)
                                                    : RevoColors.errorCrimson
                                                        .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              isActive
                                                  ? 'ACTIVE'
                                                  : 'MAINTENANCE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isActive
                                                    ? RevoColors.successGreen
                                                    : RevoColors.errorCrimson,
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
                                              color:
                                                  RevoColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            venue.location,
                                            style: RevoTypography.caption
                                                .copyWith(
                                              color: RevoColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(
                                              width: RevoSpacing.md),
                                          const Icon(Icons.people_outline,
                                              size: 14,
                                              color:
                                                  RevoColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Cap: ${venue.capacity}',
                                            style: RevoTypography.caption
                                                .copyWith(
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
                                            style: RevoTypography.caption
                                                .copyWith(
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
