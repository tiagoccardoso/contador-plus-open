// lib/src/features/reforma_timeline/rt_ai.dart
import '../../shared/openai_service.dart';
import 'rt_models.dart';

class RtAiAdapter {
  final OpenAiService _svc = OpenAiService();

  Future<String> askForEvent(RtEvent e, {String? userQuestion}) {
    final prompt = buildRtEventPrompt(e, userQuestion: userQuestion);
    final topic = _inferTopic(e);
    return _svc.ask(prompt, topicHint: topic);
  }

  String _inferTopic(RtEvent e) {
    if (e.themes.contains(RtTheme.cbs)) return 'CBS / Reforma Tributária';
    if (e.themes.contains(RtTheme.ibs)) return 'IBS / Reforma Tributária';
    if (e.themes.contains(RtTheme.impostoSeletivo)) return 'Imposto Seletivo';
    if (e.themes.contains(RtTheme.regimes)) return 'Regimes Especiais';
    return 'Reforma Tributária / Brasil';
  }
}

String buildRtEventPrompt(RtEvent e, {String? userQuestion}) {
  String fmt(DateTime d) => d.toIso8601String().split('T').first;
  final when = e.hasPeriod
      ? 'Período: ${fmt(e.startDate!)} — ${fmt(e.endDate!)}'
      : (e.date != null ? 'Data: ${fmt(e.date!)}' : 'Data não especificada');
  final srcs = e.sources.map((s) => '- ${s.label}: ${s.url}').join('\n');

  final base = [
    'Contexto: Reforma Tributária no Brasil. Resuma efeitos práticos e prazos.',
    'Evento: ${e.title}',
    'Status: ${e.status.name} · Categoria: ${e.category.name} · Escopo: ${e.scope.name}',
    'Temas: ${e.themes.map((t)=>t.name).join(", ")}',
    when,
    'Resumo: ${e.summary}',
    'Impacto: ${e.impact}',
    if (srcs.isNotEmpty) 'Fontes:\n$srcs',
    if (userQuestion != null && userQuestion.trim().isNotEmpty) 'Pergunta: ${userQuestion.trim()}'
      else 'Pergunta: O que devo observar (prazos, obrigações, riscos de compliance)?',
    'Se algo depender de regulamentação, diga explicitamente.'
  ].join('\n');
  return base;
}
