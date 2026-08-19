import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'constants/app_theme.dart';
import 'constants/supabase_config.dart';
import 'utils/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "env");

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

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
