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
import '../widgets/main_layout.dart';

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
  static const String fundTracking = '/fund_tracking';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case applicationForm:
        return MaterialPageRoute(
            builder: (_) => const ApplicationFormScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const MainLayout());
      case scholarshipDetail:
        return MaterialPageRoute(
            builder: (_) => const ScholarshipDetailScreen());
      case applicationTracker:
        return MaterialPageRoute(
            builder: (_) => const ApplicationTrackerScreen());
      case documentUpload:
        return MaterialPageRoute(
            builder: (_) => const DocumentUploadScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationScreen());
      case fundTracking:
        return MaterialPageRoute(builder: (_) => const FundTrackingScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
