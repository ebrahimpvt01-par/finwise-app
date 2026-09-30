import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'main_navigation_screen.dart';
import 'app_theme.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinWise Test',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,

      // Allows NotificationService to show foreground SnackBars.
      navigatorKey: NotificationService.navigatorKey,

      // Automatically decides whether to show LoginPage
      // or the main app based on Firebase Authentication.
      home: const AuthGate(),
    );
  }
}

/// Checks whether a Firebase user is already signed in.
///
/// Firebase Authentication persists the login session on the device.
/// If a user is already signed in, they go directly to the app.
/// Otherwise, they see the LoginPage.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Firebase is still checking the authentication state.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is already logged in.
        if (snapshot.hasData) {
          return const MainNavigationScreen();
        }

        // No user is logged in.
        return const LoginPage();
      },
    );
  }
}

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Test'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('test').add({
              'message': 'Hello from Flutter',
              'timestamp': DateTime.now(),
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sent to Firestore!'),
              ),
            );
          },
          child: const Text('Send Test Data'),
        ),
      ),
    );
  }
}