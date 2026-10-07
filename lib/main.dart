import 'package:flutter/material.dart';
import 'features/auth/role_based_router.dart';

void main() {
  runApp(const RevoApp());
}

class RevoApp extends StatelessWidget {
  const RevoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Revo — Theatre Production Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const RoleBasedRouter(),
    );
  }
}
