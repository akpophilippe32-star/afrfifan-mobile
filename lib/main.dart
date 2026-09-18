import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/users/splash/splash_screen.dart';
import 'screens/users/messages/voice_call_screen.dart';
import 'screens/users/messages/incoming_call_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
RealtimeChannel? _callChannel;

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final supabase = Supabase.instance.client;

  // ✅ Écouteur global pour les appels entrants ET les changements d'état
  supabase.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      final currentUserId = session.user.id;
      
      _callChannel?.unsubscribe();

      _callChannel = supabase
          .channel('incoming_calls')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'calls',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: currentUserId,
            ),
            callback: (payload) async {
              final newCall = payload.newRecord;
              final callerId = newCall['caller_id'];
              final status = newCall['status'];

              if (callerId != currentUserId && status == 'ongoing') {
                String displayName = "Utilisateur inconnu";
                String? displayAvatar;

                try {
                  final response = await supabase
                      .from('profiles')
                      .select('full_name, username, avatar_url')
                      .eq('id', callerId)
                      .single();

                  displayName = response['full_name'] ?? response['username'] ?? "Utilisateur";
                  displayAvatar = response['avatar_url'];
                } catch (e) {
                  print("⚠️ Erreur récupération nom appelant : $e");
                }

                // Vérifier si on est déjà sur un appel pour éviter les doublons
                if (navigatorKey.currentState?.canPop() == false || 
                    navigatorKey.currentState?.widget is! IncomingCallScreen) {
                  
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (context) => IncomingCallScreen(
                        callId: newCall['id'].toString(),
                        callerId: callerId,
                        callerName: displayName,
                        callerAvatar: displayAvatar,
                      ),
                    ),
                  );
                }
              }
            },
          )
          .subscribe((status, error) {
            if (error != null) print("❌ Erreur Realtime : $error");
          });
    } else if (event == AuthChangeEvent.signedOut) {
      _callChannel?.unsubscribe();
    }
  });

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const AfrifanApp(),
    ),
  );
}

class AfrifanApp extends StatefulWidget {
  const AfrifanApp({super.key});

  @override
  State<AfrifanApp> createState() => _AfrifanAppState();
}

class _AfrifanAppState extends State<AfrifanApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Afrifan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: currentThemeMode,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
          ),
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          home: const SplashScreen(), // ✅ Le SplashScreen va gérer la redirection
        );
      },
    );
  }
}