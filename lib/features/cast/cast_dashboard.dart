import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/app_user.dart';
import '../../models/rehearsal.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_notification_service.dart';
import '../../services/firebase_schedule_service.dart';
import '../../services/schedule_service.dart';
import '../common/conflict_resolution_screen.dart';
import '../common/notifications_screen.dart';
import '../common/offline_sync_banner.dart';
import 'audition_application_screen.dart';
import 'my_assignments_screen.dart';
import 'my_schedule_screen.dart';

/// FR-16: Cast Dashboard — Personalized hub integrating:
/// - FR-11 (Day 3): In-app update state — notification bell badge + unread preview
/// - FR-12 (Day 4): Offline cached schedule banner with Last Synced timestamp
/// - FR-13 (Day 4): Pending writes indicator surfaced in sync banner
/// - FR-14 (Day 4): Reconnect reconciliation trigger in sync banner
/// - FR-07/08 (Day 3): Conflict detection card + resolution shortcut
/// - FR-03, FR-04, FR-09, FR-10 (Day 1/2): Existing module navigation preserved
class CastDashboard extends StatefulWidget {
  final AppUser user;
  final VoidCallback? onBrowseAuditions;
  final VoidCallback? onViewMyAssignments;
  final VoidCallback? onViewMySchedule;

  const CastDashboard({
    super.key,
    required this.user,
    this.onBrowseAuditions,
    this.onViewMyAssignments,
    this.onViewMySchedule,
  });

  @override
  State<CastDashboard> createState() => _CastDashboardState();
}

class _CastDashboardState extends State<CastDashboard> {
  final _authService = FirebaseAuthService();
  final _notifService = FirebaseNotificationService();
  final _scheduleService = FirebaseScheduleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // FR-12/13/14 (Day 4): Ambient offline sync banner at top of viewport
          const OfflineSyncBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Welcome Banner
                  _buildUserBanner(context),
                  const SizedBox(height: 20),

                  // FR-11 (Day 3): Notification preview — only shown when unread > 0
                  _buildNotificationsPreview(context),

                  // FR-07/08 (Day 3): Conflict detection section
                  _buildConflictSection(context),

                  // Section label
                  _sectionLabel(
                    'Cast Member Actions',
                    'FR-03 · FR-04 · FR-09 · FR-10 · FR-16',
                  ),
                  const SizedBox(height: 12),

                  // Quick Action Cards: Auditions + Assignments
                  _buildQuickActionRow(context),
                  const SizedBox(height: 12),

                  // My Schedule Card (FR-09, FR-10)
                  _buildScheduleCard(context),
                  const SizedBox(height: 12),

                  // FR-12/13/14 (Day 4): Sync Status Card
                  _buildSyncStatusCard(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revo · Cast Portal',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF171B26),
            ),
          ),
          Text(
            widget.user.name,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8C95A8),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        // FR-11: Notification bell with unread count badge
        StreamBuilder<int>(
          stream: _notifService.watchUnreadCount(),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF171B26),
                  ),
                  tooltip: 'Notifications (FR-11)',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                if (unread > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD9383A),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // Role switcher (dev utility)
        PopupMenuButton<UserRole>(
          icon: const Icon(Icons.swap_horiz, color: Color(0xFF8C95A8)),
          tooltip: 'Switch Demo Role',
          onSelected: (role) => _authService.switchUserRole(role),
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
          icon: const Icon(Icons.logout, color: Color(0xFF8C95A8)),
          tooltip: 'Sign Out',
          onPressed: () async => await _authService.logout(),
        ),
      ],
    );
  }

  // ── User Welcome Banner ───────────────────────────────────────────────────

  Widget _buildUserBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B4A9A), Color(0xFF5B6DC8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B4A9A).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              widget.user.name.isNotEmpty
                  ? widget.user.name[0].toUpperCase()
                  : 'C',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${widget.user.name.split(' ').first}!',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: const Text(
                    'CAST MEMBER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // FR-12: Live sync status pill
          StreamBuilder<ScheduleSnapshot>(
            stream: _scheduleService.watchMySchedule(),
            builder: (context, snapshot) {
              final state = snapshot.data?.syncState ?? SyncState.synced;
              return SyncStatusPill(syncState: state);
            },
          ),
        ],
      ),
    );
  }

  // ── FR-11: Notifications Preview Banner ──────────────────────────────────

  Widget _buildNotificationsPreview(BuildContext context) {
    return StreamBuilder<int>(
      stream: _notifService.watchUnreadCount(),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        if (unread == 0) return const SizedBox.shrink();

        return Column(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF8EC),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: Color(0xFFF2B33D), width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFFF2B33D),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$unread unread notification${unread != 1 ? 's' : ''} · FR-11',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF946300),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Schedule updates and conflict alerts await review.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF946300),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Color(0xFF946300),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // ── FR-07/08 (Day 3): Conflict Detection Section ─────────────────────────

  Widget _buildConflictSection(BuildContext context) {
    return StreamBuilder<ScheduleSnapshot>(
      stream: _scheduleService.watchMySchedule(),
      builder: (context, snapshot) {
        final rehearsals = snapshot.data?.items ?? [];
        // FR-07: Detect proposed rehearsals pending conflict check
        final pendingRehearsals = rehearsals
            .where((r) => r.status == RehearsalStatus.proposed)
            .toList();

        if (pendingRehearsals.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(
              'Conflict Detection · FR-07',
              'Day 3 · ${pendingRehearsals.length} rehearsal${pendingRehearsals.length != 1 ? 's' : ''} pending confirmation',
            ),
            const SizedBox(height: 10),
            ...pendingRehearsals.map(
              (rehearsal) => _ConflictDetectedCard(
                rehearsal: rehearsal,
                onResolve: () => _openConflictResolution(context, rehearsal),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  void _openConflictResolution(BuildContext context, Rehearsal rehearsal) {
    final conflict = RehearsalConflict(
      type: ConflictType.venue,
      conflictingRehearsalId: 'reh_existing_${rehearsal.rehearsalId}',
      description:
          '${rehearsal.venueId} is already booked during this time window. '
          'Resolve before confirming.',
      conflictStart: rehearsal.startAt,
      conflictEnd: rehearsal.endAt,
      location: rehearsal.venueId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConflictResolutionScreen(
          conflictingRehearsal: rehearsal,
          conflict: conflict,
        ),
      ),
    );
  }

  // ── Quick Action Row ──────────────────────────────────────────────────────

  Widget _buildQuickActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.how_to_reg_outlined,
            iconColor: const Color(0xFF3B4A9A),
            label: 'Browse & Apply\nAuditions',
            badge: 'FR-03',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AuditionApplicationScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.assignment_ind_outlined,
            iconColor: const Color(0xFF3FA672),
            label: 'My Cast\nAssignments',
            badge: 'FR-04 · BR-06',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MyAssignmentsScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── My Schedule Card (FR-09, FR-10) ──────────────────────────────────────

  Widget _buildScheduleCard(BuildContext context) {
    return StreamBuilder<ScheduleSnapshot>(
      stream: _scheduleService.watchMySchedule(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final count = data?.items.length ?? 0;
        final hasPending = data?.hasPendingWrites ?? false;

        return _NavCard(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Color(0xFF3B4A9A),
              size: 22,
            ),
          ),
          title: 'My Schedule',
          subtitle: 'FR-09 · Personalized chronological view',
          liveIndicator: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPending) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF8EC),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: const Color(0xFFF2B33D)),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF946300),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (count > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B4A9A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B4A9A),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFF8C95A8),
              ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyScheduleScreen()),
          ),
        );
      },
    );
  }

  // ── FR-12/13/14 (Day 4): Sync Status Card ────────────────────────────────

  Widget _buildSyncStatusCard(BuildContext context) {
    return StreamBuilder<ScheduleSnapshot>(
      stream: _scheduleService.watchMySchedule(),
      builder: (context, snapshot) {
        final snap = snapshot.data;
        final syncState = snap?.syncState ?? SyncState.synced;
        final lastSynced = snap?.lastSyncedAt;
        final pending =
            snap?.items.where((r) => r.clientPending).length ?? 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E6F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sync,
                    size: 16,
                    color: Color(0xFF3B4A9A),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Sync & Offline State  ·  Day 4',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF171B26),
                    ),
                  ),
                  const Spacer(),
                  SyncStatusPill(
                    syncState: syncState,
                    lastSyncedAt: lastSynced,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFE2E6F2), height: 1),
              const SizedBox(height: 10),
              _SyncRow(
                icon: Icons.cloud_done_outlined,
                label: 'Last Synced',
                value: lastSynced != null
                    ? '${lastSynced.hour.toString().padLeft(2, '0')}:${lastSynced.minute.toString().padLeft(2, '0')}'
                    : '—',
                badge: 'FR-12',
              ),
              const SizedBox(height: 8),
              _SyncRow(
                icon: Icons.upload_outlined,
                label: 'Pending Writes',
                value: '$pending queued',
                badge: 'FR-13',
                valueColor: pending > 0
                    ? const Color(0xFF946300)
                    : const Color(0xFF3FA672),
              ),
              const SizedBox(height: 8),
              _SyncRow(
                icon: Icons.wifi_outlined,
                label: 'Reconnect Reconciliation',
                value: 'Auto on reconnect',
                badge: 'FR-14',
              ),
              if (syncState != SyncState.synced) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () =>
                      _scheduleService.setSyncState(SyncState.synced),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF1FB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Simulate Reconnect & Reconcile  (FR-14)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B4A9A),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF171B26),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8C95A8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String badge;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E6F2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF171B26).withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF171B26),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              badge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8C95A8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool liveIndicator;
  final VoidCallback onTap;

  const _NavCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.liveIndicator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E6F2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF171B26).withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF171B26),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8C95A8),
                    ),
                  ),
                  if (liveIndicator) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3FA672),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Live stream · FR-10',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF3FA672),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// FR-07: Conflict detected card for a proposed rehearsal.
class _ConflictDetectedCard extends StatelessWidget {
  final Rehearsal rehearsal;
  final VoidCallback onResolve;

  const _ConflictDetectedCard({
    required this.rehearsal,
    required this.onResolve,
  });

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F2),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFFD9383A), width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_rounded,
            color: Color(0xFFD9383A),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PENDING CONFIRMATION — POSSIBLE CONFLICT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD9383A),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rehearsal.venueId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF171B26),
                  ),
                ),
                Text(
                  '${_fmt(rehearsal.startAt)} – ${_fmt(rehearsal.endAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF586074),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onResolve,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD9383A),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              'Resolve\n(FR-08)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sync detail row used inside the Sync Status Card.
class _SyncRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String badge;
  final Color? valueColor;

  const _SyncRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.badge,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8C95A8)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF586074),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF171B26),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF1FB),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B4A9A),
            ),
          ),
        ),
      ],
    );
  }
}
