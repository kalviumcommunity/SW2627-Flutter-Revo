import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/app_user.dart';
import 'auth_identity.dart';
import 'auth_service.dart';

/// Firebase-backed authentication. The default instance never creates a local
/// identity; demo authentication is available only through [demo].
class FirebaseAuthService implements AuthService, AuthIdentityProvider {
  static FirebaseAuthService? _instance;
  static FirebaseAuthService? _uninitializedInstance;

  factory FirebaseAuthService() {
    if (Firebase.apps.isEmpty) {
      return _uninitializedInstance ??= FirebaseAuthService._uninitialized();
    }
    return _instance ??= FirebaseAuthService._internal(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );
  }

  factory FirebaseAuthService.withDependencies({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) => FirebaseAuthService._internal(auth: auth, firestore: firestore);

  factory FirebaseAuthService.demo() => FirebaseAuthService._demo();

  FirebaseAuthService._internal({required this._auth, required this._firestore})
    : _demoMode = false,
      _unavailable = false;

  FirebaseAuthService._uninitialized()
    : _auth = null,
      _firestore = null,
      _demoMode = false,
      _unavailable = true;

  FirebaseAuthService._demo()
    : _auth = null,
      _firestore = null,
      _demoMode = true,
      _unavailable = false {
    _demoUsers.addAll({
      'dir_101': AppUser(
        userId: 'dir_101',
        name: 'Sarah Jenkins (Director)',
        email: 'director@revo.com',
        role: UserRole.director,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      'cast_201': AppUser(
        userId: 'cast_201',
        name: 'Alex Rivera (Cast)',
        email: 'cast@revo.com',
        role: UserRole.cast,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      'admin_301': AppUser(
        userId: 'admin_301',
        name: 'Elena Rostova (Admin)',
        email: 'admin@revo.com',
        role: UserRole.admin,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    });
  }

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final bool _demoMode;
  final bool _unavailable;
  final Map<String, AppUser> _demoUsers = {};
  final StreamController<AppUser?> _demoAuthController =
      StreamController<AppUser?>.broadcast();
  AppUser? _demoCurrentUser;

  bool get isDemoMode => _demoMode;

  @override
  Stream<AppUser?> authStateChanges() {
    if (_unavailable) return Stream.value(null);
    if (isDemoMode) {
      return _demoAuthController.stream;
    }
    return _auth!.authStateChanges().asyncMap(_profileForFirebaseUser);
  }

  @override
  Future<AppUser?> currentUser() async {
    if (_unavailable) return null;
    if (isDemoMode) return _demoCurrentUser;
    return _profileForFirebaseUser(_auth!.currentUser);
  }

  Future<AppUser?> _profileForFirebaseUser(User? user) async {
    if (user == null) return null;
    final document = await _firestore!.collection('users').doc(user.uid).get();
    if (!document.exists || document.data() == null) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Authenticated user profile is missing.',
      );
    }
    final role = userRoleFromValue(document.data()!['role']);
    if (role == null) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Authenticated user profile has an invalid role.',
      );
    }
    return AppUser.fromMap(document.data()!, document.id);
  }

  @override
  Future<AuthIdentity?> currentIdentity() async {
    if (_unavailable) return null;
    if (isDemoMode) {
      final user = _demoCurrentUser;
      return user == null
          ? null
          : AuthIdentity(userId: user.userId, role: user.role);
    }
    final user = _auth!.currentUser;
    if (user == null) return null;
    final profile = await _firestore!.collection('users').doc(user.uid).get();
    return firebaseIdentityFromProfile(
      userId: user.uid,
      exists: profile.exists,
      data: profile.data(),
    );
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Email and password cannot be empty.',
      );
    }
    if (_unavailable) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Firebase has not been initialized.',
      );
    }
    if (isDemoMode) {
      final user = _demoUsers.values.cast<AppUser?>().firstWhere(
        (candidate) =>
            candidate!.email.toLowerCase() == email.trim().toLowerCase(),
        orElse: () => null,
      );
      if (user == null) {
        throw RevoException(
          RevoErrorCode.unauthenticated,
          'Unknown demo account.',
        );
      }
      _demoCurrentUser = user;
      _demoAuthController.add(user);
      return user;
    }
    final credential = await _auth!.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final profile = await _profileForFirebaseUser(credential.user);
    if (profile == null) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Firebase did not return an authenticated user.',
      );
    }
    return profile;
  }

  @override
  Future<AppUser> signInWithGoogle({UserRole defaultRole = UserRole.cast}) async {
    if (_unavailable) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Firebase has not been initialized.',
      );
    }
    if (isDemoMode) {
      final user = _demoUsers['dir_101'] ?? _demoUsers.values.first;
      _demoCurrentUser = user;
      _demoAuthController.add(user);
      return user;
    }

    try {
      final googleProvider = GoogleAuthProvider();
      final credential = await _auth!.signInWithPopup(googleProvider);
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw RevoException(
          RevoErrorCode.unauthenticated,
          'Google Sign-In was cancelled or failed.',
        );
      }

      // Check if user profile exists in Firestore
      final userDoc = await _firestore!.collection('users').doc(firebaseUser.uid).get();
      if (!userDoc.exists) {
        final newProfile = AppUser(
          userId: firebaseUser.uid,
          name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'Google User',
          email: firebaseUser.email ?? '',
          role: defaultRole,
          createdAt: DateTime.now().toUtc(),
        );
        await _firestore.collection('users').doc(firebaseUser.uid).set(newProfile.toMap());
        return newProfile;
      }

      final profile = await _profileForFirebaseUser(firebaseUser);
      if (profile == null) {
        throw RevoException(
          RevoErrorCode.notFound,
          'User profile could not be loaded from Firestore.',
        );
      }
      return profile;
    } catch (e) {
      if (e is RevoException) rethrow;
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Google Sign-In failed: $e',
      );
    }
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.cast,
    String? adminPasscode,
  }) async {
    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        password.trim().isEmpty) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'All registration fields are required.',
      );
    }
    if (_unavailable) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Firebase has not been initialized.',
      );
    }
    if (isDemoMode) {
      final user = AppUser(
        userId: 'demo_${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        email: email.trim(),
        role: UserRole.cast,
        createdAt: DateTime.now(),
      );
      _demoUsers[user.userId] = user;
      _demoCurrentUser = user;
      _demoAuthController.add(user);
      return user;
    }
    final credential = await _auth!.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Firebase did not return the newly created user.',
      );
    }
    final profile = AppUser(
      userId: firebaseUser.uid,
      name: name.trim(),
      email: email.trim(),
      role: role, // Bug 2 fix: use the supplied role instead of always defaulting to UserRole.cast
      createdAt: DateTime.now(),
    );
    try {
      await _firestore!
          .collection('users')
          .doc(firebaseUser.uid)
          .set(profile.toMap());
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
    return profile;
  }

  @override
  Future<void> logout() async {
    if (_unavailable) return;
    if (isDemoMode) {
      _demoCurrentUser = null;
      _demoAuthController.add(null);
    } else {
      await _auth!.signOut();
    }
  }

  /// Demo-only role switching retained for local UI walkthroughs.
  void switchUserRole(UserRole newRole) {
    if (!isDemoMode || _demoCurrentUser == null) return;
    final user = _demoCurrentUser!;
    _demoCurrentUser = AppUser(
      userId: user.userId,
      name: user.name,
      email: user.email,
      role: newRole,
      createdAt: user.createdAt,
    );
    _demoAuthController.add(_demoCurrentUser);
  }
}
