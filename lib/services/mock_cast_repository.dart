import '../models/cast_assignment.dart';
import '../models/production_role.dart';
import '../core/enums/revo_enums.dart';
import 'cast_repository.dart';
import 'mock_data_service.dart';

class MockCastRepository implements CastRepository {
  final MockDataService _dataService = MockDataService();

  @override
  Stream<List<ProductionRole>> watchRoles(String productionId) async* {
    yield _dataService.getRolesForProduction(productionId);
    yield* _dataService.watchProductions().asyncMap(
      (_) => _dataService.getRolesForProduction(productionId),
    );
  }

  @override
  Future<ProductionRole> createRole(RoleInput input) async {
    if (input.name.trim().isEmpty) {
      throw ArgumentError('Role name cannot be empty.');
    }
    final role = ProductionRole(
      roleId: 'role_${DateTime.now().millisecondsSinceEpoch}',
      productionId: input.productionId,
      name: input.name.trim(),
      description: input.description.trim(),
      status: RoleStatus.open,
    );
    _dataService.addRole(role);
    return role;
  }

  @override
  Future<CastAssignment> assign({
    required String roleId,
    required String castMemberId,
  }) async {
    final role = _dataService.getRoleById(roleId);
    if (role == null) {
      throw StateError('Production role not found.');
    }
    _dataService.assignCastToRole(
      roleId,
      castMemberId,
      productionId: role.productionId,
    );
    return _dataService.getCastAssignmentsForProduction(role.productionId).last;
  }

  @override
  Future<void> removeAssignment(String assignmentId) async {
    _dataService.removeCastAssignment(assignmentId);
  }

  @override
  Stream<List<CastAssignment>> watchAssignments(String productionId) async* {
    yield _dataService.getCastAssignmentsForProduction(productionId);
    yield* _dataService.watchProductions().asyncMap(
      (_) => _dataService.getCastAssignmentsForProduction(productionId),
    );
  }

  @override
  Stream<List<CastAssignment>> watchMyAssignments() async* {
    yield _dataService.getCastAssignmentsForUser('usr_cast_201');
  }
}
