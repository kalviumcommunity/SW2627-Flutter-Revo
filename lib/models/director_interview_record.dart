/// Validation status for director interview and empirical baseline recording.
enum InterviewValidationStatus {
  notStarted,
  draft,
  completedAwaitingVerification,
  verified,
}

/// Structured data model for documenting a real theatre director interview
/// and operational baseline metrics in compliance with PRD v1.1 and Issue #13.
class DirectorInterviewRecord {
  final String recordId;
  final String intervieweeName;
  final String role;
  final DateTime? interviewDate;
  final String theatreContext;
  
  // Quantitative Baseline Metrics (with explicit units and periods)
  final int? simultaneousProductions; // count at interview time
  final int? castMembersCount; // approximate count
  final int? rehearsalsPerWeek; // rehearsals / week
  final int? scheduleChangesPerWeek; // schedule changes / week
  final int? missedUpdatesPerWeek; // delayed/missed updates / week
  final int? venueConflictsPerMonth; // venue collisions / month
  final double? coordinationHoursPerWeek; // hours / week searching/correcting

  // Business Impact Estimate (Director's ballpark, never fabricated)
  final String? businessImpactEstimate; // e.g. "Estimated 15-20 hours / month"
  final String? monetaryEstimate; // null unless explicitly provided by stakeholder
  
  // Supporting Qualitative Evidence & Notes
  final String? qualitativePainPoints;
  final String? evidenceReference;
  final InterviewValidationStatus status;

  const DirectorInterviewRecord({
    required this.recordId,
    required this.intervieweeName,
    required this.role,
    this.interviewDate,
    required this.theatreContext,
    this.simultaneousProductions,
    this.castMembersCount,
    this.rehearsalsPerWeek,
    this.scheduleChangesPerWeek,
    this.missedUpdatesPerWeek,
    this.venueConflictsPerMonth,
    this.coordinationHoursPerWeek,
    this.businessImpactEstimate,
    this.monetaryEstimate,
    this.qualitativePainPoints,
    this.evidenceReference,
    this.status = InterviewValidationStatus.notStarted,
  });

  /// Baseline record template with uncollected fields marked null (no invented figures)
  factory DirectorInterviewRecord.emptyTemplate() {
    return const DirectorInterviewRecord(
      recordId: 'rec_template',
      intervieweeName: '',
      role: 'Theatre Director / Production Lead',
      theatreContext: 'Regional Community Theatre (3-5 simultaneous productions)',
      status: InterviewValidationStatus.notStarted,
    );
  }

  DirectorInterviewRecord copyWith({
    String? recordId,
    String? intervieweeName,
    String? role,
    DateTime? interviewDate,
    String? theatreContext,
    int? simultaneousProductions,
    int? castMembersCount,
    int? rehearsalsPerWeek,
    int? scheduleChangesPerWeek,
    int? missedUpdatesPerWeek,
    int? venueConflictsPerMonth,
    double? coordinationHoursPerWeek,
    String? businessImpactEstimate,
    String? monetaryEstimate,
    String? qualitativePainPoints,
    String? evidenceReference,
    InterviewValidationStatus? status,
  }) {
    return DirectorInterviewRecord(
      recordId: recordId ?? this.recordId,
      intervieweeName: intervieweeName ?? this.intervieweeName,
      role: role ?? this.role,
      interviewDate: interviewDate ?? this.interviewDate,
      theatreContext: theatreContext ?? this.theatreContext,
      simultaneousProductions:
          simultaneousProductions ?? this.simultaneousProductions,
      castMembersCount: castMembersCount ?? this.castMembersCount,
      rehearsalsPerWeek: rehearsalsPerWeek ?? this.rehearsalsPerWeek,
      scheduleChangesPerWeek:
          scheduleChangesPerWeek ?? this.scheduleChangesPerWeek,
      missedUpdatesPerWeek: missedUpdatesPerWeek ?? this.missedUpdatesPerWeek,
      venueConflictsPerMonth:
          venueConflictsPerMonth ?? this.venueConflictsPerMonth,
      coordinationHoursPerWeek:
          coordinationHoursPerWeek ?? this.coordinationHoursPerWeek,
      businessImpactEstimate:
          businessImpactEstimate ?? this.businessImpactEstimate,
      monetaryEstimate: monetaryEstimate ?? this.monetaryEstimate,
      qualitativePainPoints:
          qualitativePainPoints ?? this.qualitativePainPoints,
      evidenceReference: evidenceReference ?? this.evidenceReference,
      status: status ?? this.status,
    );
  }

  /// True if any quantitative field remains uncollected (evidence integrity guard)
  bool get hasUncollectedFields =>
      simultaneousProductions == null ||
      castMembersCount == null ||
      rehearsalsPerWeek == null ||
      scheduleChangesPerWeek == null ||
      missedUpdatesPerWeek == null ||
      venueConflictsPerMonth == null ||
      coordinationHoursPerWeek == null;
}
