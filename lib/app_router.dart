import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/connection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/purity_test_screen.dart';
import 'screens/density_test_screen.dart';
import 'screens/combined_result_screen.dart';
import 'screens/metal_reference_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/bt_reconnect_wrapper.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // ─── Screens WITHOUT reconnect banner ───
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/connect',
      builder: (context, state) => const ConnectionScreen(),
    ),

    // ─── Screens WITH reconnect banner ───
    ShellRoute(
      builder: (context, state, child) => BtReconnectWrapper(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/purity',
          builder: (context, state) {
            final mode = state.uri.queryParameters['mode'] ?? 'standalone';
            return PurityTestScreen(mode: mode);
          },
        ),
        GoRoute(
          path: '/density',
          builder: (context, state) {
            final mode = state.uri.queryParameters['mode'] ?? 'standalone';
            return DensityTestScreen(mode: mode);
          },
        ),
        GoRoute(
          path: '/combined-result',
          builder: (context, state) => const CombinedResultScreen(),
        ),
        GoRoute(
          path: '/metals',
          builder: (context, state) => const MetalReferenceScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
