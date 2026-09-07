import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static bool _isInitialized = false;

  /// Main initialization entry point called when scholar is logged in / inside app
  static Future<void> initializeAndRegister(BuildContext? context) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request Push Notification permissions (Android 13+ & iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[PushNotificationService]: Permission status: ${settings.authorizationStatus}');

      // 2. Fetch current FCM device token with retry logic for Google Play Services connection
      String? token;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          token = await messaging.getToken();
          if (token != null) break;
        } catch (tokErr) {
          debugPrint('[PushNotificationService Token Fetch Attempt $attempt Error]: $tokErr');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 1500 * attempt));
          }
        }
      }

      if (token != null) {
        await registerDeviceToken(fcmToken: token);
      }

      // 3. Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) {
        registerDeviceToken(fcmToken: newToken);
      });

      if (!_isInitialized) {
        _isInitialized = true;

        // 4. Handle Foreground Messages (App is currently open on screen)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[FCM Foreground Message]: ${message.notification?.title} | ${message.notification?.body}');

          final notification = message.notification;
          if (notification != null && context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title ?? 'Notification',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                backgroundColor: const Color(0xFF1A3C2E),
                action: SnackBarAction(
                  label: 'VIEW',
                  textColor: const Color(0xFFC97B2E),
                  onPressed: () {
                    // Action handler when tapped
                  },
                ),
              ),
            );
          }
        });

        // 5. Handle Background Message Tap
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('[FCM App Opened from Background]: ${message.data}');
        });
      }
    } catch (e) {
      debugPrint('[PushNotificationService Init Error]: $e');
    }
  }

  /// Register or update the scholar's device FCM push token in Supabase user_fcm_tokens table
  static Future<void> registerDeviceToken({required String fcmToken, String deviceType = 'android'}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ [FCM DEBUG WARNING]: No authenticated user logged in yet to save token.');
        return;
      }

      debugPrint('🔔 ====================================');
      debugPrint('🔔 [FCM DEBUG] Logged In User ID: ${user.id}');
      debugPrint('🔔 [FCM DEBUG] Device FCM Token: $fcmToken');
      debugPrint('🔔 ====================================');

      final response = await _supabase
          .from('user_fcm_tokens')
          .upsert(
            {
              'user_id': user.id,
              'fcm_token': fcmToken,
              'device_type': deviceType,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'fcm_token',
          )
          .select();

      debugPrint('🔔 [FCM DEBUG SUCCESS]: Saved token to user_fcm_tokens table: $response');
    } catch (e) {
      debugPrint('❌ [FCM DEBUG ERROR]: Failed to register FCM token: $e');
    }
  }

  /// Remove device token on logout
  static Future<void> unregisterDeviceToken({required String fcmToken}) async {
    try {
      await _supabase.from('user_fcm_tokens').delete().eq('fcm_token', fcmToken);
      debugPrint('[PushNotificationService]: Removed FCM token on logout.');
    } catch (e) {
      debugPrint('[PushNotificationService Error]: Failed to unregister token: $e');
    }
  }

  /// Helper to check if scholar has active push notifications registered
  static Future<bool> hasRegisteredDeviceToken() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final data = await _supabase
          .from('user_fcm_tokens')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      return data != null;
    } catch (_) {
      return false;
    }
  }

  /// Send in-app notification & log to notifications table
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('[PushNotificationService]: In-app notification created for user $userId');
    } catch (e) {
      debugPrint('[PushNotificationService Error]: $e');
    }
  }
}
