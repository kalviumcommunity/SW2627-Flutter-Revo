import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const RevoApp());
}

class RevoApp extends StatelessWidget {
  const RevoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Revo',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Revo Theatre'),
        ),
        body: const Center(
          child: Text('Firebase Connected Successfully'),
        ),
      ),
    );
  }
}