import 'package:flutter/material.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/applications/application_form_screen.dart';
import '../screens/applications/application_tracker_screen.dart';
import '../screens/applications/document_upload_screen.dart';
import '../screens/scholarships/scholarship_detail_screen.dart';
import '../screens/funds/fund_tracking_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/notifications/notification_detail_screen.dart';
import '../widgets/main_layout.dart';

import '../screens/profile/profile_edit_screen.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String applicationForm = '/application_form';

  static const String scholarshipDetail = '/scholarship_detail';
  static const String applicationTracker = '/application_tracker';
  static const String documentUpload = '/document_upload';
  static const String notifications = '/notifications';
  static const String notificationDetail = '/notification_detail';
  static const String fundTracking = '/fund_tracking';
  static const String profileEdit = '/profile_edit';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen(), settings: settings);
      case applicationForm:
        return MaterialPageRoute(
            builder: (_) => const ApplicationFormScreen(), settings: settings);
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen(), settings: settings);
      case home:
        return MaterialPageRoute(builder: (_) => const MainLayout(), settings: settings);
      case scholarshipDetail:
        return MaterialPageRoute(
            builder: (_) => const ScholarshipDetailScreen(), settings: settings);
      case applicationTracker:
        return MaterialPageRoute(
            builder: (_) => const ApplicationTrackerScreen(), settings: settings);
      case documentUpload:
        return MaterialPageRoute(
            builder: (_) => const DocumentUploadScreen(), settings: settings);
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationScreen(), settings: settings);
      case notificationDetail:
        return MaterialPageRoute(
          builder: (_) => const NotificationDetailScreen(),
          settings: settings,
        );
      case fundTracking:
        return MaterialPageRoute(builder: (_) => const FundTrackingScreen(), settings: settings);
      case profileEdit:
        return MaterialPageRoute(builder: (_) => const ProfileEditScreen(), settings: settings);
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
