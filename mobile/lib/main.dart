import 'package:flutter/material.dart';
import 'constants/app_theme.dart';
import 'utils/app_router.dart';

void main() {
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
