import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/cast_assignment.dart';
import '../models/production_role.dart';
import 'auth_identity.dart';
import 'firebase_auth_service.dart';
import 'cast_repository.dart';
import 'mock_data_service.dart';

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
  Stream<List<ProductionRole>> watchRoles(String productionId) {
    final fallback = MockDataService().getRolesForProduction(productionId);
    final query = _roles.where('productionId', isEqualTo: productionId);
    return Stream<List<ProductionRole>>.multi((controller) {
      controller.add(fallback);
      final subscription = query.snapshots().listen(
        (snapshot) {
          final items = snapshot.docs
              .map(
                (document) =>
                    ProductionRole.fromMap(document.data(), document.id),
              )
              .toList();
          controller.add(items.isNotEmpty ? items : fallback);
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.add(fallback);
        },
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<ProductionRole> createRole(RoleInput input) async {
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
    try {
      await _requireManager();
      await ref.set(role.toMap());
    } catch (_) {
      MockDataService().addRole(role);
    }
    return role;
  }

  @override
  Future<CastAssignment> assign({
    required String roleId,
    required String castMemberId,
  }) async {
    if (castMemberId.trim().isEmpty) {
      throw ArgumentError('Cast member ID cannot be empty.');
    }
    try {
      await _requireManager();
      final roleRef = _roles.doc(roleId);
      final roleSnapshot = await roleRef.get();
      if (!roleSnapshot.exists) {
        throw RevoException(
          RevoErrorCode.notFound,
          'Production role not found.',
        );
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
    } catch (_) {
      final dataService = MockDataService();
      final role = dataService.getRoleById(roleId);
      if (role == null) rethrow;
      dataService.assignCastToRole(
        roleId,
        castMemberId.trim(),
        productionId: role.productionId,
      );
      return dataService
          .getCastAssignmentsForProduction(role.productionId)
          .last;
    }
  }

  @override
  Future<void> removeAssignment(String assignmentId) async {
    try {
      await _requireManager();
      final ref = _assignments.doc(assignmentId);
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final assignment = CastAssignment.fromMap(
          snapshot.data()!,
          assignmentId,
        );
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
    } catch (_) {
      MockDataService().removeCastAssignment(assignmentId);
    }
  }

  @override
  Stream<List<CastAssignment>> watchAssignments(String productionId) {
    final fallback = MockDataService().getCastAssignmentsForProduction(
      productionId,
    );
    final query = _assignments
        .where('productionId', isEqualTo: productionId)
        .where('status', isEqualTo: AssignmentStatus.active.name);
    return Stream<List<CastAssignment>>.multi((controller) {
      controller.add(fallback);
      final subscription = query.snapshots().listen(
        (snapshot) {
          final items = snapshot.docs
              .map(
                (document) =>
                    CastAssignment.fromMap(document.data(), document.id),
              )
              .toList();
          controller.add(items.isNotEmpty ? items : fallback);
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.add(fallback);
        },
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<CastAssignment>> watchMyAssignments() {
    return Stream.fromFuture(_identityProvider.currentIdentity())
        .asyncExpand((identity) {
          final userId = identity?.userId ?? 'usr_cast_201';
          final fallback = MockDataService().getCastAssignmentsForUser(userId);
          if (identity == null || !identity.isFirebaseAuthenticated) {
            return Stream.value(fallback);
          }
          return _assignments
              .where('castMemberId', isEqualTo: userId)
              .where('status', isEqualTo: AssignmentStatus.active.name)
              .snapshots()
              .map((s) {
                final items = s.docs
                    .map((d) => CastAssignment.fromMap(d.data(), d.id))
                    .toList();
                return items.isNotEmpty ? items : fallback;
              })
              .handleError((_) => fallback);
        });
  }
}
