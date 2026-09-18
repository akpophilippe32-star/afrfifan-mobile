import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'video_call_screen.dart';
import '../../../services/messaging_service.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT
import '../creator/creator_profile_screen.dart';
import 'voice_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasText = false;
  bool _showEmojiPanel = false;
  bool _showAttachmentMenu = false;

  bool _isRecording = false;
  bool _isRecordingStopped = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _currentRecordingPath;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId;

  Map<String, dynamic>? _replyTo;
  Map<String, dynamic>? _editingMessage;
  String? _currentUserId;
  RealtimeChannel? _realtimeChannel;

  static const List<String> _emojis = [
    '😀', '😁', '😂', '🤣', '😅', '😊', '😍', '😘', '😎', '🥺', '😭', '😤', '😡', '🤔', '🤫',
    '👍', '👎', '👏', '🙌', '🤝', '💪', '🙏', '❤️', '💜', '💙', '💚', '💛', '🖤', '💯', '✨',
    '🔥', '💥', '💦', '🎉', '🎊', '🎵', '🎮', '📸', '🍕', '🍔', '🍟', '🚗', '✈️', '🏠', '💼', '💰',
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _messageController.addListener(_syncHasText);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPanel) {
        setState(() => _showEmojiPanel = false);
      }
    });
    _loadMessages();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _messageController.removeListener(_syncHasText);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _realtimeChannel?.unsubscribe();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _syncHasText() {
    final has = _messageController.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final messages = await _messagingService.fetchConversation(otherUserId: widget.otherUserId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        await _messagingService.markConversationAsRead(widget.otherUserId);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement messages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeListener() {
    final supabase = Supabase.instance.client;
    _realtimeChannel = supabase.channel('chat:${widget.otherUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: _currentUserId),
          callback: (payload) {
            final newMessage = payload.newRecord;
            if (newMessage['sender_id'] == widget.otherUserId && mounted) {
              setState(() => _messages.add(newMessage));
              _messagingService.markAsRead(newMessage['id'].toString());
              _scrollToBottom();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final updated = payload.newRecord;
            if (mounted && _isRelevantMessage(updated)) {
              setState(() {
                final idx = _messages.indexWhere((m) => m['id'].toString() == updated['id'].toString());
                if (idx != -1) _messages[idx] = updated;
              });
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final deletedId = payload.oldRecord['id'].toString();
            if (mounted) {
              setState(() => _messages.removeWhere((m) => m['id'].toString() == deletedId));
            }
          },
        )
        .subscribe();
  }

  bool _isRelevantMessage(Map<String, dynamic> msg) {
    return (msg['sender_id'] == _currentUserId && msg['receiver_id'] == widget.otherUserId) ||
           (msg['sender_id'] == widget.otherUserId && msg['receiver_id'] == _currentUserId);
  }

  Future<void> _sendMessage() => _sendContent(_messageController.text.trim(), 'text');
  Future<void> _sendLike() => _sendContent('👍', 'text');

  void _onSendPressed() {
    if (_editingMessage != null) {
      _applyEdit();
    } else if (_hasText) {
      _sendMessage();
    } else {
      _sendLike();
    }
  }

  Future<void> _sendContent(String content, String type) async {
    if (content.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    final reply = _replyTo;

    final optimisticMessage = <String, dynamic>{
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': _currentUserId,
      'receiver_id': widget.otherUserId,
      'type': type,
      'content': content,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    };
    if (reply != null) {
      optimisticMessage['reply_to_id'] = reply['id'];
      optimisticMessage['reply_to_content'] = reply['content'];
      optimisticMessage['reply_to_name'] = reply['name'];
    }

    setState(() {
      _messages.add(optimisticMessage);
      _replyTo = null;
    });

    _messageController.clear();
    _syncHasText();
    _scrollToBottom();

    try {
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': widget.otherUserId,
        'type': type,
        'content': content,
        'reply_to_id': reply?['id']?.toString(),
        'reply_to_content': reply?['content'],
        'reply_to_name': reply?['name'],
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Erreur envoi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _applyEdit() async {
    final message = _editingMessage;
    if (message == null) return;
    final newContent = _messageController.text.trim();
    if (newContent.isEmpty) return;
    final id = message['id'].toString();
    setState(() => _isSending = true);

    void applyLocal() {
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'].toString() == id);
        if (idx != -1) {
          _messages[idx] = {..._messages[idx], 'content': newContent, 'is_edited': true};
        }
        _editingMessage = null;
        _messageController.clear();
      });
      _syncHasText();
    }

    if (id.startsWith('temp_')) {
      applyLocal();
      setState(() => _isSending = false);
      return;
    }

    try {
      await Supabase.instance.client.from('messages').update({'content': newContent, 'is_edited': true}).eq('id', id);
      applyLocal();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur modification'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final id = message['id'].toString();
    setState(() {
      _messages.removeWhere((m) => m['id'].toString() == id);
      if (_editingMessage?['id'].toString() == id) _editingMessage = null;
    });
    if (id.startsWith('temp_')) return;
    try {
      await Supabase.instance.client.from('messages').delete().eq('id', id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur suppression'), backgroundColor: Colors.red));
    }
  }

  void _confirmDelete(Map<String, dynamic> message, bool isDark) {
    final dialogBg = isDark ? const Color(0xFF1C1C1F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer ce message ?', style: TextStyle(color: textColor, fontSize: 16)),
        content: Text('Ce message sera supprimé pour vous et votre destinataire.', style: TextStyle(color: subTextColor, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: subTextColor))),
          TextButton(onPressed: () { Navigator.pop(context); _deleteMessage(message); }, child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _openMessageMenu(Map<String, dynamic> message, bool isDark) {
    final isMine = message['sender_id'] == _currentUserId;
    final content = message['content']?.toString() ?? '';
    final type = message['type'] ?? 'text';

    final sheetBg = isDark ? const Color(0xFF1C1C1F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuTile(Icons.reply, 'Répondre', textColor, () {
                Navigator.pop(context);
                setState(() {
                  _replyTo = {'id': message['id'], 'content': content, 'name': isMine ? 'Vous' : widget.otherUserName};
                  _editingMessage = null;
                });
                _focusNode.requestFocus();
              }),
              if (type != 'voice')
                _menuTile(Icons.copy, 'Copier', textColor, () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: content));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copié'), backgroundColor: Colors.grey, behavior: SnackBarBehavior.floating));
                }),
              if (isMine && type != 'voice')
                _menuTile(Icons.edit_outlined, 'Modifier', textColor, () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMessage = message;
                    _replyTo = null;
                    _messageController.text = content;
                  });
                  _syncHasText();
                  _focusNode.requestFocus();
                }),
              if (isMine)
                _menuTile(Icons.delete_outline, 'Supprimer', const Color(0xFFEF4444), () {
                  Navigator.pop(context);
                  _confirmDelete(message, isDark);
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: color), title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)), onTap: onTap);
  }

  void _openUserProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorProfileScreen(creatorId: widget.otherUserId)));
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final sel = _messageController.selection;
    if (sel.isValid && sel.start <= text.length && sel.end <= text.length) {
      _messageController.text = text.replaceRange(sel.start, sel.end, emoji);
      _messageController.selection = TextSelection.collapsed(offset: sel.start + emoji.length);
    } else {
      _messageController.text = text + emoji;
      _messageController.selection = TextSelection.collapsed(offset: _messageController.text.length);
    }
    _syncHasText();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String _formatTime(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt).toLocal();
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) { return ''; }
  }

  bool _isSameDay(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  String _formatDateSeparator(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
      if (messageDate == today) return 'Aujourd\'hui';
      if (messageDate == yesterday) return 'Hier';
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) { return ''; }
  }

  bool _isEmojiOnly(String s) {
    final t = s.trim();
    if (t.isEmpty || t.length > 16) return false;
    return !RegExp(r'''[A-Za-z0-9À-ɏ.,;:!?'""()\-\n]''').hasMatch(t);
  }

  void _showEncryptionInfo(bool isDark) {
    final dialogBg = isDark ? const Color(0xFF1C1C1F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.lock_outline, color: textColor),
          const SizedBox(width: 8),
          Expanded(child: Text('Sécurité des données', style: TextStyle(color: textColor, fontSize: 16))),
        ]),
        content: Text('Vos messages et appels sont protégés par un chiffrement en transit et au repos grâce à l\'infrastructure sécurisée de Supabase.',
            style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 14)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK', style: TextStyle(color: textColor)))],
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() { _isSending = true; _showAttachmentMenu = false; });
    try {
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await File(image.path).readAsBytes();

      await Supabase.instance.client.storage.from('chat_images').uploadBinary(fileName, fileBytes);
      final imageUrl = Supabase.instance.client.storage.from('chat_images').getPublicUrl(fileName);

      await _sendContent(imageUrl, 'image');
    } catch (e) {
      debugPrint('❌ Erreur envoi image: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'envoi de l\'image'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      _currentRecordingPath = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: _currentRecordingPath!,
      );

      setState(() { _isRecording = true; _isRecordingStopped = false; _recordingSeconds = 0; });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _recordingSeconds++);
      });
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    if (mounted) setState(() { _isRecording = false; _isRecordingStopped = true; _currentRecordingPath = path; });
  }

  void _cancelRecording() {
    _recordingTimer?.cancel();
    _audioRecorder.stop();
    if (mounted) setState(() { _isRecording = false; _isRecordingStopped = false; _recordingSeconds = 0; _currentRecordingPath = null; });
  }

  Future<void> _sendVoiceMessage() async {
    if (_currentRecordingPath == null) return;
    setState(() => _isSending = true);
    try {
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final fileBytes = await File(_currentRecordingPath!).readAsBytes();

      await Supabase.instance.client.storage.from('voice_messages').uploadBinary(fileName, fileBytes);
      final audioUrl = Supabase.instance.client.storage.from('voice_messages').getPublicUrl(fileName);

      final optimisticVoice = {
        'id': 'temp_voice_${DateTime.now().millisecondsSinceEpoch}',
        'sender_id': _currentUserId,
        'receiver_id': widget.otherUserId,
        'type': 'voice',
        'content': audioUrl,
        'duration': _recordingSeconds,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      setState(() { _messages.add(optimisticVoice); });
      _scrollToBottom();

      await Supabase.instance.client.from('messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': widget.otherUserId,
        'type': 'voice',
        'content': audioUrl,
        'duration': _recordingSeconds,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) setState(() { _isRecordingStopped = false; _recordingSeconds = 0; _currentRecordingPath = null; });
    } catch (e) {
      debugPrint("❌ Erreur envoi vocal : $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _playVoiceMessage(String messageId, String url) async {
    if (_playingMessageId == messageId) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _playingMessageId = null);
      return;
    }
    if (mounted) setState(() => _playingMessageId = messageId);
    await _audioPlayer.setUrl(url);
    await _audioPlayer.play();
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playingMessageId = null);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
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
    final subTextColor = isDark ? Colors.grey.shade500 : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    // Couleurs des bulles
    final myBubbleColor = accentColor;
    final myBubbleTextColor = accentTextColor;
    final otherBubbleColor = isDark ? const Color(0xFF1F1F23) : const Color(0xFFF3F4F6);
    final otherBubbleTextColor = isDark ? Colors.white : Colors.black87;

    // Input
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF3F4F6);
    final attachBtnBg = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E7EB);
    final attachIconColor = isDark ? Colors.white70 : Colors.black54;

    // Barres contextuelles
    final contextBarBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF3F4F6);
    final contextBarBorder = accentColor.withOpacity(0.4);
    final dateSepBg = isDark ? const Color(0xFF232327) : const Color(0xFFE5E7EB);
    final dateSepText = isDark ? Colors.grey.shade300 : Colors.black87;
    final menuBg = isDark ? const Color(0xFF1C1C1F) : Colors.white;
    final emojiPanelBg = isDark ? const Color(0xFF141417) : const Color(0xFFF3F4F6);
    final infoBarBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF3F4F6);

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accentColor), onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _openUserProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Stack(clipBehavior: Clip.none, children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  backgroundImage: widget.otherUserAvatar != null ? NetworkImage(widget.otherUserAvatar!) : null,
                  child: widget.otherUserAvatar == null
                      ? Icon(Icons.person, color: textColor, size: 20)
                      : null,
                ),
                Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: bgColor, width: 2)))),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.otherUserName, style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Text('En ligne', style: TextStyle(color: Color(0xFF22C55E), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call_outlined, color: accentColor),
            onPressed: () async {
              final currentUserId = Supabase.instance.client.auth.currentUser?.id;
              if (currentUserId != null) {
                try {
                  final response = await Supabase.instance.client.from('calls').insert({'caller_id': currentUserId, 'receiver_id': widget.otherUserId, 'status': 'ongoing', 'call_type': 'audio'}).select();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => VoiceCallScreen(otherUserId: widget.otherUserId, otherUserName: widget.otherUserName, otherUserAvatar: widget.otherUserAvatar, callId: response[0]['id'], isReceiver: false)));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.videocam_outlined, color: accentColor),
            onPressed: () async {
              final currentUserId = Supabase.instance.client.auth.currentUser?.id;
              if (currentUserId != null) {
                try {
                  final response = await Supabase.instance.client.from('calls').insert({'caller_id': currentUserId, 'receiver_id': widget.otherUserId, 'status': 'ongoing', 'call_type': 'video'}).select();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => VideoCallScreen(otherUserId: widget.otherUserId, otherUserName: widget.otherUserName, otherUserAvatar: widget.otherUserAvatar, callId: response[0]['id'], isReceiver: false)));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Envoyez le premier message !',
                          style: TextStyle(color: subTextColor, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final i = _messages.length - 1 - index;
                          final message = _messages[i];

                          Widget? separator;

                          if (i == _messages.length - 1) {
                            separator = _dateSeparator(message['created_at'].toString(), dateSepBg, dateSepText);
                          } else if (i < _messages.length - 1) {
                            final next = DateTime.parse(_messages[i + 1]['created_at'].toString());
                            final current = DateTime.parse(message['created_at'].toString());
                            if (!_isSameDay(next, current)) {
                              separator = _dateSeparator(message['created_at'].toString(), dateSepBg, dateSepText);
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (separator != null) separator,
                              _messageBubble(
                                message,
                                isDark: isDark,
                                myBubbleColor: myBubbleColor,
                                myBubbleTextColor: myBubbleTextColor,
                                otherBubbleColor: otherBubbleColor,
                                otherBubbleTextColor: otherBubbleTextColor,
                                accentColor: accentColor,
                                subTextColor: subTextColor,
                                infoBarBg: infoBarBg,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          // Zone de saisie
          Container(
            color: bgColor,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_editingMessage != null)
                    _contextBar(
                      icon: Icons.edit_outlined,
                      title: 'Modification du message',
                      content: _editingMessage!['content']?.toString() ?? '',
                      onCancel: () { setState(() { _editingMessage = null; _messageController.clear(); }); _syncHasText(); },
                      barBg: contextBarBg,
                      barBorder: contextBarBorder,
                      textColor: textColor,
                      accentColor: accentColor,
                      subTextColor: subTextColor,
                    )
                  else if (_replyTo != null)
                    _contextBar(
                      icon: Icons.reply,
                      title: 'Réponse à ${_replyTo!['name']}',
                      content: _replyTo!['content']?.toString() ?? '',
                      onCancel: () => setState(() => _replyTo = null),
                      barBg: contextBarBg,
                      barBorder: contextBarBorder,
                      textColor: textColor,
                      accentColor: accentColor,
                      subTextColor: subTextColor,
                    ),

                  if (_isRecording) _recordingBar(bgColor, textColor, subTextColor),
                  if (_isRecordingStopped) _previewVoiceBar(bgColor, textColor, accentColor, accentTextColor),

                  if (!_isRecording && !_isRecordingStopped)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
  Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _focusNode,
                              style: TextStyle(color: textColor),
                              cursorColor: accentColor,
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => _syncHasText(),
                              decoration: InputDecoration(
                                hintText: _editingMessage != null ? 'Modifier le message...' : 'Écrivez un message...',
                                hintStyle: TextStyle(color: subTextColor),
                                filled: true,
                                fillColor: inputBg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.emoji_emotions_outlined, color: subTextColor),
                                  onPressed: () => setState(() { _showEmojiPanel = !_showEmojiPanel; _showAttachmentMenu = false; if (_showEmojiPanel) _focusNode.unfocus(); }),
                                ),
                              ),
                              onSubmitted: (_) => _onSendPressed(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_isSending)
                            SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: accentColor, strokeWidth: 2))
                          else if (_editingMessage != null)
                            GestureDetector(
                              onTap: _applyEdit,
                              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                                  child: Icon(Icons.check, color: accentTextColor, size: 22)),
                            )
                          else if (_hasText)
                            GestureDetector(
                              onTap: _sendMessage,
                              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                                  child: Icon(Icons.send, color: accentTextColor, size: 20)),
                            )
                          else
                            GestureDetector(
                              onTap: _startRecording,
                              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                                  child: Icon(Icons.mic, color: accentTextColor, size: 24)),
                            ),
                        ],
                      ),
                    ),
                  if (_showEmojiPanel) _emojiPanel(emojiPanelBg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordingBar(Color bgColor, Color textColor, Color subTextColor) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 28)),
          ),
          Expanded(
            child: Column(children: [
              Container(width: 16, height: 16, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
              const SizedBox(height: 8),
              Text('${(_recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Enregistrement...', style: TextStyle(color: subTextColor, fontSize: 12)),
            ]),
          ),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.stop, color: Colors.white, size: 28)),
          ),
        ],
      ),
    );
  }

  Widget _previewVoiceBar(Color bgColor, Color textColor, Color accentColor, Color accentTextColor) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 28)),
          ),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.mic, color: accentColor, size: 24),
              const SizedBox(width: 8),
              Text('Message vocal • ${(_recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          ),
          GestureDetector(
            onTap: _sendVoiceMessage,
            child: Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                child: Icon(Icons.send, color: accentTextColor, size: 28)),
          ),
        ],
      ),
    );
  }

  Widget _contextBar({
    required IconData icon,
    required String title,
    required String content,
    required VoidCallback onCancel,
    required Color barBg,
    required Color barBorder,
    required Color textColor,
    required Color accentColor,
    required Color subTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: barBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: barBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(content, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subTextColor, fontSize: 12)),
              ]),
            ),
            IconButton(icon: Icon(Icons.close, color: subTextColor, size: 18), onPressed: onCancel),
          ],
        ),
      ),
    );
  }

  Widget _dateSeparator(String createdAt, Color bg, Color textColor) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Text(_formatDateSeparator(createdAt).toUpperCase(),
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _messageBubble(
    Map<String, dynamic> message, {
    required bool isDark,
    required Color myBubbleColor,
    required Color myBubbleTextColor,
    required Color otherBubbleColor,
    required Color otherBubbleTextColor,
    required Color accentColor,
    required Color subTextColor,
    required Color infoBarBg,
  }) {
    final isMine = message['sender_id'] == _currentUserId;
    final messageType = message['type'] ?? 'text';
    final content = message['content']?.toString() ?? '';
    final createdAt = message['created_at']?.toString() ?? '';
    final isRead = message['is_read'] == true;
    final isEdited = message['is_edited'] == true;
    final duration = message['duration'] != null ? message['duration'].toString() : '0:00';

    if (messageType == 'call_log') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: infoBarBg, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.call, color: accentColor, size: 18),
            const SizedBox(width: 8),
            Text(content, style: TextStyle(color: subTextColor, fontSize: 13)),
          ]),
        ),
      );
    }

    if (messageType == 'image') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
          GestureDetector(
            onLongPress: () => _openMessageMenu(message, isDark),
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(content, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 150,
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        child: Icon(Icons.broken_image, color: subTextColor))),
              ),
            ),
          ),
        ]),
      );
    }

    if (messageType == 'voice') {
      final isPlaying = _playingMessageId == message['id'];
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
          GestureDetector(
            onLongPress: () => _openMessageMenu(message, isDark),
            onTap: () => _playVoiceMessage(message['id'], content),
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMine ? myBubbleColor : otherBubbleColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: isMine ? myBubbleTextColor : otherBubbleTextColor, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Message vocal',
                        style: TextStyle(color: (isMine ? myBubbleTextColor : otherBubbleTextColor).withOpacity(0.8), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(duration, style: TextStyle(color: isMine ? myBubbleTextColor : otherBubbleTextColor, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(width: 12),
                  Icon(Icons.multitrack_audio,
                      color: (isMine ? myBubbleTextColor : otherBubbleTextColor).withOpacity(0.5), size: 24),
                ],
              ),
            ),
          ),
        ]),
      );
    }

    final isSticker = _isEmojiOnly(content);
    final replyName = message['reply_to_name']?.toString();
    final replyContent = message['reply_to_content']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        GestureDetector(
          onLongPress: () => _openMessageMenu(message, isDark),
          child: isSticker
              ? Text(content, style: const TextStyle(fontSize: 56))
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMine ? myBubbleColor : otherBubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMine ? 18 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (replyContent != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isMine ? myBubbleTextColor : otherBubbleTextColor).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border(
                                  left: BorderSide(
                                    color: isMine ? myBubbleTextColor : accentColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(replyName ?? '',
                                      style: TextStyle(
                                          color: isMine ? myBubbleTextColor : accentColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(replyContent, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: (isMine ? myBubbleTextColor : otherBubbleTextColor).withOpacity(0.7),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          Text(content,
                              style: TextStyle(
                                  color: isMine ? myBubbleTextColor : otherBubbleTextColor,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: -8,
                      right: isMine ? 0 : null,
                      left: isMine ? null : 0,
                      child: CustomPaint(
                          size: const Size(12, 10),
                          painter: _BubbleTailPainter(
                              color: isMine ? myBubbleColor : otherBubbleColor,
                              mirror: !isMine)),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_formatTime(createdAt)}${isEdited ? ' · modifié' : ''}',
                style: TextStyle(color: subTextColor, fontSize: 11)),
            if (isMine) ...[
              const SizedBox(width: 4),
              Icon(isRead ? Icons.done_all : Icons.done,
                  size: 14,
                  color: isRead ? accentColor : subTextColor),
            ],
          ],
        ),
      ]),
    );
  }

  Widget _emojiPanel(Color bg) {
    return Container(
      height: 240,
      color: bg,
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, childAspectRatio: 1),
        itemCount: _emojis.length,
        itemBuilder: (_, i) => GestureDetector(onTap: () => _insertEmoji(_emojis[i]), child: Center(child: Text(_emojis[i], style: const TextStyle(fontSize: 26)))),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool mirror;
  _BubbleTailPainter({required this.color, this.mirror = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path();
    if (!mirror) {
      path.moveTo(w, 0); path.lineTo(w, h); path.quadraticBezierTo(0, h, 0, 0); path.close();
    } else {
      path.moveTo(0, 0); path.lineTo(0, h); path.quadraticBezierTo(w, h, w, 0); path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}