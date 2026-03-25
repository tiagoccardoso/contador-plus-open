
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/state.dart';
import '../../shared/models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final now = DateTime.now();
    final upcoming = app.dues.where((d) => d.vencimento.isAfter(now.subtract(const Duration(days: 1)))).toList()
      ..sort((a, b) => a.vencimento.compareTo(b.vencimento));
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final d in upcoming) _DueTile(due: d),
        ],
      ),
    );
  }
}

class _DueTile extends ConsumerWidget {
  final DueDate due;
  const _DueTile({required this.due});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final ob = obligationById(app, due.obligationId);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text('${ob.nome} • ${due.competencia}'),
        subtitle: Text('Vence em ${due.vencimento.day}/${due.vencimento.month}/${due.vencimento.year} — ${due.status}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/deadline/${due.id}'),
      ),
    );
  }
}
