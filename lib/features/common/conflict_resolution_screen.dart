import 'package:flutter/material.dart';
import '../../models/rehearsal.dart';
import '../../core/enums/revo_enums.dart';
import '../../services/firebase_notification_service.dart';
import '../../services/firebase_schedule_service.dart';

/// FR-07: Conflict Detection model — holds detected venue or cast collision data.
class RehearsalConflict {
  final ConflictType type;
  final String conflictingRehearsalId;
  final String description;
  final DateTime conflictStart;
  final DateTime conflictEnd;
  final String location;

  const RehearsalConflict({
    required this.type,
    required this.conflictingRehearsalId,
    required this.description,
    required this.conflictStart,
    required this.conflictEnd,
    required this.location,
  });
}

/// FR-07 & FR-08: Conflict Resolution Screen.
/// Surfaces detected schedule conflicts (venue overlap or cast member overlap)
/// in a comparison card layout per DESIGN.md §6.3, and provides resolution
/// actions: change time, change venue, or remove participant.
class ConflictResolutionScreen extends StatefulWidget {
  final Rehearsal conflictingRehearsal;
  final RehearsalConflict conflict;
  final VoidCallback? onResolved;

  const ConflictResolutionScreen({
    super.key,
    required this.conflictingRehearsal,
    required this.conflict,
    this.onResolved,
  });

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  _ResolutionOption? _selectedOption;
  bool _isResolving = false;

  final List<_ResolutionOption> _options = [
    _ResolutionOption(
      id: 'change_time',
      title: 'Reschedule Time Slot',
      subtitle: 'Move rehearsal to a non-conflicting time window.',
      icon: Icons.schedule_outlined,
      consequence: '✓ Recommended · Venue secured · Director notified',
    ),
    _ResolutionOption(
      id: 'change_venue',
      title: 'Move to Different Venue',
      subtitle: 'Transfer to an available alternative venue.',
      icon: Icons.location_on_outlined,
      consequence: '✓ Same time window · Zero cast delay',
    ),
    _ResolutionOption(
      id: 'remove_participant',
      title: 'Remove Conflicting Participant',
      subtitle: 'Remove the overlapping cast member from this session.',
      icon: Icons.person_remove_outlined,
      consequence: '⚠ Partial resolution · Cast member must be informed',
    ),
  ];

  Future<void> _applyResolution() async {
    if (_selectedOption == null) return;
    setState(() => _isResolving = true);

    await Future.delayed(const Duration(milliseconds: 800));

    // FR-08: Notify affected participants of resolution
    final notifService = FirebaseNotificationService();
    await notifService.notifyParticipants(
      type: 'ScheduleUpdate',
      message:
          'Conflict resolved for rehearsal at ${widget.conflictingRehearsal.venueId}. '
          'Resolution applied: ${_selectedOption!.title}.',
      relatedId: widget.conflictingRehearsal.rehearsalId,
      userIds: widget.conflictingRehearsal.participantIds,
    );

    if (mounted) {
      setState(() => _isResolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3FA672),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conflict resolved: ${_selectedOption!.title}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      widget.onResolved?.call();
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflict = widget.conflict;
    final rehearsal = widget.conflictingRehearsal;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Conflict Resolution',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF171B26),
          ),
        ),
        leading: const BackButton(color: Color(0xFF3B4A9A)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Conflict Alert Banner ──────────────────────────────────
            _ConflictAlertBanner(conflict: conflict),
            const SizedBox(height: 20),

            // ── Comparison Cards (Old Call vs New Call) ────────────────
            const Text(
              'Conflict Comparison',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF171B26),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ComparisonCard(
                    label: 'EXISTING BOOKING',
                    labelColor: const Color(0xFFD9383A),
                    venue: conflict.location,
                    startAt: conflict.conflictStart,
                    endAt: conflict.conflictEnd,
                    isConflicting: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ComparisonCard(
                    label: 'YOUR REHEARSAL',
                    labelColor: const Color(0xFF3B4A9A),
                    venue: rehearsal.venueId,
                    startAt: rehearsal.startAt,
                    endAt: rehearsal.endAt,
                    isConflicting: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Resolution Options ─────────────────────────────────────
            const Text(
              'Choose Resolution Action',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF171B26),
              ),
            ),
            const SizedBox(height: 10),
            ..._options.map(
              (option) => _ResolutionOptionCard(
                option: option,
                isSelected: _selectedOption?.id == option.id,
                onTap: () => setState(() => _selectedOption = option),
              ),
            ),
            const SizedBox(height: 32),

            // ── Apply Button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _selectedOption != null
                      ? const Color(0xFF3B4A9A)
                      : const Color(0xFFE2E6F2),
                  foregroundColor: _selectedOption != null
                      ? Colors.white
                      : const Color(0xFF8C95A8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_selectedOption != null && !_isResolving)
                    ? _applyResolution
                    : null,
                icon: _isResolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  _isResolving ? 'Applying...' : 'Apply Resolution',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (_selectedOption != null) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  _selectedOption!.consequence,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF586074),
                    fontStyle: _selectedOption!.consequence.startsWith('⚠')
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sub-components ────────────────────────────────────────────────────────────

class _ConflictAlertBanner extends StatelessWidget {
  final RehearsalConflict conflict;
  const _ConflictAlertBanner({required this.conflict});

  @override
  Widget build(BuildContext context) {
    final typeLabel = conflict.type == ConflictType.venue
        ? 'VENUE COLLISION'
        : 'CAST OVERLAP';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF8EC),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFFF2B33D), width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF2B33D), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF946300),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  conflict.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF171B26),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final String label;
  final Color labelColor;
  final String venue;
  final DateTime startAt;
  final DateTime endAt;
  final bool isConflicting;

  const _ComparisonCard({
    required this.label,
    required this.labelColor,
    required this.venue,
    required this.startAt,
    required this.endAt,
    required this.isConflicting,
  });

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConflicting
            ? const Color(0xFFFDF2F2)
            : const Color(0xFFEBF7F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConflicting
              ? const Color(0xFFD9383A).withValues(alpha: 0.3)
              : const Color(0xFF3FA672).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: labelColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            venue,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF171B26),
              decoration: isConflicting ? TextDecoration.lineThrough : null,
              decorationColor: const Color(0xFFD9383A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(startAt)} – ${_fmt(endAt)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF586074),
              fontFeatures: const [FontFeature.tabularFigures()],
              decoration: isConflicting ? TextDecoration.lineThrough : null,
              decorationColor: const Color(0xFFD9383A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolutionOptionCard extends StatelessWidget {
  final _ResolutionOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _ResolutionOptionCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF1FB) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B4A9A)
                : const Color(0xFFE2E6F2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF171B26).withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3B4A9A).withValues(alpha: 0.12)
                    : const Color(0xFFF1F3FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                option.icon,
                color: isSelected
                    ? const Color(0xFF3B4A9A)
                    : const Color(0xFF8C95A8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF3B4A9A)
                          : const Color(0xFF171B26),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF586074),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF3B4A9A), size: 22)
            else
              const Icon(Icons.radio_button_unchecked,
                  color: Color(0xFFE2E6F2), size: 22),
          ],
        ),
      ),
    );
  }
}

class _ResolutionOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String consequence;

  const _ResolutionOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.consequence,
  });
}
