import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/revo_theme.dart';
import 'features/auth/role_based_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely initialize Firebase when available; falls back smoothly to Mock Auth (Issue #8)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('Firebase initialization skipped/deferred. Operating in Mock Auth mode: $e');
  }

  runApp(const RevoApp());
}

class RevoApp extends StatelessWidget {
  const RevoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Revo — Theatre Production Management System',
      debugShowCheckedModeBanner: false,
      theme: RevoTheme.lightTheme,
      home: const RoleBasedRouter(),
    );
  }
}