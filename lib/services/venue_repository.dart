import '../models/rehearsal.dart';
import '../models/venue.dart';

/// Abstract repository defining venue operations for UI screens and
/// future Firebase implementations (FR-06, Issue #13, Issue #11).
abstract class VenueRepository {
  /// Reactive stream of venues, optionally filtered by active status.
  Stream<List<Venue>> watchVenues({bool activeOnly = false});

  /// Retrieve current snapshot of venues, optionally filtered by active status.
  Future<List<Venue>> getVenues({bool activeOnly = false});

  /// Retrieve a venue by its unique ID.
  Future<Venue?> getVenue(String venueId);

  /// Create a new venue (Admin only).
  Future<Venue> createVenue(VenueInput input);

  /// Update an existing venue's details (Admin only).
  Future<void> updateVenue(String venueId, VenueInput input);

  /// Toggle venue status between active and underMaintenance (Admin only).
  Future<void> toggleStatus(String venueId);

  /// Retrieve scheduled rehearsals for [venueId].
  Future<List<Rehearsal>> getRehearsalsForVenue(String venueId);

  /// Resolve production title for a given [productionId].
  Future<String> getProductionName(String productionId);

  /// Retrieve booked time ranges for [venueId] on a given [day].
  Future<List<TimeRange>> getBookings(String venueId, DateTime day);
}
