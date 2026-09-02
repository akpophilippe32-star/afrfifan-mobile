import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? callId;
  final bool isReceiver;

  const VideoCallScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.callId,
    this.isReceiver = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RtcEngine? _engine;
  RealtimeChannel? _syncChannel;
  
  VideoViewController? _localViewController;
  VideoViewController? _remoteViewController;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isJoined = false;
  bool _isOtherUserJoined = false;
  bool _isLeaving = false;

  Timer? _callTimer;
  int _callDuration = 0;

  final String appId = '18d7051c40f14cea8953b23824683c0b';
  final Color primaryColor = const Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    _setupSyncChannel();
    _initAgoraVideo();
  }

  void _setupSyncChannel() {
    final callId = widget.callId;
    if (callId == null) return;

    print("📡 [VideoCallScreen] Création du canal de synchro...");
    final channel = Supabase.instance.client.channel('call_sync_$callId');

    // Écoute des messages broadcast
    channel.onBroadcast(event: 'user_joined', callback: (payload) {
      print("✅ [VideoCallScreen] L'autre utilisateur est connecté (broadcast) !");
      if (mounted && !_isOtherUserJoined) {
        setState(() => _isOtherUserJoined = true);
        _startTimer();
      }
    });

    channel.onBroadcast(event: 'call_ended', callback: (payload) {
      print("📴 [VideoCallScreen] L'autre utilisateur a raccroché !");
      _callTimer?.cancel();
      if (mounted && !_isLeaving) {
        _isLeaving = true;
        Navigator.of(context).pop();
      }
    });

    // ✅ Écouter les changements de statut de l'appel dans la BDD via PostgresChanges
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'calls',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: callId,
      ),
      callback: (payload) {
        final newStatus = payload.newRecord?['status'];
        print("📡 [VideoCallScreen] Statut appel mis à jour : $newStatus");
        if (newStatus == 'connected' && !_isOtherUserJoined) {
          print("✅ [VideoCallScreen] L'autre personne a décroché !");
          if (mounted) {
            setState(() => _isOtherUserJoined = true);
            _startTimer();
          }
        } else if (newStatus == 'cancelled' || newStatus == 'ended' || newStatus == 'rejected') {
          print("📴 [VideoCallScreen] L'appel a été terminé par l'autre");
          if (mounted && !_isLeaving) {
            _isLeaving = true;
            Navigator.of(context).pop();
          }
        }
      },
    );

    // Écouter les suppressions
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'calls',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: callId,
      ),
      callback: (payload) {
        print("📴 [VideoCallScreen] L'appel a été supprimé de la BDD");
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
          await channel.sendBroadcastMessage(event: 'user_joined', payload: {'user': 'receiver'});
        } catch (e) { print("⚠️ Erreur envoi signal: $e"); }
      });
    }
  }

  Future<void> _initAgoraVideo() async {
    print("🎥 [VideoCallScreen] Initialisation de la vidéo...");
    
    // ✅ DEMANDER LES PERMISSIONS
    final permissions = await [Permission.microphone, Permission.camera].request();
    if (permissions[Permission.camera] != PermissionStatus.granted ||
        permissions[Permission.microphone] != PermissionStatus.granted) {
      print("❌ [VideoCallScreen] Permissions caméra ou micro refusées !");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez autoriser la caméra et le micro dans les paramètres")),
        );
      }
      return;
    }
    
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
    
    await _engine!.enableAudio();
    await _engine!.enableVideo();
    await _engine!.setEnableSpeakerphone(true);

    // ✅ CONFIGURER LA VIDÉO LOCALE
    _localViewController = VideoViewController(
      rtcEngine: _engine!,
      canvas: const VideoCanvas(uid: 0),
    );

    await _engine!.startPreview();
    if (mounted) setState(() {});

    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("🎉 [VideoCallScreen] L'autre a rejoint ! UID: $remoteUid");
          if (mounted) {
            setState(() => _isOtherUserJoined = true);
            _remoteViewController = VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(uid: remoteUid),
              connection: connection,
            );
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          if (mounted) setState(() => _isOtherUserJoined = false);
        },
      ),
    );

    final currentChannelId = widget.callId ?? 'default_channel';
    String token = "";
    try {
      final appCertificate = 'ea5e4a39245d4849bfd84a99d5100632';
      token = RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: appCertificate,
        channelName: currentChannelId,
        uid: 0,
        tokenExpireSeconds: 3600,
      );
      print("✅ [VideoCallScreen] Token généré avec succès !");
    } catch (e) { print("❌ Erreur token: $e"); }

    await _engine!.joinChannel(
      token: token,
      channelId: currentChannelId,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
    
    if (mounted) setState(() => _isJoined = true);
  }

  Future<void> _leaveChannel() async {
    if (_isLeaving) return; 
    _isLeaving = true;

    print("📞 [VideoCallScreen] Raccrochage...");
    _callTimer?.cancel();

    final callDurationFormatted = '${(_callDuration ~/ 60).toString().padLeft(2, '0')}:${(_callDuration % 60).toString().padLeft(2, '0')}';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId != null) {
      Supabase.instance.client.from('messages').insert({
        'sender_id': currentUserId,
        'receiver_id': widget.otherUserId,
        'type': 'video_call',
        'content': '🎥 Appel vidéo terminé • $callDurationFormatted',
        'created_at': DateTime.now().toIso8601String(),
      }).catchError((e) => print("⚠️ Erreur trace appel: $e"));
    }

    final channel = _syncChannel;
    if (channel != null) {
      channel.sendBroadcastMessage(event: 'call_ended', payload: {'user': 'receiver'}).catchError((e) {});
      channel.unsubscribe().catchError((e) {});
    }

    final engineToCleanup = _engine;
    _engine = null;
    if (engineToCleanup != null) {
      engineToCleanup.leaveChannel().catchError((e) {});
      engineToCleanup.release().catchError((e) {});
    }

    if (mounted) Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // VIDÉO DISTANTE (plein écran)
          if (_isOtherUserJoined && _remoteViewController != null)
            Positioned.fill(
              child: AgoraVideoView(controller: _remoteViewController!),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: widget.otherUserAvatar != null 
                        ? NetworkImage(widget.otherUserAvatar!) 
                        : null,
                    child: widget.otherUserAvatar == null 
                        ? const Icon(Icons.person, color: Colors.white, size: 60) 
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isOtherUserJoined ? _formatDuration(_callDuration) : 'Appel en cours...',
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                ],
              ),
            ),

          // MA VIDÉO LOCALE (petit rectangle en haut à droite)
          if (_localViewController != null)
            Positioned(
              top: 60,
              right: 20,
              child: Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AgoraVideoView(controller: _localViewController!),
                ),
              ),
            ),

          // BOUTONS DE CONTRÔLE (en bas)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  onTap: () {
                    setState(() => _isMuted = !_isMuted);
                    _engine?.muteLocalAudioStream(_isMuted);
                  },
                ),
                const SizedBox(width: 24),
                _buildControlButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  onTap: () {
                    setState(() => _isCameraOff = !_isCameraOff);
                    _engine?.enableLocalVideo(!_isCameraOff);
                  },
                ),
                const SizedBox(width: 24),
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
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1F),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}