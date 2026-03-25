// lib/src/features/reforma_timeline/rt_models.dart
import 'package:flutter/material.dart';

enum RtCategory { legislativo, executivo, judiciario, receita, orientacao }
enum RtStatus { proposto, emTramitacao, aprovado, vigente, revogado, pendenteRegulamentacao }
enum RtScope { federal, estadual, municipal }
enum RtTheme { cbs, ibs, impostoSeletivo, regimes, cashback, beneficios, transicao, compliance }

@immutable
class RtSource {
  final Uri url;
  final String label;
  final DateTime checkedAt;
  final String kind;

  const RtSource({
    required this.url,
    required this.label,
    required this.checkedAt,
    required this.kind,
  });

  factory RtSource.fromJson(Map<String, dynamic> j) => RtSource(
        url: Uri.parse(j['url'] as String),
        label: j['label'] as String,
        checkedAt: DateTime.parse(j['checkedAt'] as String).toUtc(),
        kind: j['kind'] as String,
      );

  Map<String, dynamic> toJson() => {
        'url': url.toString(),
        'label': label,
        'checkedAt': checkedAt.toIso8601String(),
        'kind': kind,
      };
}

@immutable
class RtEvent {
  final String id;
  final String title;
  final String? subtitle;
  final DateTime? date;
  final DateTime? startDate;
  final DateTime? endDate;
  final RtCategory category;
  final RtStatus status;
  final RtScope scope;
  final List<RtTheme> themes;
  final List<String> actors;
  final String summary;
  final String impact;
  final List<RtSource> sources;
  final Map<String, dynamic>? extra;
  final DateTime updatedAt;

  const RtEvent({
    required this.id,
    required this.title,
    this.subtitle,
    this.date,
    this.startDate,
    this.endDate,
    required this.category,
    required this.status,
    required this.scope,
    required this.themes,
    required this.actors,
    required this.summary,
    required this.impact,
    required this.sources,
    this.extra,
    required this.updatedAt,
  });

  bool get hasPeriod => startDate != null && endDate != null;
  DateTime get effectiveDate => (startDate ?? date ?? updatedAt).toUtc();

  factory RtEvent.fromJson(Map<String, dynamic> j) {
    RtStatus parseStatus(String s) {
      switch (s) {
        case 'proposto': return RtStatus.proposto;
        case 'em_tramitacao': return RtStatus.emTramitacao;
        case 'aprovado': return RtStatus.aprovado;
        case 'vigente': return RtStatus.vigente;
        case 'revogado': return RtStatus.revogado;
        case 'pendente_regulamentacao': return RtStatus.pendenteRegulamentacao;
        default: return RtStatus.emTramitacao;
      }
    }

    RtCategory parseCat(String s) {
      switch (s) {
        case 'legislativo': return RtCategory.legislativo;
        case 'executivo': return RtCategory.executivo;
        case 'judiciario': return RtCategory.judiciario;
        case 'receita': return RtCategory.receita;
        default: return RtCategory.orientacao;
      }
    }

    RtScope parseScope(String s) {
      switch (s) {
        case 'estadual': return RtScope.estadual;
        case 'municipal': return RtScope.municipal;
        default: return RtScope.federal;
      }
    }

    List<RtTheme> parseThemes(List<dynamic> list) {
      return list.map((e) {
        switch (e as String) {
          case 'cbs': return RtTheme.cbs;
          case 'ibs': return RtTheme.ibs;
          case 'is': return RtTheme.impostoSeletivo;
          case 'imposto_seletivo': return RtTheme.impostoSeletivo;
          case 'regimes': return RtTheme.regimes;
          case 'cashback': return RtTheme.cashback;
          case 'beneficios': return RtTheme.beneficios;
          case 'transicao': return RtTheme.transicao;
          default: return RtTheme.compliance;
        }
      }).toList();
    }

    return RtEvent(
      id: j['id'] as String,
      title: j['title'] as String,
      subtitle: j['subtitle'] as String?,
      date: j['date'] != null && (j['date'] as String).isNotEmpty ? DateTime.parse(j['date']).toUtc() : null,
      startDate: j['startDate'] != null ? DateTime.parse(j['startDate']).toUtc() : null,
      endDate: j['endDate'] != null ? DateTime.parse(j['endDate']).toUtc() : null,
      category: parseCat(j['category'] as String),
      status: parseStatus(j['status'] as String),
      scope: parseScope(j['scope'] as String? ?? 'federal'),
      themes: parseThemes((j['themes'] as List).cast()),
      actors: (j['actors'] as List).map((e) => e.toString()).toList(),
      summary: j['summary'] as String,
      impact: j['impact'] as String,
      sources: (j['sources'] as List).map((e) => RtSource.fromJson(Map<String, dynamic>.from(e))).toList(),
      extra: j['extra'] == null ? null : Map<String, dynamic>.from(j['extra'] as Map),
      updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'date': date?.toIso8601String(),
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'category': category.name,
    'status': (){
      switch(status){
        case RtStatus.proposto: return 'proposto';
        case RtStatus.emTramitacao: return 'em_tramitacao';
        case RtStatus.aprovado: return 'aprovado';
        case RtStatus.vigente: return 'vigente';
        case RtStatus.revogado: return 'revogado';
        case RtStatus.pendenteRegulamentacao: return 'pendente_regulamentacao';
      }
    }(),
    'scope': scope.name,
    'themes': themes.map((e)=>e.name).toList(),
    'actors': actors,
    'summary': summary,
    'impact': impact,
    'sources': sources.map((e)=>e.toJson()).toList(),
    'extra': extra,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
