import '../models/cast_assignment.dart';
import '../models/production_role.dart';

abstract class CastRepository {
  Stream<List<ProductionRole>> watchRoles(String productionId);
  Future<ProductionRole> createRole(RoleInput input);
  Future<CastAssignment> assign({required String roleId, required String castMemberId});
  Future<void> removeAssignment(String assignmentId);
  Stream<List<CastAssignment>> watchAssignments(String productionId);
  Stream<List<CastAssignment>> watchMyAssignments(); // Cast
}
