import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/director_interview_record.dart';
import '../../services/mock_data_service.dart';

/// Phase 10 & Issue #13: Director Interview & Operational Baseline Recording.
/// Implements structured evidence capture, quantitative baseline metrics with
/// explicit units, integrity verification, and validation status tracking.
class DirectorInterviewScreen extends StatefulWidget {
  const DirectorInterviewScreen({super.key});

  @override
  State<DirectorInterviewScreen> createState() =>
      _DirectorInterviewScreenState();
}

class _DirectorInterviewScreenState extends State<DirectorInterviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MockDataService _dataService = MockDataService();

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _contextController = TextEditingController();
  final _simultaneousProdsController = TextEditingController();
  final _castCountController = TextEditingController();
  final _rehearsalsPerWeekController = TextEditingController();
  final _scheduleChangesPerWeekController = TextEditingController();
  final _missedUpdatesController = TextEditingController();
  final _venueConflictsController = TextEditingController();
  final _coordinationHoursController = TextEditingController();
  final _businessImpactController = TextEditingController();
  final _monetaryEstimateController = TextEditingController();
  final _painPointsController = TextEditingController();
  final _evidenceRefController = TextEditingController();

  InterviewValidationStatus _selectedStatus = InterviewValidationStatus.notStarted;
  DateTime? _interviewDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExistingRecord();
  }

  void _loadExistingRecord() {
    final record = _dataService.getInterviewRecord();
    _nameController.text = record.intervieweeName;
    _roleController.text = record.role;
    _contextController.text = record.theatreContext;
    _interviewDate = record.interviewDate;

    if (record.simultaneousProductions != null) {
      _simultaneousProdsController.text =
          record.simultaneousProductions.toString();
    }
    if (record.castMembersCount != null) {
      _castCountController.text = record.castMembersCount.toString();
    }
    if (record.rehearsalsPerWeek != null) {
      _rehearsalsPerWeekController.text =
          record.rehearsalsPerWeek.toString();
    }
    if (record.scheduleChangesPerWeek != null) {
      _scheduleChangesPerWeekController.text =
          record.scheduleChangesPerWeek.toString();
    }
    if (record.missedUpdatesPerWeek != null) {
      _missedUpdatesController.text = record.missedUpdatesPerWeek.toString();
    }
    if (record.venueConflictsPerMonth != null) {
      _venueConflictsController.text =
          record.venueConflictsPerMonth.toString();
    }
    if (record.coordinationHoursPerWeek != null) {
      _coordinationHoursController.text =
          record.coordinationHoursPerWeek.toString();
    }
    if (record.businessImpactEstimate != null) {
      _businessImpactController.text = record.businessImpactEstimate!;
    }
    if (record.monetaryEstimate != null) {
      _monetaryEstimateController.text = record.monetaryEstimate!;
    }
    if (record.qualitativePainPoints != null) {
      _painPointsController.text = record.qualitativePainPoints!;
    }
    if (record.evidenceReference != null) {
      _evidenceRefController.text = record.evidenceReference!;
    }
    _selectedStatus = record.status;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _contextController.dispose();
    _simultaneousProdsController.dispose();
    _castCountController.dispose();
    _rehearsalsPerWeekController.dispose();
    _scheduleChangesPerWeekController.dispose();
    _missedUpdatesController.dispose();
    _venueConflictsController.dispose();
    _coordinationHoursController.dispose();
    _businessImpactController.dispose();
    _monetaryEstimateController.dispose();
    _painPointsController.dispose();
    _evidenceRefController.dispose();
    super.dispose();
  }

  void _saveRecord() {
    final simultaneousProds = int.tryParse(_simultaneousProdsController.text.trim());
    final castCount = int.tryParse(_castCountController.text.trim());
    final rehearsalsWeek = int.tryParse(_rehearsalsPerWeekController.text.trim());
    final changesWeek = int.tryParse(_scheduleChangesPerWeekController.text.trim());
    final missedUpdates = int.tryParse(_missedUpdatesController.text.trim());
    final conflictsMonth = int.tryParse(_venueConflictsController.text.trim());
    final coordHours = double.tryParse(_coordinationHoursController.text.trim());

    final updated = DirectorInterviewRecord(
      recordId: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      intervieweeName: _nameController.text.trim(),
      role: _roleController.text.trim().isNotEmpty
          ? _roleController.text.trim()
          : 'Theatre Director',
      interviewDate: _interviewDate,
      theatreContext: _contextController.text.trim().isNotEmpty
          ? _contextController.text.trim()
          : 'Regional Theatre Production',
      simultaneousProductions: simultaneousProds,
      castMembersCount: castCount,
      rehearsalsPerWeek: rehearsalsWeek,
      scheduleChangesPerWeek: changesWeek,
      missedUpdatesPerWeek: missedUpdates,
      venueConflictsPerMonth: conflictsMonth,
      coordinationHoursPerWeek: coordHours,
      businessImpactEstimate: _businessImpactController.text.trim().isNotEmpty
          ? _businessImpactController.text.trim()
          : null,
      monetaryEstimate: _monetaryEstimateController.text.trim().isNotEmpty
          ? _monetaryEstimateController.text.trim()
          : null,
      qualitativePainPoints: _painPointsController.text.trim().isNotEmpty
          ? _painPointsController.text.trim()
          : null,
      evidenceReference: _evidenceRefController.text.trim().isNotEmpty
          ? _evidenceRefController.text.trim()
          : null,
      status: _selectedStatus,
    );

    _dataService.saveInterviewRecord(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Baseline record updated. Uncollected fields retained as uncollected.'),
        backgroundColor: RevoColors.primary,
      ),
    );

    setState(() {});
    _tabController.animateTo(2); // Jump to record preview tab
  }

  Color _getStatusColor(InterviewValidationStatus status) {
    switch (status) {
      case InterviewValidationStatus.verified:
        return RevoColors.successGreen;
      case InterviewValidationStatus.completedAwaitingVerification:
        return const Color(0xFF5B6BBF);
      case InterviewValidationStatus.draft:
        return RevoColors.warningAmber;
      case InterviewValidationStatus.notStarted:
        return RevoColors.textMuted;
    }
  }

  String _getStatusLabel(InterviewValidationStatus status) {
    switch (status) {
      case InterviewValidationStatus.verified:
        return 'VERIFIED';
      case InterviewValidationStatus.completedAwaitingVerification:
        return 'AWAITING VERIFICATION';
      case InterviewValidationStatus.draft:
        return 'DRAFT';
      case InterviewValidationStatus.notStarted:
        return 'NOT STARTED (OUTSTANDING)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RevoColors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Baseline & Director Interview'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: RevoColors.primary,
          labelColor: RevoColors.primary,
          unselectedLabelColor: RevoColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'PRD Targets'),
            Tab(text: 'Record Data'),
            Tab(text: 'Current Record'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrdTargetsTab(),
          _buildRecorderFormTab(),
          _buildCurrentRecordTab(),
        ],
      ),
    );
  }

  // ── Tab 1: PRD Targets & Baseline Goals ─────────────────────────────────────
  Widget _buildPrdTargetsTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(RevoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(RevoSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: RevoSpacing.borderRadiusCard,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 36,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: RevoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRD v1.1 Operational Target Gates',
                        style: RevoTypography.title2.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sprint 2 pre-submission validation metrics. Targets must be measured against real director baseline post-pilot.',
                        style: RevoTypography.caption.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RevoSpacing.xl),
          Text(
            'Target Outcomes (Baseline Evidence Criteria)',
            style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: RevoSpacing.md),
          _buildKpiCard(
            icon: Icons.timer,
            title: 'Coordination Time Reduction',
            metric: '≥ 30%',
            description:
                'Target reduction in weekly schedule searching & conflict resolution time.',
          ),
          _buildKpiCard(
            icon: Icons.notifications_active_outlined,
            title: 'Delayed Schedule Updates',
            metric: '≥ 50%',
            description:
                'Target reduction in late/missed cast notifications across concurrent productions.',
          ),
          _buildKpiCard(
            icon: Icons.meeting_room_outlined,
            title: 'Venue Double-Bookings',
            metric: '0 Conflicts',
            description:
                'Zero confirmed venue conflicts in production schedules with pre-confirmation checks.',
          ),
          _buildKpiCard(
            icon: Icons.group_off_outlined,
            title: 'Cast Rehearsal Overlaps',
            metric: '0 Overlaps',
            description:
                'Zero confirmed cast member schedule overlaps across active productions.',
          ),
          const SizedBox(height: RevoSpacing.xl),
          Text(
            'Evidence Integrity Rule',
            style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: RevoSpacing.sm),
          Container(
            padding: const EdgeInsets.all(RevoSpacing.md),
            decoration: BoxDecoration(
              color: RevoColors.cardBackground,
              borderRadius: RevoSpacing.borderRadiusCard,
              border: Border.all(color: RevoColors.borderDefault),
            ),
            child: Text(
              'Per Revo Product Requirements and Issue #13 rules: In the absence of a completed interview with an authentic theatre director, baseline fields must remain null/uncollected. Real-world validation remains an open project gate until verified with a primary director stakeholder.',
              style: RevoTypography.bodyMedium.copyWith(
                color: RevoColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String title,
    required String metric,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: RevoSpacing.sm),
      padding: const EdgeInsets.all(RevoSpacing.md),
      decoration: BoxDecoration(
        color: RevoColors.cardBackground,
        borderRadius: RevoSpacing.borderRadiusCard,
        border: Border.all(color: RevoColors.borderDefault),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: RevoColors.primary.withValues(alpha: 0.12),
            child: Icon(icon, color: RevoColors.primary, size: 20),
          ),
          const SizedBox(width: RevoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: RevoTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: RevoColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        metric,
                        style: RevoTypography.caption.copyWith(
                          color: RevoColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Interactive Baseline Data Recorder Form ─────────────────────────
  Widget _buildRecorderFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(RevoSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(RevoSpacing.md),
              decoration: BoxDecoration(
                color: RevoColors.warningAmber.withValues(alpha: 0.1),
                borderRadius: RevoSpacing.borderRadiusCard,
                border: Border.all(
                  color: RevoColors.warningAmber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: RevoColors.warningAmber, size: 24),
                  const SizedBox(width: RevoSpacing.md),
                  Expanded(
                    child: Text(
                      'Evidence Integrity Notice: Leave unknown or unmeasured fields blank. Do NOT fabricate numbers.',
                      style: RevoTypography.caption.copyWith(
                        color: RevoColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RevoSpacing.lg),

            // Section 1: Stakeholder Identification
            Text(
              '1. Interviewee & Context',
              style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: RevoSpacing.sm),
            AppTextField(
              controller: _nameController,
              label: 'Interviewee Name or Anonymized ID',
              hint: 'e.g. Director Sarah J. (or DIR-INT-01)',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _roleController,
              label: 'Stakeholder Role / Title',
              hint: 'e.g. Artistic Director / Production Lead',
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _contextController,
              label: 'Theatre / Company Context',
              hint: 'e.g. Regional Community Theatre, 3 concurrent productions',
              prefixIcon: const Icon(Icons.theater_comedy_outlined),
            ),
            const SizedBox(height: RevoSpacing.lg),

            // Section 2: Quantitative Baseline Metrics
            Text(
              '2. Quantitative Operational Baselines',
              style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Provide explicit units and time periods for each observed measurement.',
              style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _simultaneousProdsController,
              label: 'Simultaneous Productions (count at interview time)',
              hint: 'e.g. 3',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.movie_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _castCountController,
              label: 'Active Cast Members (approximate count)',
              hint: 'e.g. 28',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.people_alt_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _rehearsalsPerWeekController,
              label: 'Rehearsals (count per week)',
              hint: 'e.g. 12',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.event_repeat_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _scheduleChangesPerWeekController,
              label: 'Schedule Changes (count per week)',
              hint: 'e.g. 5',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.edit_calendar_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _missedUpdatesController,
              label: 'Delayed / Missed Schedule Updates (count per week)',
              hint: 'e.g. 3',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.warning_amber_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _venueConflictsController,
              label: 'Venue Collisions / Conflicts (count per month)',
              hint: 'e.g. 2',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.meeting_room_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _coordinationHoursController,
              label: 'Coordination Time Spent (hours per week)',
              hint: 'e.g. 8.5',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: const Icon(Icons.hourglass_bottom_outlined),
            ),
            const SizedBox(height: RevoSpacing.lg),

            // Section 3: Business Impact & Evidence
            Text(
              '3. Qualitative Observations & Business Impact',
              style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _painPointsController,
              label: 'Coordination Pain Points & Notes',
              hint: 'Describe key operational bottlenecks observed during season',
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _businessImpactController,
              label: "Director's Coordination Impact Estimate",
              hint: 'e.g. Estimated 15–20 hours/month lost to rescheduling',
              prefixIcon: const Icon(Icons.assessment_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _monetaryEstimateController,
              label: 'Monetary Impact Estimate (Optional, only if provided)',
              hint: 'Leave blank if not calculated by stakeholder',
              prefixIcon: const Icon(Icons.attach_money_outlined),
            ),
            const SizedBox(height: RevoSpacing.md),
            AppTextField(
              controller: _evidenceRefController,
              label: 'Evidence Reference / Transcript Link',
              hint: 'e.g. Meeting notes doc, audio recording reference',
              prefixIcon: const Icon(Icons.link_outlined),
            ),
            const SizedBox(height: RevoSpacing.lg),

            // Section 4: Validation Status
            Text(
              '4. Verification Status',
              style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: RevoSpacing.sm),
            DropdownButtonFormField<InterviewValidationStatus>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                filled: true,
                fillColor: RevoColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: RevoSpacing.borderRadiusButton,
                ),
              ),
              items: InterviewValidationStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedStatus = val);
                }
              },
            ),
            const SizedBox(height: RevoSpacing.xl),
            PrimaryButton(
              label: 'Save Baseline Record',
              onPressed: _saveRecord,
            ),
            const SizedBox(height: RevoSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Tab 3: Saved Record Overview ───────────────────────────────────────────
  Widget _buildCurrentRecordTab() {
    final record = _dataService.getInterviewRecord();
    final statusColor = _getStatusColor(record.status);
    final hasUncollected = record.hasUncollectedFields;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(RevoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Validation Status Badge Banner
          Container(
            padding: const EdgeInsets.all(RevoSpacing.lg),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: RevoSpacing.borderRadiusCard,
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECORD VALIDATION STATUS',
                      style: RevoTypography.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusLabel(record.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RevoSpacing.sm),
                Text(
                  record.status == InterviewValidationStatus.verified
                      ? 'This record has been verified with primary director evidence.'
                      : record.status == InterviewValidationStatus.draft
                          ? 'This record is currently in Draft status. Real-world validation remains an open requirement.'
                          : 'No empirical interview data has been recorded yet. Real director interview remains outstanding.',
                  style: RevoTypography.bodyMedium.copyWith(
                    color: RevoColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RevoSpacing.xl),

          // Overview Details
          _buildRecordDetailCard(
            title: 'Interview Details',
            rows: [
              _buildDetailRow('Interviewee', record.intervieweeName.isNotEmpty ? record.intervieweeName : 'Unspecified / Anonymous'),
              _buildDetailRow('Role', record.role),
              _buildDetailRow('Theatre Context', record.theatreContext),
              _buildDetailRow('Recorded On', record.interviewDate != null ? '${record.interviewDate!.month}/${record.interviewDate!.day}/${record.interviewDate!.year}' : 'Date not set'),
            ],
          ),
          const SizedBox(height: RevoSpacing.md),

          // Quantitative Baseline Metrics
          _buildRecordDetailCard(
            title: 'Quantitative Measurements (with Units)',
            rows: [
              _buildDetailRow('Simultaneous Shows', record.simultaneousProductions != null ? '${record.simultaneousProductions} productions' : '— [Uncollected]'),
              _buildDetailRow('Active Cast Members', record.castMembersCount != null ? '${record.castMembersCount} actors' : '— [Uncollected]'),
              _buildDetailRow('Weekly Rehearsals', record.rehearsalsPerWeek != null ? '${record.rehearsalsPerWeek} rehearsals/week' : '— [Uncollected]'),
              _buildDetailRow('Schedule Changes', record.scheduleChangesPerWeek != null ? '${record.scheduleChangesPerWeek} changes/week' : '— [Uncollected]'),
              _buildDetailRow('Delayed Updates', record.missedUpdatesPerWeek != null ? '${record.missedUpdatesPerWeek} delayed updates/week' : '— [Uncollected]'),
              _buildDetailRow('Venue Collisions', record.venueConflictsPerMonth != null ? '${record.venueConflictsPerMonth} conflicts/month' : '— [Uncollected]'),
              _buildDetailRow('Coordination Time', record.coordinationHoursPerWeek != null ? '${record.coordinationHoursPerWeek} hours/week' : '— [Uncollected]'),
            ],
          ),
          const SizedBox(height: RevoSpacing.md),

          // Qualitative & Impact Details
          _buildRecordDetailCard(
            title: 'Qualitative Impact & Evidence Reference',
            rows: [
              _buildDetailRow('Reported Pain Points', record.qualitativePainPoints ?? '— [None recorded]'),
              _buildDetailRow('Business Impact Estimate', record.businessImpactEstimate ?? '— [None estimated]'),
              _buildDetailRow('Monetary Estimate', record.monetaryEstimate ?? '— [None estimated]'),
              _buildDetailRow('Evidence Reference', record.evidenceReference ?? '— [None provided]'),
            ],
          ),
          const SizedBox(height: RevoSpacing.lg),

          if (hasUncollected)
            Container(
              padding: const EdgeInsets.all(RevoSpacing.md),
              decoration: BoxDecoration(
                color: RevoColors.cardBackground,
                borderRadius: RevoSpacing.borderRadiusCard,
                border: Border.all(color: RevoColors.borderDefault),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: RevoColors.textSecondary, size: 20),
                  const SizedBox(width: RevoSpacing.sm),
                  Expanded(
                    child: Text(
                      'Uncollected fields are preserved as null in accordance with PRD evidence integrity rules.',
                      style: RevoTypography.caption.copyWith(color: RevoColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: RevoSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildRecordDetailCard({
    required String title,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(RevoSpacing.lg),
      decoration: BoxDecoration(
        color: RevoColors.cardBackground,
        borderRadius: RevoSpacing.borderRadiusCard,
        border: Border.all(color: RevoColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: RevoTypography.title2.copyWith(fontWeight: FontWeight.w700),
          ),
          const Divider(height: RevoSpacing.lg),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: RevoTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: RevoColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: RevoTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: value.contains('[Uncollected]')
                    ? RevoColors.warningAmber
                    : RevoColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
