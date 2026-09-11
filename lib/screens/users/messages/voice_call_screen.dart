import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT

class VoiceCallScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? callId;
  final bool isReceiver;

  const VoiceCallScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.callId,
    this.isReceiver = false,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  RtcEngine? _engine;
  RealtimeChannel? _syncChannel;

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isJoined = false;
  bool _isOtherUserJoined = false;
  bool _isLeaving = false;

  Timer? _callTimer;
  int _callDuration = 0;

  final String appId = '18d7051c40f14cea8953b23824683c0b';

  @override
  void initState() {
    super.initState();
    print("📞 [VoiceCallScreen] L'écran d'appel s'est ouvert !");

    if (widget.isReceiver) {
      _isOtherUserJoined = true;
      _startTimer();
    }

    _setupSyncChannel();
    _initAgora();
  }

  void _setupSyncChannel() {
    final callId = widget.callId;
    if (callId == null) return;

    print("📡 [VoiceCallScreen] Création du canal de synchro...");

    final channel = Supabase.instance.client.channel('call_sync_$callId');

    channel.onBroadcast(
      event: 'user_joined',
      callback: (payload) {
        print("✅ [VoiceCallScreen] L'autre utilisateur est connecté !");
        if (mounted && !_isOtherUserJoined) {
          setState(() => _isOtherUserJoined = true);
          _startTimer();
        }
      },
    );

    channel.onBroadcast(
      event: 'call_ended',
      callback: (payload) {
        print("📴 [VoiceCallScreen] L'autre utilisateur a raccroché !");
        _callTimer?.cancel();
        if (mounted && !_isLeaving) {
          _isLeaving = true;
          Navigator.of(context).pop();
        }
      },
    );

    channel.subscribe();
    _syncChannel = channel;

    if (widget.isReceiver) {
      Future.delayed(const Duration(seconds: 1), () async {
        if (!mounted) return;
        try {
          await channel.sendBroadcastMessage(
            event: 'user_joined',
            payload: {'user': 'receiver'},
          );
          print("📤 [VoiceCallScreen] Signal 'user_joined' envoyé !");
        } catch (e) {
          print("⚠️ [VoiceCallScreen] Envoi 'user_joined' échoué : $e");
        }
      });
    }
  }

  Future<void> _initAgora() async {
    print("🎙️ [VoiceCallScreen] Début de l'initialisation d'Agora...");

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));

    await _engine!.enableAudio();
    await _engine!.enableLocalAudio(true);
    await _engine!.setEnableSpeakerphone(true);
    await _engine!.muteLocalAudioStream(false);

    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onError: (ErrorCodeType error, String msg) {
          print("❌ [AGORA ERREUR] Code: $error | Message: $msg");
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("🎉 [VoiceCallScreen] Agora : l'autre a rejoint ! UID: $remoteUid");
          if (mounted && !_isOtherUserJoined) {
            setState(() => _isOtherUserJoined = true);
            _startTimer();
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print("👋 [VoiceCallScreen] Agora : l'autre a quitté ! UID: $remoteUid");
          if (mounted) {
            setState(() => _isOtherUserJoined = false);
          }
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("✅ [VoiceCallScreen] Agora : rejoint avec succès ! UID: ${connection.localUid}");
        },
      ),
    );

    final currentChannelId = widget.callId ?? 'default_channel';
    print("📡 [VoiceCallScreen] Connexion à la salle : $currentChannelId");

    String token = "";
    try {
      print("🔄 [VoiceCallScreen] Génération du token Agora en local...");

      final appCertificate = 'ea5e4a39245d4849bfd84a99d5100632';

      token = RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: appCertificate,
        channelName: currentChannelId,
        uid: 0,
        tokenExpireSeconds: 3600,
      );

      print("✅ [VoiceCallScreen] Token généré en local avec succès !");
    } catch (e) {
      print("❌ [VoiceCallScreen] Erreur génération token local: $e");
    }

    await _engine!.joinChannel(
      token: token,
      channelId: currentChannelId,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    if (mounted) {
      setState(() {
        _isJoined = true;
        _isSpeakerOn = true;
        _isMuted = false;
      });
    }
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    await _engine?.setEnableSpeakerphone(_isSpeakerOn);
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine?.muteLocalAudioStream(_isMuted);
  }

  Future<void> _leaveChannel() async {
    if (_isLeaving) return;
    _isLeaving = true;

    print("📞 [VoiceCallScreen] Raccrochage...");
    _callTimer?.cancel();

    final callDurationFormatted = '${(_callDuration ~/ 60).toString().padLeft(2, '0')}:${(_callDuration % 60).toString().padLeft(2, '0')}';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId != null) {
      Supabase.instance.client.from('messages').insert({
        'sender_id': currentUserId,
        'receiver_id': widget.otherUserId,
        'type': 'call_log',
        'content': 'Appel vocal terminé • $callDurationFormatted',
        'created_at': DateTime.now().toIso8601String(),
      }).catchError((e) => print("⚠️ Erreur trace appel: $e"));
    }

    final channel = _syncChannel;
    if (channel != null) {
      channel.sendBroadcastMessage(
        event: 'call_ended',
        payload: {'user': widget.isReceiver ? 'receiver' : 'caller'},
      ).catchError((e) => print("⚠️ Erreur envoi signal: $e"));

      channel.unsubscribe().catchError((e) => print("⚠️ Erreur unsubscribe: $e"));
    }

    final engineToCleanup = _engine;
    _engine = null;

    if (engineToCleanup != null) {
      engineToCleanup.leaveChannel().catchError((e) => print("⚠️ Erreur leaveChannel: $e"));
      engineToCleanup.release().catchError((e) => print("⚠️ Erreur release: $e"));
    }

    if (mounted) {
      print("🔙 [VoiceCallScreen] Fermeture de l'écran...");
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    print("🗑️ [VoiceCallScreen] Nettoyage automatique (dispose)...");
    _callTimer?.cancel();

    final channel = _syncChannel;
    if (channel != null) {
      try { channel.unsubscribe(); } catch (e) {}
    }

    final engine = _engine;
    if (engine != null) {
      try {
        engine.leaveChannel();
        engine.release();
      } catch (e) {}
    }
    super.dispose();
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
    double size = 64,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
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
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;

    final avatarBg = isDark ? const Color(0xFF1C1C1F) : const Color(0xFFE5E7EB);
    final controlBg = isDark ? const Color(0xFF1C1C1F) : Colors.white;
    final controlBorder = isDark ? Colors.white24 : Colors.black12;
    final controlIcon = isDark ? Colors.white : Colors.black;
    final statusBorder = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: subTextColor),
                    onPressed: _leaveChannel,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: avatarBg,
                        backgroundImage: widget.otherUserAvatar != null
                            ? NetworkImage(widget.otherUserAvatar!)
                            : null,
                        child: widget.otherUserAvatar == null
                            ? Icon(Icons.person, color: textColor, size: 60)
                            : null,
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _isOtherUserJoined ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                          border: Border.all(color: statusBorder, width: 3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.otherUserName,
                    style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOtherUserJoined ? _formatDuration(_callDuration) : 'En attente de réponse...',
                    style: TextStyle(
                      color: _isOtherUserJoined ? accentColor : subTextColor,
                      fontSize: 20,
                      fontWeight: _isOtherUserJoined ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 60.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    iconColor: _isMuted ? Colors.red : controlIcon,
                    bgColor: controlBg,
                    borderColor: controlBorder,
                    onTap: _toggleMute,
                  ),
                  const SizedBox(width: 24),
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    iconColor: controlIcon,
                    bgColor: controlBg,
                    borderColor: controlBorder,
                    onTap: _toggleSpeaker,
                  ),
                  const SizedBox(width: 24),
                  // 🔴 Bouton raccrocher reste ROUGE (standard universel)
                  GestureDetector(
                    onTap: _leaveChannel,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}