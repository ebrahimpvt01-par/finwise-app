import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Saves this device's FCM token under the logged-in user:
///   users/{uid}/fcmTokens/{token}
///
/// One document per device, so a user with two phones gets reminders on both,
/// and each token is tied to a user id.
class FcmTokenService {
  static StreamSubscription<String>? _refreshSub;

  static CollectionReference<Map<String, dynamic>> _tokens(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcmTokens');
  }

  /// Call after a successful login, and on app start if a user is already
  /// signed in.
  static Future<void> register() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Needed on Android 13+ so notifications can be shown.
      await messaging.requestPermission();

      final token = await messaging.getToken();

      if (token != null) {
        await _tokens(user.uid).doc(token).set({
          'token': token,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // FCM can rotate the token; keep Firestore in sync.
      await _refreshSub?.cancel();

      _refreshSub = messaging.onTokenRefresh.listen((newToken) async {
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser == null) {
          return;
        }

        await _tokens(currentUser.uid).doc(newToken).set({
          'token': newToken,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      // Never let a notification problem break login.
    }
  }

  /// Call BEFORE FirebaseAuth.instance.signOut(), so the next person who
  /// logs in on this phone does not inherit the previous user's reminders.
  static Future<void> unregister() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await FirebaseMessaging.instance.getToken();

      if (user != null && token != null) {
        await _tokens(user.uid).doc(token).delete();
      }

      await _refreshSub?.cancel();
      _refreshSub = null;
    } catch (_) {
      // Ignore: logout must always succeed.
    }
  }
}