// lib/src/features/reforma_timeline/rt_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'rt_models.dart';

const String kRtRemoteFeedUrl = '';
const String _kPrefsCacheKey = 'rt_events_cache_v1';

class RtEventsRepository {
  RtEventsRepository();

  Future<List<RtEvent>> loadSeed() async {
    final raw = await rootBundle.loadString('assets/reforma/events.json');
    final data = jsonDecode(raw) as List;
    return data.map((e) => RtEvent.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<RtEvent>> loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsCacheKey);
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw) as List;
      return data.map((e) => RtEvent.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCache(List<RtEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsCacheKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  Future<List<RtEvent>> listEvents() async {
    final seed = await loadSeed();
    final cache = await loadCache();
    final merged = _merge(seed, cache);
    merged.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return merged;
  }

  Future<List<RtEvent>> syncRemote() async {
    if (kRtRemoteFeedUrl.isEmpty) return listEvents();
    final resp = await http.get(Uri.parse(kRtRemoteFeedUrl));
    if (resp.statusCode != 200) return listEvents();
    final data = jsonDecode(resp.body) as List;
    final remote = data.map((e) => RtEvent.fromJson(Map<String, dynamic>.from(e))).toList();
    await saveCache(remote);
    return listEvents();
  }

  List<RtEvent> _merge(List<RtEvent> a, List<RtEvent> b) {
    final map = <String, RtEvent>{ for (final e in a) e.id: e };
    for (final e in b) {
      final current = map[e.id];
      if (current == null) { map[e.id] = e; continue; }
      map[e.id] = (e.updatedAt.isAfter(current.updatedAt)) ? e : current;
    }
    return map.values.toList();
  }
}
