import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';

/// App routing. In a full build a redirect would gate on auth + onboarding
/// completion; the structure is in place here.
class AppRouter {
  static GoRouter build({required bool isSignedIn}) => GoRouter(
        initialLocation: isSignedIn ? '/home' : '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const DashboardScreen(),
          ),
        ],
        errorBuilder: (_, state) => Scaffold(
          body: Center(child: Text('Route not found: ${state.uri}')),
        ),
      );
}
