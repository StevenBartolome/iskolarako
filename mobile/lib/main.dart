import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'constants/app_theme.dart';
import 'constants/supabase_config.dart';
import 'utils/app_router.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "env");

  // 1. Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  // 2. Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  // 3. Register device FCM token to user_fcm_tokens table
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await PushNotificationService.registerDeviceToken(fcmToken: fcmToken);
    }
  } catch (e) {
    debugPrint('FCM Token registration note: $e');
  }

  runApp(const IskolarAkoApp());
}

class IskolarAkoApp extends StatelessWidget {
  const IskolarAkoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IskolarAko',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Default theme is forced to White/Light mode
      initialRoute: AppRouter.splash, // Splash screen is now the initial screen
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
