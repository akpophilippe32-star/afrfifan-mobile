import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, title: const Text('Conditions Générales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('1. Acceptation des conditions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('En utilisant l\'application Afrifan, vous acceptez pleinement les présentes conditions générales d\'utilisation.', style: TextStyle(color: Colors.grey, height: 1.5)),
            SizedBox(height: 24),
            Text('2. Contenu des utilisateurs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Les créateurs sont seuls responsables du contenu qu\'ils publient. Tout contenu illégal ou offensant entraînera la suppression immédiate du compte.', style: TextStyle(color: Colors.grey, height: 1.5)),
            SizedBox(height: 24),
            Text('3. Abonnements et remboursements', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Les abonnements sont facturés mensuellement. Les remboursements ne sont pas garantis sauf en cas de dysfonctionnement technique avéré de notre part.', style: TextStyle(color: Colors.grey, height: 1.5)),
          ],
        ),
      ),
    );
  }
}