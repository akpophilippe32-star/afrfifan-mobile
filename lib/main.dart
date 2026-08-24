import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';

import 'theme/app_theme.dart';
import 'screens/users/splash/splash_screen.dart';
import 'screens/users/messages/voice_call_screen.dart'; 
import 'screens/users/messages/incoming_call_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
RealtimeChannel? _callChannel;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final supabase = Supabase.instance.client;

  supabase.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      final currentUserId = session.user.id;
      print("✅ [MAIN DIAGNOSTIC] Utilisateur CONNECTÉ ! ID: $currentUserId");
      print("📡 [MAIN DIAGNOSTIC] Activation de l'écouteur d'appels entrants...");

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
            // ✅ AJOUT DE 'async' ICI pour pouvoir faire une requête à la BDD
            callback: (payload) async {
              print("📩 [MAIN DIAGNOSTIC] 🚨 ÉVÉNEMENT REÇU ! Données brutes : ${payload.newRecord}");
              
              final newCall = payload.newRecord;
              final callerId = newCall['caller_id'];
              final status = newCall['status'];
              
              if (callerId != currentUserId && status == 'ongoing') {
                print("🔔 [MAIN DIAGNOSTIC] SUCCÈS ! Appel entrant détecté de : $callerId");
                
                // ✅ 1. RÉCUPÉRER LE VRAI NOM ET L'AVATAR DE L'APPELANT
                String displayName = "Utilisateur inconnu";
                String? displayAvatar;

                try {
                  // ⚠️ ATTENTION : Remplace 'users' par le vrai nom de ta table si elle s'appelle 'profiles' ou 'creators'
                  final response = await supabase
                      .from('profiles') 
                      .select('full_name, username, avatar_url')
                      .eq('id', callerId)
                      .single();

                  displayName = response['full_name'] ?? response['username'] ?? "Utilisateur";
                  displayAvatar = response['avatar_url'];
                  print("✅ [MAIN DIAGNOSTIC] Infos appelant récupérées : $displayName");
                } catch (e) {
                  print("⚠️ [MAIN DIAGNOSTIC] Erreur récupération nom appelant : $e");
                }

                // ✅ 2. OUVRIR L'ÉCRAN AVEC LES VRAIES INFOS
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => IncomingCallScreen(
                      callId: newCall['id'].toString(),
                      callerId: callerId,
                      callerName: displayName, // ✅ VRAI NOM ICI (plus "Appel entrant...")
                      callerAvatar: displayAvatar, // ✅ VRAI AVATAR ICI
                    ),
                  ),
                );
              } else {
                print("⛔ [MAIN DIAGNOSTIC] Appel ignoré (propre appel ou statut != ongoing)");
              }
            },
          )
          .subscribe((status, error) {
            print("📡 [MAIN DIAGNOSTIC] Statut souscription Realtime : $status");
            if (error != null) print("❌ [MAIN DIAGNOSTIC] Erreur Realtime : $error");
          });
    } 
    
    else if (event == AuthChangeEvent.signedOut) {
      print("🚪 [MAIN DIAGNOSTIC] Utilisateur déconnecté. Désactivation de l'écouteur.");
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

class AfrifanApp extends StatelessWidget {
  const AfrifanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Afrifan',
      debugShowCheckedModeBanner: false,
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