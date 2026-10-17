import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/cast_assignment.dart';
import '../models/production_role.dart';
import 'auth_identity.dart';
import 'firebase_auth_service.dart';
import 'cast_repository.dart';

class FirebaseCastRepository implements CastRepository {
  FirebaseCastRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuthIdentityProvider? identityProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityProvider =
           identityProvider ??
           (auth != null
               ? FirebaseAuthIdentityProvider(
                   auth: auth,
                   firestore: firestore ?? FirebaseFirestore.instance,
                 )
               : FirebaseAuthService());

  final FirebaseFirestore _firestore;
  final AuthIdentityProvider _identityProvider;

  CollectionReference<Map<String, dynamic>> get _roles =>
      _firestore.collection('roles');
  CollectionReference<Map<String, dynamic>> get _assignments =>
      _firestore.collection('castAssignments');

  Future<String> _requireManager() async {
    final identity = await _identityProvider.currentIdentity();
    if (identity == null || !identity.isFirebaseAuthenticated) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Authentication is required.',
      );
    }
    if (identity.role != UserRole.director && identity.role != UserRole.admin) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only directors or admins can manage cast assignments.',
      );
    }
    return identity.userId;
  }

  @override
  Stream<List<ProductionRole>> watchRoles(String productionId) => _roles
      .where('productionId', isEqualTo: productionId)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => ProductionRole.fromMap(d.data(), d.id)).toList(),
      );

  @override
  Future<ProductionRole> createRole(RoleInput input) async {
    await _requireManager();
    if (input.name.trim().isEmpty) {
      throw ArgumentError('Role name cannot be empty.');
    }
    final ref = _roles.doc();
    final role = ProductionRole(
      roleId: ref.id,
      productionId: input.productionId,
      name: input.name.trim(),
      description: input.description.trim(),
      status: RoleStatus.open,
    );
    await ref.set(role.toMap());
    return role;
  }

  @override
  Future<CastAssignment> assign({
    required String roleId,
    required String castMemberId,
  }) async {
    await _requireManager();
    if (castMemberId.trim().isEmpty) {
      throw ArgumentError('Cast member ID cannot be empty.');
    }
    final roleRef = _roles.doc(roleId);
    final roleSnapshot = await roleRef.get();
    if (!roleSnapshot.exists) {
      throw RevoException(RevoErrorCode.notFound, 'Production role not found.');
    }
    final role = ProductionRole.fromMap(roleSnapshot.data()!, roleId);
    final existing = await _assignments
        .where('roleId', isEqualTo: roleId)
        .where('castMemberId', isEqualTo: castMemberId)
        .where('status', isEqualTo: AssignmentStatus.active.name)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Cast member is already actively assigned to this role.',
      );
    }
    final ref = _assignments.doc();
    final assignment = CastAssignment(
      assignmentId: ref.id,
      productionId: role.productionId,
      roleId: roleId,
      castMemberId: castMemberId.trim(),
      assignedAt: DateTime.now(),
      status: AssignmentStatus.active,
    );
    final batch = _firestore.batch()
      ..set(ref, assignment.toMap())
      ..update(roleRef, {'status': RoleStatus.assigned.name});
    await batch.commit();
    return assignment;
  }

  @override
  Future<void> removeAssignment(String assignmentId) async {
    await _requireManager();
    final ref = _assignments.doc(assignmentId);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw RevoException(RevoErrorCode.notFound, 'Assignment not found.');
    }
    final assignment = CastAssignment.fromMap(snapshot.data()!, assignmentId);
    final active = await _assignments
        .where('roleId', isEqualTo: assignment.roleId)
        .where('status', isEqualTo: AssignmentStatus.active.name)
        .get();
    final batch = _firestore.batch()
      ..update(ref, {'status': AssignmentStatus.removed.name});
    if (active.docs.length <= 1) {
      batch.update(_roles.doc(assignment.roleId), {
        'status': RoleStatus.open.name,
      });
    }
    await batch.commit();
  }

  @override
  Stream<List<CastAssignment>> watchAssignments(String productionId) =>
      _assignments
          .where('productionId', isEqualTo: productionId)
          .where('status', isEqualTo: AssignmentStatus.active.name)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => CastAssignment.fromMap(d.data(), d.id))
                .toList(),
          );

  @override
  Stream<List<CastAssignment>> watchMyAssignments() {
    return Stream.fromFuture(_identityProvider.currentIdentity())
        .asyncExpand((identity) {
          if (identity == null || !identity.isFirebaseAuthenticated) {
            return Stream.value(const <CastAssignment>[]);
          }
          return _assignments
              .where('castMemberId', isEqualTo: identity.userId)
              .where('status', isEqualTo: AssignmentStatus.active.name)
              .snapshots()
              .map(
                (s) => s.docs
                    .map((d) => CastAssignment.fromMap(d.data(), d.id))
                    .toList(),
              );
        });
  }
}
