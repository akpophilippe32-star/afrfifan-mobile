import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agora_token_generator/agora_token_generator.dart';

class WatchLiveScreen extends StatefulWidget {
  final String liveId;
  final String creatorName;
  final String? creatorAvatar;
  final bool isSubscribed; // Pour savoir si le fan a le droit de chatter

  const WatchLiveScreen({
    super.key,
    required this.liveId,
    required this.creatorName,
    this.creatorAvatar,
    required this.isSubscribed,
  });

  @override
  State<WatchLiveScreen> createState() => _WatchLiveScreenState();
}

class _WatchLiveScreenState extends State<WatchLiveScreen> {
  RtcEngine? _engine;
  VideoViewController? _remoteViewController;
  
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _chatSubscription;
  
  final String appId = '18d7051c40f14cea8953b23824683c0b';
  int _viewerCount = 0;

  @override
  void initState() {
    super.initState();
    _initAgoraAsAudience();
    _setupLiveChat();
    _updateViewerCount();
  }

  // ✅ 1. CONFIGURATION AGORA EN MODE SPECTATEUR (AUDIENCE)
  Future<void> _initAgoraAsAudience() async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
    
    // 🔥 MODE LIVE : On est spectateur, on ne diffuse pas
    await _engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine!.enableAudio(); // On active l'audio pour entendre le créateur

    // Écouter quand le créateur (Broadcaster) envoie sa vidéo
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (mounted) {
            setState(() {
              _remoteViewController = VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: remoteUid),
                connection: connection,
              );
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          if (mounted) setState(() => _remoteViewController = null);
        },
      ),
    );

    // Rejoindre le canal avec un token
    String token = "";
    try {
      final appCertificate = 'ea5e4a39245d4849bfd84a99d5100632';
      token = RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: appCertificate,
        channelName: widget.liveId,
        uid: 0,
        tokenExpireSeconds: 3600,
      );
    } catch (e) { print("Erreur token spectateur: $e"); }

    await _engine!.joinChannel(
      token: token,
      channelId: widget.liveId,
      uid: 0,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleAudience,
      ),
    );
  }

  // ✅ 2. GESTION DU CHAT EN DIRECT (SUPABASE REALTIME)
  void _setupLiveChat() {
    // Écouter les nouveaux messages en temps réel
    _chatSubscription = Supabase.instance.client
        .from('live_messages')
        .stream(primaryKey: ['id'])
        .eq('live_stream_id', widget.liveId)
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
        });
        // Scroll automatique vers le bas
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  // ✅ 3. ENVOYER UN MESSAGE (Si abonné)
  Future<void> _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Vérification côté client (la vraie sécurité doit être côté base de données plus tard)
    if (!widget.isSubscribed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Abonne-toi pour participer au chat !")),
      );
      return;
    }

    await Supabase.instance.client.from('live_messages').insert({
      'live_stream_id': widget.liveId,
      'user_id': currentUserId,
      'content': _chatController.text.trim(),
    });

    _chatController.clear();
  }

  // Mettre à jour le compteur de vues (simple incrémentation pour le MVP)
  Future<void> _updateViewerCount() async {
    // On pourrait faire un RPC Supabase ici, pour le MVP on simule ou on lit la table
    final response = await Supabase.instance.client
        .from('live_streams')
        .select('viewer_count')
        .eq('id', widget.liveId)
        .single();
    
    if (mounted) setState(() => _viewerCount = response['viewer_count'] ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. VIDÉO DU CRÉATEUR (PLEIN ÉCRAN)
          if (_remoteViewController != null)
            Positioned.fill(child: AgoraVideoView(controller: _remoteViewController!))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 2. OVERLAY SUPÉRIEUR (Infos Live)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: const Row(children: [
                        Icon(Icons.circle, color: Colors.white, size: 10),
                        SizedBox(width: 5),
                        Text("LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.visibility, color: Colors.white.withOpacity(0.8), size: 16),
                    const SizedBox(width: 4),
                    Text("$_viewerCount", style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 3. OVERLAY INFÉRIEUR (Chat et Input)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Liste des messages
                  Container(
                    height: 200,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "${msg['user_name'] ?? 'Fan'} : ",
                                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(
                                        text: msg['content'],
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Zone de saisie
                  if (widget.isSubscribed)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Dis quelque chose...",
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                            child: const Icon(Icons.send, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        // Action pour s'abonner
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Ouvre l'abonnement pour chatter !")),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text("💎 Abonne-toi pour participer au chat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}