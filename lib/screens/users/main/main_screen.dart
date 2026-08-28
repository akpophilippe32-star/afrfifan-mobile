import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../home/discovery_screen.dart';
import '../explore/explore_screen.dart';
import '../create/camera_screen.dart';
import '../messages/messages_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // 0=Home, 1=Explore, 2=+, 3=Messages, 4=Profile
  
  // ✅ NOUVEAU : Contrôleur pour gérer le swipe horizontal
  final PageController _pageController = PageController();

  // ✅ Les 4 vrais écrans (le "+" n'est pas un écran, c'est une action)
  final List<Widget> _screens = const [
    DiscoveryScreen(),   // Index PageView: 0  -> Index Nav: 0
    ExploreScreen(),     // Index PageView: 1  -> Index Nav: 1
    MessagesScreen(),    // Index PageView: 2  -> Index Nav: 3
    ProfileScreen(),     // Index PageView: 3  -> Index Nav: 4
  ];

  @override
  void dispose() {
    _pageController.dispose(); // ✅ Nettoyage mémoire
    super.dispose();
  }

  // ✅ ASTUCE : Convertir l'index de la barre de nav en index de PageView
  int _getPageIndexFromNavIndex(int navIndex) {
    if (navIndex < 2) return navIndex;       // 0 -> 0, 1 -> 1
    if (navIndex > 2) return navIndex - 1;   // 3 -> 2, 4 -> 3
    return 0; // Fallback pour le bouton "+"
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // ✅ REMPLACÉ IndexedStack PAR PageView pour le swipe
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(), // Effet de rebond fluide
        onPageChanged: (pageIndex) {
          // Quand on swipe, on met à jour l'onglet actif en bas
          setState(() {
            _currentIndex = pageIndex < 2 ? pageIndex : pageIndex + 1;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(color: Colors.white24, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) async {
            // ✅ GESTION DU BOUTON "+" (Index 2)
            if (index == 2) {
              await _openCameraScreen();
              return; // On ne change pas l'onglet actif, on reste où on était
            }

            // ✅ GESTION DES AUTRES ONGLETS
            setState(() {
              _currentIndex = index;
            });
            
            // Animation fluide vers la page correspondante
            final targetPageIndex = _getPageIndexFromNavIndex(index);
            _pageController.animateToPage(
              targetPageIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            // 1. Home
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            // 2. Explorer
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explorer',
            ),
            // 3. Créer (+) - Style TikTok/Snapchat
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, size: 40, color: Color(0xFF8B5CF6)), // Simplifié pour plus de propreté
              label: '', 
            ),
            // 4. Messages
            BottomNavigationBarItem(
              icon: SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(child: Icon(Icons.chat_bubble_outline, size: 24)),
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '9',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              activeIcon: SizedBox(
                width: 28,
                height: 28,
                child: Center(child: Icon(Icons.chat_bubble, size: 24)),
              ),
              label: 'Messages',
            ),
            // 5. Profile
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Ouvre la caméra style Snapchat
  Future<void> _openCameraScreen() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const CameraScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}