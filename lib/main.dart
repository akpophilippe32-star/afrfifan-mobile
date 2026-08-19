import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/users/splash/splash_screen.dart';
import 'package:flutter/gestures.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const AfrifanApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

class AfrifanApp extends StatelessWidget {
  const AfrifanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Afrifan',
      debugShowCheckedModeBanner: false,
      
      // 🎨 THÈME DE LA SCROLLBAR
      theme: AppTheme.light.copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(true),
          thickness: WidgetStateProperty.all(6.0),
          radius: const Radius.circular(10),
          thumbColor: WidgetStateProperty.all(
            const Color(0xFF6366F1).withOpacity(0.5),
          ),
        ),
      ),

      // 🎛️ CONFIGURATION COMPORTEMENTALE
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
        },
      ),

      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      home: const SplashScreen(),
    );
  }
}