// lib/router/reforma_timeline_routes.dart
import 'package:go_router/go_router.dart';
import '../src/features/reforma_timeline/rt_timeline_screen.dart';

GoRoute reformaTimelineRoute() => GoRoute(
  path: '/reforma/timeline',
  name: 'reformaTimeline',
  pageBuilder: (ctx, state) => const NoTransitionPage(child: ReformaTimelineScreen()),
);
