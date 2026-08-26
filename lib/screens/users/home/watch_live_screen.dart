import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agora_token_generator/agora_token_generator.dart';

class WatchLiveScreen extends StatefulWidget {
  final String liveId;
  final String creatorName;
  final String? creatorAvatar;
  final bool isSubscribed;

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

  // ✅ NOUVEAU : Infos de l'utilisateur connecté
  String _currentUserName = 'Fan';
  String? _currentUserAvatar;

  @override
  void initState() {
    super.initState();
    debugPrint("📺 [WATCH] Ouverture du live avec ID: '${widget.liveId}'");
    _loadCurrentUser(); // ✅ Chargement du vrai nom et avatar
    _initAgoraAsAudience();
    _setupLiveChat();
    _updateViewerCount();
  }

  // ✅ Charger le vrai nom et avatar de l'utilisateur connecté
    Future<void> _loadCurrentUser() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      debugPrint("🔍 [PROFIL] User ID: $userId");
      
      if (userId == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username, full_name, avatar_url')
          .eq('id', userId)
          .limit(1);

      debugPrint("🔍 [PROFIL] Résultat: ${profile.toString()}");

      if (profile.isNotEmpty) {
        final p = profile[0];
        if (mounted) {
          setState(() {
            _currentUserName = p['full_name'] ?? p['username'] ?? 'Fan';
            _currentUserAvatar = p['avatar_url'];
          });
          debugPrint("✅ [PROFIL] Nom chargé: $_currentUserName");
        }
      } else {
        debugPrint("❌ [PROFIL] Aucun profil trouvé pour cet utilisateur !");
      }
    } catch (e) {
      debugPrint(" Erreur chargement profil: $e");
    }
  }

  // ✅ 1. CONFIGURATION AGORA EN MODE SPECTATEUR (AUDIENCE)
  Future<void> _initAgoraAsAudience() async {
    debugPrint("🎥 [WATCH] Initialisation Agora pour le spectateur...");
    
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));
      debugPrint("✅ [WATCH] Moteur initialisé");
      
      await _engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine!.enableAudio();

      _engine?.registerEventHandler(
        RtcEngineEventHandler(
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("🎉 [WATCH] CRÉATEUR DÉTECTÉ ! UID: $remoteUid après ${elapsed}ms");
            if (mounted) {
              setState(() {
                _remoteViewController = VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: remoteUid),
                  connection: connection,
                );
              });
              debugPrint("✅ [WATCH] Contrôleur vidéo distant créé !");
            }
          },
          onFirstRemoteVideoFrame: (RtcConnection connection, int remoteUid, int width, int height, int elapsed) {
            debugPrint("📺 [WATCH] PREMIÈRE IMAGE REÇUE ! Remote UID: $remoteUid, Taille: ${width}x${height}");
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("👋 [WATCH] Le créateur a quitté le live ! UID: $remoteUid");
            if (mounted) setState(() => _remoteViewController = null);
          },
        ),
      );

      String token = "";
      try {
        final appCertificate = 'ea5e4a39245d4849bfd84a99d5100632';
        token = RtcTokenBuilder.buildTokenWithUid(
          appId: appId,
          appCertificate: appCertificate,
          channelName: widget.liveId.trim(),
          uid: 0,
          tokenExpireSeconds: 3600,
        );
        debugPrint("✅ [WATCH] Token spectateur généré pour le canal: '${widget.liveId.trim()}'");
      } catch (e) { 
        debugPrint("❌ [WATCH] Erreur token spectateur: $e"); 
      }

      await _engine!.joinChannel(
        token: token,
        channelId: widget.liveId.trim(),
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );
      
      await _engine!.muteAllRemoteVideoStreams(false);
      debugPrint("✅ [WATCH] Rejoint le canal et flux vidéo débloqués !");

    } catch (e) {
      debugPrint("❌ [WATCH] ERREUR FATALE AGORA: $e");
    }
  }

  // ✅ 2. GESTION DU CHAT EN DIRECT (SUPABASE REALTIME)
  void _setupLiveChat() {
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

  // ✅ 3. ENVOYER UN MESSAGE (Avec le VRAI nom et avatar)
  Future<void> _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    if (!widget.isSubscribed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Abonne-toi pour participer au chat !")),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('live_messages').insert({
        'live_stream_id': widget.liveId,
        'user_id': currentUserId,
        'user_name': _currentUserName,      // ✅ VRAI NOM
        'user_avatar': _currentUserAvatar,  // ✅ VRAI AVATAR
        'content': _chatController.text.trim(),
      });
      _chatController.clear();
    } catch (e) {
      debugPrint("❌ Erreur envoi message: $e");
    }
  }

  // ✅ 4. METTRE À JOUR LE COMPTEUR (Sécurisé)
  Future<void> _updateViewerCount() async {
    try {
      final response = await Supabase.instance.client
          .from('live_streams')
          .select('viewer_count')
          .eq('id', widget.liveId)
          .limit(1);
      
      if (mounted && response.isNotEmpty) {
        setState(() => _viewerCount = response[0]['viewer_count'] ?? 0);
      }
    } catch (e) {
      debugPrint("❌ Erreur compteur: $e");
    }
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
            // ✅ FALLBACK : Affiche un message au lieu du loader infini (utile pour test Chrome)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.creatorAvatar != null)
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(widget.creatorAvatar!),
                    )
                  else
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6366F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 60),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    widget.creatorName,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'En direct 🔴',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 2),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 32),
                        SizedBox(height: 8),
                        Text(
                          '📱 Test sur mobile requis',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'La vidéo ne fonctionne pas sur Chrome.\nOuvre l\'appli sur ton téléphone Android.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),

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
                      decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(4))),
                      child: const Row(children: [
                        Icon(Icons.circle, color: Colors.white, size: 10),
                        SizedBox(width: 5),
                        Text("LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.visibility, color: Colors.white70, size: 16),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 200,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final msgUserName = msg['user_name'] ?? 'Fan';
                        final msgUserAvatar = msg['user_avatar'];
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (msgUserAvatar != null)
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: NetworkImage(msgUserAvatar),
                                )
                              else
                                const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(0xFF6366F1),
                                  child: Icon(Icons.person, size: 14, color: Colors.white),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "$msgUserName : ",
                                        style: const TextStyle(
                                          color: Colors.white70, 
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: msg['content'] ?? '',
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Ouvre l'abonnement pour chatter !")),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF6366F1),
                          borderRadius: BorderRadius.all(Radius.circular(20)),
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