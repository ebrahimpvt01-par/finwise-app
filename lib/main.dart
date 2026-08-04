import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinWise Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('Firestore Test')),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('test').add({
                'message': 'Hello from Flutter',
                'timestamp': DateTime.now(),
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sent to Firestore!')),
              );
            },
            child: const Text('Send Test Data'),
          ),
        ),
      ),
    );
  }
}