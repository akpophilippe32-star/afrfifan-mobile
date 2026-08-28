import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, title: const Text('Politique de confidentialité', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Collecte des données', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Nous collectons uniquement les données nécessaires au fonctionnement de l\'application : nom, email, et données de paiement sécurisées.', style: TextStyle(color: Colors.grey, height: 1.5)),
            SizedBox(height: 24),
            Text('Utilisation des données', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Vos données ne sont jamais vendues à des tiers. Elles servent uniquement à améliorer votre expérience et à assurer la sécurité de la plateforme.', style: TextStyle(color: Colors.grey, height: 1.5)),
            SizedBox(height: 24),
            Text('Vos droits', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Conformément à la loi, vous avez un droit d\'accès, de modification et de suppression de vos données personnelles à tout moment.', style: TextStyle(color: Colors.grey, height: 1.5)),
          ],
        ),
      ),
    );
  }
}