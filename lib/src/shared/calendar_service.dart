import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:equatable/equatable.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ObrigacaoVenc extends Equatable {
  final String sigla;
  final String nome;
  final String descricao;
  final String fonte;
  final String url;
  final String competencia; // YYYY-MM
  final DateTime dataVencimento;
  final String observacao;

  const ObrigacaoVenc({
    required this.sigla,
    required this.nome,
    required this.descricao,
    required this.fonte,
    required this.url,
    required this.competencia,
    required this.dataVencimento,
    required this.observacao,
  });

  @override
  List<Object?> get props => [sigla, competencia, dataVencimento];

  factory ObrigacaoVenc.fromJson(Map<String, dynamic> j) => ObrigacaoVenc(
    sigla: j['sigla'],
    nome: j['nome'],
    descricao: j['descricao'],
    fonte: j['fonte'],
    url: j['url'],
    competencia: j['competencia'],
    dataVencimento: DateTime.parse(j['dataVencimento']),
    observacao: j['observacao'] ?? '',
  );
}

class CalendarPayload {
  final DateTime atualizadoEm;
  final List<Map<String, dynamic>> fontes;
  final List<ObrigacaoVenc> itens;

  CalendarPayload(this.atualizadoEm, this.fontes, this.itens);
}

class CalendarService {
  static const _assetPath = 'assets/data/obrigacoes.json';
  static const _prefsUpdatedKey = 'calendar_updated_at';

  Future<CalendarPayload> load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final j = json.decode(raw) as Map<String, dynamic>;
    final atualizadoEm = DateTime.tryParse(j['atualizadoEm'] ?? '') ?? DateTime.now();
    final fontes = (j['fontes'] as List).cast<Map<String, dynamic>>();
    final itens = (j['itens'] as List).map((e) => ObrigacaoVenc.fromJson(e)).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUpdatedKey, atualizadoEm.toIso8601String());

    return CalendarPayload(atualizadoEm, fontes, itens);
  }

  Future<DateTime?> lastUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefsUpdatedKey);
    return s == null ? null : DateTime.tryParse(s);
  }
}

final calendarServiceProvider = Provider<CalendarService>((_) => CalendarService());
final federalObligationsProvider = FutureProvider<CalendarPayload>((ref) async {
  final svc = ref.read(calendarServiceProvider);
  return svc.load();
});
