import 'package:flutter/material.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildDialog(isDark);
      },
    );
  }

  Widget _buildDialog(bool isDark) {
    final dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final borderColor = isDark ? Colors.grey : Colors.grey.shade400;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signaler ce contenu',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pourquoi signalez-vous ce contenu ?',
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // ─── MOTIFS ───
            ..._reasons.map((reason) => RadioListTile<String>(
              title: Text(
                reason,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
              value: reason,
              groupValue: _selectedReason,
              // ✅ Radio actif : noir en clair / blanc en sombre
              activeColor: accentColor,
              contentPadding: EdgeInsets.zero,
              dense: true,
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
            )),

            const SizedBox(height: 20),

            // ─── BOUTONS ───
            Row(
              children: [
                // ─── ANNULER (outlined) ───
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                // ─── SIGNALER (filled accent) ───
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      // ✅ Bouton : noir en clair / blanc en sombre
                      backgroundColor: accentColor,
                      foregroundColor: accentTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: accentTextColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Signaler',
                            style: TextStyle(color: accentTextColor),
                          ),
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