
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'models.dart';

class AppState {
  final List<Company> companies;
  final List<Obligation> obligations;
  final List<DueDate> dues;

  const AppState({this.companies = const [], this.obligations = const [], this.dues = const []});

  AppState copyWith({List<Company>? companies, List<Obligation>? obligations, List<DueDate>? dues}) =>
      AppState(companies: companies ?? this.companies, obligations: obligations ?? this.obligations, dues: dues ?? this.dues);
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(const AppState());

  Future<void> loadSeeds() async {
    if (state.dues.isNotEmpty) return;
    try {
      final companies = (json.decode(await rootBundle.loadString('assets/seeds/companies.json')) as List).map((e) => Company.fromJson(e)).toList();
      final obligations = (json.decode(await rootBundle.loadString('assets/seeds/obligations.json')) as List).map((e) => Obligation.fromJson(e)).toList();
      final dues = (json.decode(await rootBundle.loadString('assets/seeds/dues.json')) as List).map((e) => DueDate.fromJson(e)).toList();
      state = state.copyWith(companies: companies, obligations: obligations, dues: dues);
    } catch (_) {
      // Se assets não existirem, mantém estado vazio (app continua renderizando)
      state = const AppState();
    }
  }

  void markSent(String dueId) {
    final updated = state.dues.map((d) => d.id == dueId ? d.copyWith(status: 'enviado') : d).toList();
    state = state.copyWith(dues: updated);
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) => AppStateNotifier());

Company companyById(AppState s, String id) => s.companies.firstWhere((c) => c.id == id);
Obligation obligationById(AppState s, String id) => s.obligations.firstWhere((o) => o.id == id);
DueDate? dueById(AppState s, String id) {
  for (final d in s.dues) {
    if (d.id == id) return d;
  }
  return null;
}
