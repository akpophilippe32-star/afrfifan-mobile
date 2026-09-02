import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Pour fermer l'application proprement
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
  
  final PageController _pageController = PageController();

  // ✅ NOUVEAU : Le "Chronomètre" pour mesurer le délai de 5 secondes
  DateTime? _lastBackPressed;

  final List<Widget> _screens = const [
    DiscoveryScreen(),   // Index PageView: 0  -> Index Nav: 0
    ExploreScreen(),     // Index PageView: 1  -> Index Nav: 1
    MessagesScreen(),    // Index PageView: 2  -> Index Nav: 3
    ProfileScreen(),     // Index PageView: 3  -> Index Nav: 4
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getPageIndexFromNavIndex(int navIndex) {
    if (navIndex < 2) return navIndex;       
    if (navIndex > 2) return navIndex - 1;   
    return 0; 
  }

  @override
  Widget build(BuildContext context) {
    // ✅ NOUVEAU : Le "Garde" qui intercepte le bouton retour du téléphone
    return PopScope(
      canPop: false, // On dit à Flutter : "Ne ferme pas l'app tout de suite, je gère"
      onPopInvoked: (bool didPop) async {
        if (didPop) return; // Si c'est déjà fermé, on ne fait rien

        if (_currentIndex == 0) {
          // CAS 1 : On est DÉJÀ sur l'onglet Home
          final now = DateTime.now();
          
          // Si le dernier appui était il y a moins de 5 secondes
          if (_lastBackPressed != null && 
              now.difference(_lastBackPressed!) < const Duration(seconds: 5)) {
            
            // ✅ C'est le 2ème appui rapide : On ferme l'application
            SystemNavigator.pop();
            
          } else {
            // ✅ C'est le 1er appui : On lance le chrono et on affiche le message
            _lastBackPressed = now;
            ScaffoldMessenger.of(context).clearSnackBars(); // Nettoie les anciens messages
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Appuyez encore pour quitter', textAlign: TextAlign.center),
                backgroundColor: Colors.black87,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2), // Le message disparaît visuellement après 2s
              ),
            );
          }
        } else {
          // CAS 2 : On est sur un AUTRE onglet (Profil, Messages, etc.)
          // On ramène l'utilisateur à la maison (Home)
          setState(() {
            _currentIndex = 0;
          });
          
          _pageController.animateToPage(
            0, // Retour à l'index 0 du PageView (DiscoveryScreen)
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      
      // Le reste de ton interface est enveloppé dans ce PopScope
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (pageIndex) {
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
              if (index == 2) {
                await _openCameraScreen();
                return;
              }

              setState(() {
                _currentIndex = index;
              });
              
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
            
            // ✅ CORRECTION ICI : J'ai enlevé le mot-clé 'const' devant le crochet '['
            // Cela empêche l'erreur de compilation avec le Container imbriqué
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Explorer',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle, size: 40, color: Color(0xFF8B5CF6)),
                label: '', 
              ),
              
              // Item Messages (avec le badge)
              const BottomNavigationBarItem(
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
                        child: Padding(
                          padding: EdgeInsets.all(2.0), // Simplifié pour éviter l'erreur const
                          child: Icon(Icons.circle, color: Colors.red, size: 16),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        top: 1,
                        child: Text(
                          '9',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                activeIcon: SizedBox(
                  width: 28,
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(child: Icon(Icons.chat_bubble, size: 24)),
                      Positioned(
                        right: -4,
                        top: -2,
                        child: Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.circle, color: Colors.red, size: 16),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        top: 1,
                        child: Text(
                          '9',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                label: 'Messages',
              ),
              
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    ); // ✅ Fin du PopScope
  }

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