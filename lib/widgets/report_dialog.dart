import 'package:flutter/material.dart';
import '../services/report_service.dart';

class ReportDialog extends StatefulWidget {
  final String targetId;
  final String targetType; // 'post' ou 'profile'

  const ReportDialog({
    super.key,
    required this.targetId,
    required this.targetType,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final ReportService _reportService = ReportService();
  String? _selectedReason;
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Spam ou contenu trompeur',
    'Nudité ou contenu sexuel',
    'Harcèlement ou intimidation',
    'Violence ou contenu dangereux',
    'Arnaque ou fraude',
    'Faux compte',
    'Autre',
  ];

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un motif')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _reportService.submitReport(
        targetId: widget.targetId,
        targetType: widget.targetType,
        reason: _selectedReason!,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signalement envoyé. Merci !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Signaler ce contenu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pourquoi signalez-vous ce contenu ?',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            
            ..._reasons.map((reason) => RadioListTile<String>(
              title: Text(reason, style: const TextStyle(color: Colors.white, fontSize: 14)),
              value: reason,
              groupValue: _selectedReason,
              activeColor: const Color(0xFF8B5CF6),
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
            )),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Signaler'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}