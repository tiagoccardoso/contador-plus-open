// lib/src/features/reforma_timeline/rt_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'rt_models.dart';
import 'rt_repository.dart';

final rtRepositoryProvider = Provider<RtEventsRepository>((ref) => RtEventsRepository());

final rtEventsProvider = FutureProvider<List<RtEvent>>((ref) async {
  final repo = ref.watch(rtRepositoryProvider);
  return repo.listEvents();
});

class RtFilters {
  final String query;
  final Set<RtTheme> themes;
  final Set<RtStatus> statuses;
  final Set<RtCategory> categories;

  const RtFilters({
    this.query = '',
    this.themes = const {},
    this.statuses = const {},
    this.categories = const {},
  });

  RtFilters copyWith({
    String? query,
    Set<RtTheme>? themes,
    Set<RtStatus>? statuses,
    Set<RtCategory>? categories,
  }) => RtFilters(
    query: query ?? this.query,
    themes: themes ?? this.themes,
    statuses: statuses ?? this.statuses,
    categories: categories ?? this.categories,
  );

  bool get isEmpty => query.isEmpty && themes.isEmpty && statuses.isEmpty && categories.isEmpty;
}

List<RtEvent> applyFilters(List<RtEvent> events, RtFilters f) {
  if (f.isEmpty) return events;
  bool matchText(RtEvent e) {
    if (f.query.isEmpty) return true;
    final q = f.query.toLowerCase();
    return e.title.toLowerCase().contains(q) ||
           (e.subtitle ?? '').toLowerCase().contains(q) ||
           e.summary.toLowerCase().contains(q) ||
           e.impact.toLowerCase().contains(q) ||
           e.actors.join(' ').toLowerCase().contains(q);
  }
  return events.where((e) =>
    matchText(e) &&
    (f.themes.isEmpty || e.themes.any(f.themes.contains)) &&
    (f.statuses.isEmpty || f.statuses.contains(e.status)) &&
    (f.categories.isEmpty || f.categories.contains(e.category))
  ).toList();
}

final rtFiltersProvider = StateProvider<RtFilters>((ref) => const RtFilters());

final filteredRtEventsProvider = FutureProvider<List<RtEvent>>((ref) async {
  final events = await ref.watch(rtEventsProvider.future);
  final filters = ref.watch(rtFiltersProvider);
  return applyFilters(events, filters);
});

final rtAutoSyncProvider = FutureProvider<void>((ref) async {
  final repo = ref.read(rtRepositoryProvider);
  await repo.syncRemote();
  ref.invalidate(rtEventsProvider);
  try { ref.invalidate(filteredRtEventsProvider); } catch (_) {}
});
