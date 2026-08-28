import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, title: const Text('Aide & FAQ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          ExpansionTile(title: Text('Comment m\'abonner à un créateur ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFF1A1A1A), collapsedBackgroundColor: Color(0xFF1A1A1A), children: [Padding(padding: EdgeInsets.all(16), child: Text('Allez sur le profil du créateur et cliquez sur le bouton "S\'abonner". Le paiement est sécurisé.', style: TextStyle(color: Colors.grey)))]),
          SizedBox(height: 12),
          ExpansionTile(title: Text('Comment supprimer mon compte ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFF1A1A1A), collapsedBackgroundColor: Color(0xFF1A1A1A), children: [Padding(padding: EdgeInsets.all(16), child: Text('Rendez-vous dans Paramètres > À propos > Supprimer mon compte.', style: TextStyle(color: Colors.grey)))]),
          SizedBox(height: 12),
          ExpansionTile(title: Text('Mes paiements sont-ils sécurisés ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFF1A1A1A), collapsedBackgroundColor: Color(0xFF1A1A1A), children: [Padding(padding: EdgeInsets.all(16), child: Text('Oui, toutes les transactions sont chiffrées et traitées par des prestataires agréés.', style: TextStyle(color: Colors.grey)))]),
        ],
      ),
    );
  }
}