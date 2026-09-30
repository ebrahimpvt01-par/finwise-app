import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Tags this device's FCM token with the logged-in user's id.
///
/// Uses the SAME collection as NotificationService: fcmTokens/{token}.
/// NotificationService.init() saves the bare token at app start (no user
/// yet). After login/signup, register() adds `userId` to that document, so
/// server jobs can find a user's devices with:
///   fcmTokens where userId == <uid>
class FcmTokenService {
  static final CollectionReference<Map<String, dynamic>> _tokens =
      FirebaseFirestore.instance.collection('fcmTokens');

  static bool _listening = false;

  /// Call right after a successful login or signup.
  static Future<void> register() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await _tokens.doc(token).set(
          {
            'token': token,
            'userId': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // If FCM rotates the token, tag the new one too.
      if (!_listening) {
        _listening = true;

        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          final current = FirebaseAuth.instance.currentUser;

          if (current == null) {
            return;
          }

          await _tokens.doc(newToken).set(
            {
              'token': newToken,
              'userId': current.uid,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        });
      }
    } catch (_) {
      // Never let a notification problem break login.
    }
  }

  /// Call BEFORE FirebaseAuth.instance.signOut(). Removes this device's
  /// token so a logged-out phone stops receiving the previous user's alerts.
  static Future<void> unregister() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await _tokens.doc(token).delete();
      }
    } catch (_) {
      // Logout must always succeed.
    }
  }
}