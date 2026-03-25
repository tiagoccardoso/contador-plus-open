// lib/src/features/reforma_timeline/reforma_timeline_menu_tile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReformaTimelineMenuTile extends StatelessWidget {
  const ReformaTimelineMenuTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.timeline_outlined),
      title: const Text('Linha do tempo'),
      subtitle: const Text('Acompanhe marcos, vigência e regulamentações'),
      onTap: () => context.goNamed('reformaTimeline'),
    );
  }
}
