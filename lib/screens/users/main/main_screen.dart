import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_notifier.dart';
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
  int _currentIndex = 0;

  final PageController _pageController = PageController();
  DateTime? _lastBackPressed;

  final List<Widget> _screens = const [
    DiscoveryScreen(),
    ExploreScreen(),
    MessagesScreen(),
    ProfileScreen(),
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;

        final bgColor = isDark ? Colors.black : Colors.white;
        final iconSelected = isDark ? Colors.white : const Color(0xFF111827);
        final iconUnselected = isDark ? Colors.white60 : Colors.grey.shade600;
        final borderColor = isDark ? Colors.white24 : Colors.black12;
        // ✅ Le "+" suit le thème : blanc en sombre, noir en clair
        final plusColor = isDark ? Colors.white : Colors.black;

        return PopScope(
          canPop: false,
          onPopInvoked: (bool didPop) async {
            if (didPop) return;

            if (_currentIndex == 0) {
              final now = DateTime.now();
              if (_lastBackPressed != null &&
                  now.difference(_lastBackPressed!) < const Duration(seconds: 5)) {
                SystemNavigator.pop();
              } else {
                _lastBackPressed = now;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appuyez encore pour quitter', textAlign: TextAlign.center),
                    backgroundColor: Colors.black87,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              setState(() => _currentIndex = 0);
              _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          child: Scaffold(
            backgroundColor: bgColor,
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
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  top: BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) async {
                  if (index == 2) {
                    await _openCameraScreen();
                    return;
                  }
                  setState(() => _currentIndex = index);
                  final targetPageIndex = _getPageIndexFromNavIndex(index);
                  _pageController.animateToPage(
                    targetPageIndex,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: bgColor,
                selectedItemColor: iconSelected,
                unselectedItemColor: iconUnselected,
                selectedFontSize: 11,
                unselectedFontSize: 11,
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
                  // ✅ "+" adaptatif : blanc en sombre, noir en clair
                  BottomNavigationBarItem(
                    icon: Icon(Icons.add_circle, size: 40, color: plusColor),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: SizedBox(
                      width: 28,
                      height: 28,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(child: Icon(Icons.chat_bubble_outline, color: iconUnselected, size: 24)),
                          const Positioned(
                            right: -4,
                            top: -2,
                            child: Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.circle, color: Colors.red, size: 16),
                            ),
                          ),
                          const Positioned(
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
                          Center(child: Icon(Icons.chat_bubble, color: iconSelected, size: 24)),
                          const Positioned(
                            right: -4,
                            top: -2,
                            child: Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.circle, color: Colors.red, size: 16),
                            ),
                          ),
                          const Positioned(
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
        );
      },
    );
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