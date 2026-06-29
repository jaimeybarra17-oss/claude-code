import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../ai_coach/coach_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../jobs/jobs_screen.dart';
import '../practice/practice_screen.dart';
import '../profile/profile_screen.dart';

/// The five-destination app shell. Owns the bottom navigation and keeps each
/// tab's state alive via an IndexedStack. Five destinations max keeps the nav
/// simple and thumb-reachable (see docs/DESIGN_SYSTEM.md).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    DashboardScreen(),
    PracticeScreen(),
    CoachScreen(),
    JobsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), label: 'Practice'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Coach'),
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
