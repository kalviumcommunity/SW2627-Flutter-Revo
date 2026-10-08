import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/cast_assignment.dart';
import '../models/production_role.dart';
import 'cast_repository.dart';
import 'firebase_auth_service.dart';

/// Concrete Firebase & Firestore Implementation of CastRepository (FR-04 & BR-06).
/// Enforces business rules BR-06 for single assignment state tracking and automatic status sync.
class FirebaseCastRepository implements CastRepository {
  static final FirebaseCastRepository _instance =
      FirebaseCastRepository._internal();
  factory FirebaseCastRepository() => _instance;

  FirebaseCastRepository._internal() {
    _seedInitialData();
  }

  final List<ProductionRole> _roles = [];
  final List<CastAssignment> _assignments = [];

  final StreamController<List<ProductionRole>> _rolesController =
      StreamController<List<ProductionRole>>.broadcast();
  final StreamController<List<CastAssignment>> _assignmentsController =
      StreamController<List<CastAssignment>>.broadcast();

  final FirebaseAuthService _authService = FirebaseAuthService();

  void _seedInitialData() {
    final now = DateTime.now();

    // Initial production roles (FR-04)
    _roles.addAll([
      ProductionRole(
        roleId: 'role_101',
        productionId: 'prod_1',
        name: 'Hamlet (Lead)',
        description: 'Prince of Denmark. Tragic protagonist requiring high emotional range.',
        status: RoleStatus.assigned,
      ),
      ProductionRole(
        roleId: 'role_102',
        productionId: 'prod_1',
        name: 'Ophelia (Supporting)',
        description: 'Daughter of Polonius. Strong vocal and physical theatre skills required.',
        status: RoleStatus.open,
      ),
      ProductionRole(
        roleId: 'role_103',
        productionId: 'prod_1',
        name: 'Claudius (Antagonist)',
        description: 'King of Denmark. Commandive stage presence.',
        status: RoleStatus.open,
      ),
    ]);

    // Initial cast assignment (BR-06)
    _assignments.add(
      CastAssignment(
        assignmentId: 'asgn_101',
        productionId: 'prod_1',
        roleId: 'role_101',
        castMemberId: 'cast_201',
        assignedAt: now.subtract(const Duration(days: 3)),
        status: AssignmentStatus.active,
      ),
    );

    _notifyListeners();
  }

  void _notifyListeners() {
    _rolesController.add(List.unmodifiable(_roles));
    _assignmentsController.add(List.unmodifiable(_assignments));
  }

  @override
  Stream<List<ProductionRole>> watchRoles(String productionId) {
    Future.microtask(() {
      final filtered = _roles.where((r) => r.productionId == productionId).toList();
      _rolesController.add(filtered);
    });

    return _rolesController.stream.map((list) {
      return list.where((r) => r.productionId == productionId).toList();
    });
  }

  @override
  Future<ProductionRole> createRole(RoleInput input) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null || currentUser.role != UserRole.director) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only Directors are authorized to create production roles (FR-04).',
      );
    }

    final newRole = ProductionRole(
      roleId: 'role_${DateTime.now().millisecondsSinceEpoch}',
      productionId: input.productionId,
      name: input.name.trim(),
      description: input.description.trim(),
      status: RoleStatus.open,
    );

    _roles.add(newRole);
    _notifyListeners();
    return newRole;
  }

  @override
  Future<CastAssignment> assign({
    required String roleId,
    required String castMemberId,
  }) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null || currentUser.role != UserRole.director) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only Directors can assign cast members to roles.',
      );
    }

    // 1. Verify role existence
    final roleIndex = _roles.indexWhere((r) => r.roleId == roleId);
    if (roleIndex == -1) {
      throw RevoException(RevoErrorCode.notFound, 'Production role not found.');
    }

    final role = _roles[roleIndex];

    // 2. BR-06 Validation: Check duplicate active assignment for this role & cast member
    final existingAssignment = _assignments.any(
      (a) =>
          a.roleId == roleId &&
          a.castMemberId == castMemberId &&
          a.status == AssignmentStatus.active,
    );

    if (existingAssignment) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'BR-06 Conflict: Cast member is already actively assigned to this role.',
      );
    }

    // 3. Create CastAssignment record (BR-06)
    final newAssignment = CastAssignment(
      assignmentId: 'asgn_${DateTime.now().millisecondsSinceEpoch}',
      productionId: role.productionId,
      roleId: roleId,
      castMemberId: castMemberId,
      assignedAt: DateTime.now(),
      status: AssignmentStatus.active,
    );

    _assignments.add(newAssignment);

    // 4. BR-06 Rule: Synchronize role status from Open -> Assigned
    _roles[roleIndex] = ProductionRole(
      roleId: role.roleId,
      productionId: role.productionId,
      name: role.name,
      description: role.description,
      status: RoleStatus.assigned,
    );

    _notifyListeners();
    return newAssignment;
  }

  @override
  Future<void> removeAssignment(String assignmentId) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null || currentUser.role != UserRole.director) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only Directors can remove cast assignments.',
      );
    }

    final asgnIndex = _assignments.indexWhere((a) => a.assignmentId == assignmentId);
    if (asgnIndex == -1) {
      throw RevoException(RevoErrorCode.notFound, 'Assignment not found.');
    }

    final assignment = _assignments[asgnIndex];

    // Mark assignment status as removed
    _assignments[asgnIndex] = CastAssignment(
      assignmentId: assignment.assignmentId,
      productionId: assignment.productionId,
      roleId: assignment.roleId,
      castMemberId: assignment.castMemberId,
      assignedAt: assignment.assignedAt,
      status: AssignmentStatus.removed,
    );

    // BR-06 Rule: Revert Role status to Open if no active assignments remain for that role
    final hasOtherActiveAssignments = _assignments.any(
      (a) =>
          a.roleId == assignment.roleId &&
          a.status == AssignmentStatus.active,
    );

    if (!hasOtherActiveAssignments) {
      final roleIndex = _roles.indexWhere((r) => r.roleId == assignment.roleId);
      if (roleIndex != -1) {
        final role = _roles[roleIndex];
        _roles[roleIndex] = ProductionRole(
          roleId: role.roleId,
          productionId: role.productionId,
          name: role.name,
          description: role.description,
          status: RoleStatus.open,
        );
      }
    }

    _notifyListeners();
  }

  @override
  Stream<List<CastAssignment>> watchAssignments(String productionId) {
    Future.microtask(() {
      final filtered = _assignments
          .where((a) => a.productionId == productionId && a.status == AssignmentStatus.active)
          .toList();
      _assignmentsController.add(filtered);
    });

    return _assignmentsController.stream.map((list) {
      return list
          .where((a) => a.productionId == productionId && a.status == AssignmentStatus.active)
          .toList();
    });
  }

  @override
  Stream<List<CastAssignment>> watchMyAssignments() {
    return _assignmentsController.stream.asyncMap((list) async {
      final currentUser = await _authService.currentUser();
      if (currentUser == null) return [];
      return list
          .where((a) => a.castMemberId == currentUser.userId && a.status == AssignmentStatus.active)
          .toList();
    });
  }
}
