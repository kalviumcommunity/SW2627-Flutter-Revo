/// Roles in Revo System
enum UserRole {
  director,
  cast,
  admin,
}

/// Production status enum
enum ProductionStatus {
  planning,
  casting,
  rehearsing,
  completed,
  cancelled,
}

/// Audition status enum
enum AuditionStatus {
  open,
  closed,
  cancelled,
}

/// Application status enum
enum ApplicationStatus {
  submitted,
  shortlisted,
  selected,
  rejected,
  withdrawn,
}

/// Role status enum
enum RoleStatus {
  open,
  assigned,
  inactive,
}

/// Assignment status enum
enum AssignmentStatus {
  active,
  removed,
}

/// Rehearsal status enum
enum RehearsalStatus {
  proposed,
  confirmed,
  cancelled,
}

/// Venue status enum
enum VenueStatus {
  active,
  inactive,
}

/// Conflict type enum
enum ConflictType {
  venue,
  cast,
}

/// Network & Sync State enum
enum SyncState {
  synced,
  stale,
  offline,
  pending,
  conflict,
}

/// Independent Connectivity State (FR-12, FR-13)
enum ConnectivityState {
  online,
  offline,
  unknown,
}

/// Independent Data Freshness State (FR-12)
enum DataFreshness {
  fresh,
  stale,
  unknown,
}

/// Independent Write Synchronization State (FR-13)
enum WriteSyncStatus {
  pending,
  confirmed,
  failed,
}
