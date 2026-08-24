import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'voice_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _isAnswering = false;

  Future<void> _answerCall() async {
    if (_isAnswering) return;
    setState(() => _isAnswering = true);
    
    print("📞 [IncomingCall] UTILISATEUR A DÉCROCHÉ ! Call ID: ${widget.callId}");

    if (mounted) {
      print("🔄 [IncomingCall] Navigation vers VoiceCallScreen...");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceCallScreen(
            otherUserId: widget.callerId,
            otherUserName: widget.callerName,
            otherUserAvatar: widget.callerAvatar,
            callId: widget.callId,
            isReceiver: true,
          ),
        ),
      );
    }
  }

  Future<void> _declineCall() async {
    print("📞 [IncomingCall] Utilisateur a refusé l'appel.");
    
    try {
      await Supabase.instance.client
          .from('calls')
          .update({'status': 'rejected'})
          .eq('id', widget.callId);
      print("✅ [IncomingCall] Statut mis à jour : rejected");
    } catch (e) {
      print("⚠️ [IncomingCall] Erreur mise à jour statut : $e");
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(padding: EdgeInsets.all(24.0)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Appel vocal entrant...", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF1C1C1F),
                    backgroundImage: widget.callerAvatar != null ? NetworkImage(widget.callerAvatar!) : null,
                    child: widget.callerAvatar == null ? const Icon(Icons.person, color: Colors.white, size: 60) : null,
                  ),
                  const SizedBox(height: 24),
                  Text(widget.callerName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _declineCall,
                    child: Column(
                      children: [
                        Container(width: 72, height: 72, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.call_end, color: Colors.white, size: 36)),
                        const SizedBox(height: 12),
                        const Text("Refuser", style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _answerCall,
                    child: Column(
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                          child: _isAnswering ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.call, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 12),
                        const Text("Décrocher", style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
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