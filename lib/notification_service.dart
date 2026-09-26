import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles push notification setup: asking permission, saving the device's
/// FCM token to Firestore (so the daily Python job knows where to send the
/// portfolio update), and showing a snackbar if a notification arrives
/// while the app is open in the foreground.
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// A global navigator key lets us show a snackbar from anywhere,
  /// without needing a BuildContext passed in. Add this same key to
  /// MaterialApp's `navigatorKey:` property in main.dart.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Call this once, early in main(), right after Firebase.initializeApp()
  /// has completed and before runApp(). No BuildContext needed.
  static Future<void> init() async {
    // 1. Ask the user for permission to show notifications.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // User said no - nothing more to do.
      return;
    }

    // 2. Get this device/browser's unique FCM token and save it to
    // Firestore, so the daily Python script knows where to send updates.
    // NOTE: on web this requires the VAPID key - see setup instructions.
    try {
      final token = await _messaging.getToken(
        vapidKey: 'YOUR_VAPID_KEY_HERE', // replace after generating in Firebase console
      );
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('fcmTokens')
            .doc(token)
            .set({
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Could not get/save FCM token: $e');
    }

    // 3. If the token refreshes later (can happen), keep Firestore updated.
    _messaging.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance.collection('fcmTokens').doc(newToken).set({
        'token': newToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // 4. Show a snackbar if a notification arrives while the app is open
    // and focused (foreground). Uses the global navigatorKey's context,
    // so this works no matter which screen is currently showing.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'Portfolio Update';
      final body = message.notification?.body ?? '';
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }
}