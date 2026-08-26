import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart'; // Assure-toi d'avoir 'uuid' dans pubspec.yaml, sinon utilise DateTime.now().toString()

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  RtcEngine? _engine;
  VideoViewController? _localViewController;
  final TextEditingController _titleController = TextEditingController();
  
  bool _isLive = false;
  String? _liveId;
  final String appId = '18d7051c40f14cea8953b23824683c0b'; // Ton App ID

  @override
  void initState() {
    super.initState();
    _initAgoraForLive();
  }

  Future<void> _initAgoraForLive() async {
    // 1. Permissions
    await [Permission.microphone, Permission.camera].request();

    // 2. Initialisation Agora
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
    
    // 🔥 CONFIGURATION SPÉCIALE POUR LES LIVES (Différent des appels)
    await _engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster); // Le créateur est le "Broadcaster"
    
    await _engine!.enableVideo();
    await _engine!.startPreview();

    // 3. Contrôleur vidéo local
    _localViewController = VideoViewController(
      rtcEngine: _engine!,
      canvas: const VideoCanvas(uid: 0),
    );

    if (mounted) setState(() {});
  }

  Future<void> _startLive() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mets un titre à ton Live !")));
      return;
    }

    setState(() => _isLive = true);

    final liveId = const Uuid().v4(); // ID unique pour ce live
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    // 1. Enregistrer le Live dans Supabase
    await Supabase.instance.client.from('live_streams').insert({
      'id': liveId,
      'creator_id': currentUserId,
      'title': _titleController.text,
      'status': 'live',
      'viewer_count': 0,
      'started_at': DateTime.now().toIso8601String(),
    });

    // 2. Rejoindre le canal Agora
    // (Ici on génère un token simple, à améliorer avec Edge Function plus tard si besoin)
    // Pour le test, on utilise un token vide ou généré localement si ton projet l'autorise
    String token = ""; 
    try {
       final appCertificate = 'ea5e4a39245d4849bfd84a99d5100632';
       token = RtcTokenBuilder.buildTokenWithUid(
         appId: appId,
         appCertificate: appCertificate,
         channelName: liveId,
         uid: 0,
         tokenExpireSeconds: 3600,
       );
    } catch (e) { print("Erreur token: $e"); }

    await _engine!.joinChannel(
      token: token,
      channelId: liveId,
      uid: 0,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    setState(() => _liveId = liveId);
    print("🔴 LIVE DÉMARRÉ ! ID: $liveId");
  }

  Future<void> _endLive() async {
    if (_liveId != null) {
      // Mettre à jour le statut dans Supabase
      await Supabase.instance.client.from('live_streams').update({
        'status': 'ended',
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', _liveId!);
    }

    await _engine?.leaveChannel();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Caméra du créateur (Plein écran)
          if (_localViewController != null)
            Positioned.fill(child: AgoraVideoView(controller: _localViewController!)),
          
          // Interface par-dessus la caméra
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (!_isLive)
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Titre de ton Live (ex: Soirée dédicace 🇧🇯)",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
              ],
            ),
          ),

          // Bouton d'action (Démarrer ou Arrêter)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isLive ? _endLive : _startLive,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  decoration: BoxDecoration(
                    color: _isLive ? Colors.red : const Color(0xFF6366F1), // Rouge si live, Violet si prêt
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                  ),
                  child: Text(
                    _isLive ? "🔴 ARRÊTER LE LIVE" : "🚀 DÉMARRER LE LIVE",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _engine?.release();
    _titleController.dispose();
    super.dispose();
  }
}