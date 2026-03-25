// lib/src/features/reforma_timeline/rt_timeline_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'rt_providers.dart';
import 'rt_models.dart';
import 'rt_widgets.dart';

class ReformaTimelineScreen extends ConsumerWidget {
  const ReformaTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEvents = ref.watch(filteredRtEventsProvider);
    ref.watch(rtAutoSyncProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reforma Tributária · Linha do tempo'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: () async {
              final repo = ref.read(rtRepositoryProvider);
              await repo.syncRemote();
              ref.invalidate(rtEventsProvider);
              ref.invalidate(filteredRtEventsProvider);
            },
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Limpar filtros',
            onPressed: () => ref.read(rtFiltersProvider.notifier).state = const RtFilters(),
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          const _FiltersBar(),
          Expanded(
            child: asyncEvents.when(
              data: (List<RtEvent> events) => _EventsGroupedList(events: events),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Erro ao carregar: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends ConsumerWidget {
  const _FiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(rtFiltersProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por título, órgão, resumo...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => ref.read(rtFiltersProvider.notifier).state = filters.copyWith(query: v),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ThemeChips(filters: filters),
                const SizedBox(width: 8),
                _StatusChips(filters: filters),
                const SizedBox(width: 8),
                _CategoryChips(filters: filters),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChips extends ConsumerWidget {
  final RtFilters filters;
  const _ThemeChips({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 6,
      children: RtTheme.values.map((t) {
        final selected = filters.themes.contains(t);
        return FilterChip(
          label: Text(t.name.toUpperCase()),
          selected: selected,
          onSelected: (v) {
            final next = Set<RtTheme>.from(filters.themes);
            v ? next.add(t) : next.remove(t);
            ref.read(rtFiltersProvider.notifier).state = filters.copyWith(themes: next);
          },
        );
      }).toList(),
    );
  }
}

class _StatusChips extends ConsumerWidget {
  final RtFilters filters;
  const _StatusChips({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 6,
      children: RtStatus.values.map((s) {
        final selected = filters.statuses.contains(s);
        return FilterChip(
          label: Text(statusLabel(s)),
          selected: selected,
          onSelected: (v) {
            final next = Set<RtStatus>.from(filters.statuses);
            v ? next.add(s) : next.remove(s);
            ref.read(rtFiltersProvider.notifier).state = filters.copyWith(statuses: next);
          },
        );
      }).toList(),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  final RtFilters filters;
  const _CategoryChips({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 6,
      children: RtCategory.values.map((c) {
        final selected = filters.categories.contains(c);
        return FilterChip(
          label: Text(c.name.toUpperCase()),
          selected: selected,
          onSelected: (v) {
            final next = Set<RtCategory>.from(filters.categories);
            v ? next.add(c) : next.remove(c);
            ref.read(rtFiltersProvider.notifier).state = filters.copyWith(categories: next);
          },
        );
      }).toList(),
    );
  }
}

class _EventsGroupedList extends StatelessWidget {
  final List<RtEvent> events;
  const _EventsGroupedList({required this.events});

  @override
  Widget build(BuildContext context) {
    final groups = _groupByYear(events);
    final years = groups.keys.toList()..sort((a,b)=> b.compareTo(a));
    return ListView.builder(
      itemCount: years.length,
      itemBuilder: (ctx, i) {
        final year = years[i];
        final list = groups[year]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('$year', style: Theme.of(context).textTheme.titleLarge),
            ),
            ...list.map((e) => RtEventCard(e: e)),
          ],
        );
      },
    );
  }

  Map<int, List<RtEvent>> _groupByYear(List<RtEvent> list) {
    final map = <int, List<RtEvent>>{};
    for (final e in list) {
      final y = e.effectiveDate.year;
      map.putIfAbsent(y, () => []).add(e);
    }
    return map;
  }
}
