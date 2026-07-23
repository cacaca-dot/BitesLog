import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../feed/home_page.dart';
import '../discover/discover_page.dart';
import '../lists/lists_page.dart';
import '../log/log_visit_page.dart';
import '../profile/profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  // 4 tab: Home, Discover, Lists, Profile
  // Index 2 (➕) adalah aksi push — bukan tab
  final List<Widget> _pages = const [
    HomePage(),
    DiscoverPage(),
    ListsPage(),
    ProfilePage(isCurrentUser: true),
  ];

  void _openLogVisit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LogVisitPage(
          onSaved: () {
            // Setelah simpan, kembali ke Home
            setState(() => _selectedIndex = 0);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate page index from destination index
    final int pageIndex = _selectedIndex < 2 ? _selectedIndex : _selectedIndex - 1;

    return Scaffold(
      body: _pages[pageIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        // Map tap index: 0,1 → langsung, 2 → aksi push, 3,4 → geser 1
        onDestinationSelected: (i) {
          if (i == 2) {
            _openLogVisit();
          } else {
            setState(() => _selectedIndex = i);
          }
        },
        indicatorColor: AppColors.primary,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Colors.white),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: Colors.white),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline, size: 32, color: AppColors.primary),
            selectedIcon: Icon(Icons.add_circle, size: 32, color: AppColors.primary),
            label: 'Catat',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt, color: Colors.white),
            label: 'Lists',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.white),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}