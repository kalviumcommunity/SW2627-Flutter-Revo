import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/app_user.dart';
import '../models/cast_assignment.dart';
import '../models/production.dart';
import '../models/production_role.dart';
import '../models/rehearsal.dart';
import '../models/venue.dart';
import 'mock_data_service.dart';
import 'production_repository.dart';

/// In-memory mock implementation of [ProductionRepository] (FR-02, Issue #13).
/// Backed by the shared [MockDataService] singleton to guarantee cross-screen
/// data consistency without exposing mock concrete classes to the presentation layer.
class MockProductionRepository implements ProductionRepository {
  static final MockProductionRepository _instance =
      MockProductionRepository._internal();

  factory MockProductionRepository({MockDataService? dataService}) {
    if (dataService != null) {
      return MockProductionRepository._custom(dataService);
    }
    return _instance;
  }

  final MockDataService _dataService;

  MockProductionRepository._internal() : _dataService = MockDataService();
  MockProductionRepository._custom(this._dataService);

  @override
  Stream<List<Production>> watchProductions({
    required String userId,
    required UserRole role,
  }) async* {
    yield await getProductions(userId: userId, role: role);
    yield* _dataService.watchProductions().map((list) {
      if (role == UserRole.director) {
        return list.where((p) => p.directorId == userId).toList();
      }
      return list;
    });
  }

  @override
  Future<List<Production>> getProductions({
    required String userId,
    required UserRole role,
  }) async {
    final syntheticUser = AppUser(
      userId: userId,
      role: role,
      name: '',
      email: '',
      createdAt: DateTime.now(),
    );
    return _dataService.getProductionsForUserSync(syntheticUser);
  }

  @override
  Future<Production?> getProduction(String productionId) async {
    return _dataService.getProductionById(productionId);
  }

  @override
  Future<Production> createProduction(
    ProductionInput input, {
    String? directorId,
  }) async {
    if (input.name.trim().isEmpty) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Production name cannot be empty.',
      );
    }
    if (input.endDate.isBefore(input.startDate)) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'End date cannot precede start date.',
      );
    }
    return _dataService.createProduction(
      input: input,
      directorId: directorId ?? 'usr_dir_101',
    );
  }

  @override
  Future<void> updateProduction(
    String productionId,
    ProductionInput input,
  ) async {
    final existing = _dataService.getProductionById(productionId);
    if (existing == null) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Production $productionId not found.',
      );
    }
    await _dataService.updateProduction(
      productionId: productionId,
      input: input,
    );
  }

  @override
  Future<void> setStatus(
    String productionId,
    ProductionStatus status,
  ) async {
    final existing = _dataService.getProductionById(productionId);
    if (existing == null) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Production $productionId not found.',
      );
    }

    await _dataService.updateProduction(
      productionId: productionId,
      input: ProductionInput(
        name: existing.name,
        description: existing.description,
        startDate: existing.startDate,
        endDate: existing.endDate,
        status: status,
      ),
    );
  }

  @override
  Future<void> deleteProduction(String productionId) async {
    final existing = _dataService.getProductionById(productionId);
    if (existing == null) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Production $productionId not found.',
      );
    }
    await _dataService.deleteProduction(productionId);
  }

  @override
  Future<String> getDirectorName(String directorId) async {
    return _dataService.getDirectorName(directorId);
  }

  @override
  Future<List<ProductionRole>> getRolesForProduction(String productionId) async {
    return _dataService.getRolesForProduction(productionId);
  }

  @override
  Future<List<CastAssignment>> getCastAssignmentsForProduction(
    String productionId,
  ) async {
    return _dataService.getCastAssignmentsForProduction(productionId);
  }

  @override
  Future<List<Rehearsal>> getRehearsalsForProduction(String productionId) async {
    return _dataService.getRehearsalsForProduction(productionId);
  }

  @override
  Future<List<Venue>> getVenuesForProduction(String productionId) async {
    return _dataService.getVenuesForProduction(productionId);
  }

  @override
  Future<String> getUserName(String userId) async {
    return _dataService.getUserName(userId);
  }

  @override
  Future<Venue?> getVenueById(String venueId) async {
    return _dataService.getVenueById(venueId);
  }
}
