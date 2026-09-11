import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

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
  bool _isProcessing = false;
  String? _liveId;
  final String appId = '18d7051c40f14cea8953b23824683c0b';

  @override
  void initState() {
    super.initState();
    _initAgoraForLive();
  }

  Future<void> _initAgoraForLive() async {
    final permissions = await [Permission.microphone, Permission.camera].request();
    if (permissions[Permission.camera] != PermissionStatus.granted ||
        permissions[Permission.microphone] != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Permissions caméra et micro requises pour le live !")),
        );
        Navigator.pop(context);
      }
      return;
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));

    await _engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    await _engine!.enableVideo();
    await _engine!.startPreview();

    _localViewController = VideoViewController(
      rtcEngine: _engine!,
      canvas: const VideoCanvas(uid: 0),
    );

    if (mounted) setState(() {});
  }

  Future<void> _startLive() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mets un titre à ton Live !")),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final liveId = const Uuid().v4();
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;

      await Supabase.instance.client.from('live_streams').insert({
        'id': liveId,
        'creator_id': currentUserId,
        'title': _titleController.text.trim(),
        'status': 'live',
        'viewer_count': 0,
        'started_at': DateTime.now().toIso8601String(),
      });

      String token = "";
      final appCertificate = 'ea5e4a39245d4849bfd84a99d5100632';
      token = RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: appCertificate,
        channelName: liveId,
        uid: 0,
        tokenExpireSeconds: 3600,
      );

      await _engine!.joinChannel(
        token: token,
        channelId: liveId,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      if (mounted) {
        setState(() {
          _isLive = true;
          _liveId = liveId;
          _isProcessing = false;
        });
      }
      print("🔴 LIVE DÉMARRÉ ! ID: $liveId");

    } catch (e) {
      print("❌ Erreur démarrage live: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _endLive() async {
    if (_liveId != null) {
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    // ⚠️ Le live vidéo reste sur fond noir (préview caméra plein écran)
    // ✅ Le bouton neutre devient noir en clair / blanc en sombre
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return PopScope(
      canPop: !_isLive,
      onPopInvoked: (didPop) async {
        if (!didPop && _isLive) {
          await _endLive();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ─── CAMÉRA PLEIN ÉCRAN ───
            if (_localViewController != null)
              Positioned.fill(child: AgoraVideoView(controller: _localViewController!)),

            // ─── CHAMP TITRE ───
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─── BOUTON DÉMARRER / ARRÊTER ───
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _isProcessing ? null : (_isLive ? _endLive : _startLive),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    decoration: BoxDecoration(
                      // ✅ Arrêter : rouge (convention live)
                      // ✅ Démarrer : noir en clair / blanc en sombre
                      color: _isLive ? Colors.red : accentColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10),
                      ],
                    ),
                    child: _isProcessing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              // ✅ Loader adaptatif sur fond accent
                              color: _isLive ? Colors.white : accentTextColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLive ? "🔴 ARRÊTER LE LIVE" : "🚀 DÉMARRER LE LIVE",
                            style: TextStyle(
                              // ✅ Texte adaptatif selon fond
                              color: _isLive ? Colors.white : accentTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
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