import '../core/enums/revo_enums.dart';
import '../models/cast_assignment.dart';
import '../models/production.dart';
import '../models/production_role.dart';
import '../models/rehearsal.dart';
import '../models/venue.dart';

/// Abstract repository defining production operations for UI screens and
/// future Firebase implementations (FR-02, Issue #13, Issue #11).
abstract class ProductionRepository {
  /// Reactive stream of productions scoped to the user role:
  /// - Director: sees only productions where `directorId == userId`
  /// - Admin: sees all theatre productions
  Stream<List<Production>> watchProductions({
    required String userId,
    required UserRole role,
  });

  /// Asynchronous retrieval of productions scoped to the user role.
  Future<List<Production>> getProductions({
    required String userId,
    required UserRole role,
  });

  /// Retrieve a single production by unique ID.
  Future<Production?> getProduction(String productionId);

  /// Create a new production.
  Future<Production> createProduction(
    ProductionInput input, {
    String? directorId,
  });

  /// Update an existing production's metadata.
  Future<void> updateProduction(
    String productionId,
    ProductionInput input,
  );

  /// Update production lifecycle status.
  Future<void> setStatus(
    String productionId,
    ProductionStatus status,
  );

  // ── Associated Production Metadata ─────────────────────────────────────────

  /// Resolve director display name from [directorId].
  Future<String> getDirectorName(String directorId);

  /// Retrieve character / production roles for [productionId].
  Future<List<ProductionRole>> getRolesForProduction(String productionId);

  /// Retrieve cast assignments for [productionId].
  Future<List<CastAssignment>> getCastAssignmentsForProduction(String productionId);

  /// Retrieve scheduled rehearsals for [productionId].
  Future<List<Rehearsal>> getRehearsalsForProduction(String productionId);

  /// Retrieve venues associated with [productionId]'s rehearsals.
  Future<List<Venue>> getVenuesForProduction(String productionId);

  /// Resolve a cast member / user display name from [userId].
  Future<String> getUserName(String userId);

  /// Look up a venue by [venueId].
  Future<Venue?> getVenueById(String venueId);
}
