
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../src/features/home/home_screen.dart';
import '../src/features/calendar/calendar_screen.dart';
import '../src/features/podcast/podcast_screen.dart';
import '../src/features/settings/settings_screen.dart';
import '../src/features/about/about_sources_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => RootScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CalendarScreen()),
          ),
          GoRoute(
            path: '/podcast',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PodcastScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/about',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AboutSourcesScreen()),
          ),
        ],
      ),
      // OAuth callback route (optional visual)
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Autorização recebida, finalizando...')),
        ),
      ),
    ],
  );
  return router;
});

class RootScaffold extends StatelessWidget {
  const RootScaffold({super.key, required this.child});
  final Widget child;

  static int _indexForLocation(String loc) {
    if (loc.startsWith('/calendar')) return 1;
    if (loc.startsWith('/podcast')) return 2;
    if (loc.startsWith('/settings')) return 3;
    if (loc.startsWith('/about')) return 4;
    return 0; // home
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(loc);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Calendário'),
          NavigationDestination(icon: Icon(Icons.podcasts_outlined), label: 'Podcast'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'Sobre'),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/home'); break;
            case 1: context.go('/calendar'); break;
            case 2: context.go('/podcast'); break;
            case 3: context.go('/settings'); break;
            case 4: context.go('/about'); break;
          }
        },
      ),
    );
  }
}
