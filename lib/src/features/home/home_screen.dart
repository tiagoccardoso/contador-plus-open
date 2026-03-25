import '../../shared/non_affiliation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../shared/agenda_federal_service.dart';
import '../../shared/providers.dart'; // exporta appStateProvider, helpers
import '../../shared/state.dart';     // AppState para tipos

enum _HomeKind { federal, local }

class _HomeItem {
  final DateTime date;
  final String title;
  final _HomeKind kind;
  final String? code;        // usado em federais
  final String? sourceUrl;   // link oficial (federais)
  final String? companyId;   // locais
  final String? obligationId;// locais
  const _HomeItem({
    required this.date,
    required this.title,
    required this.kind,
    this.code,
    this.sourceUrl,
    this.companyId,
    this.obligationId,
  });
}

/// Home sincronizada com a MESMA FONTE do Calendário (gov.br via AgendaFederalService),
/// combinando vencimentos locais do AppState e evitando duplicidades.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  Timer? _midnightTimer;

  bool _loading = false;
  String? _error;

  late DateTime _today;
  late DateTime _monthKeyNow;
  late DateTime _monthKeyNext;

  @override
  void initState() {
    super.initState();
    
    NonAffiliationNotice.scheduleOnce(context);
_today = DateTime.now();
    _monthKeyNow = DateTime(_today.year, _today.month, 1);
    _monthKeyNext = DateTime(_today.year, _today.month + 1, 1);

    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightTick();

    _refreshData(initial: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfMonthChanged();
      _scheduleMidnightTick();
    }
  }

  void _scheduleMidnightTick() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight =
    DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _midnightTimer = Timer(nextMidnight.difference(now), () async {
      _refreshIfMonthChanged();
      _scheduleMidnightTick();
    });
  }

  Future<void> _refreshIfMonthChanged() async {
    final now = DateTime.now();
    final keyNow = DateTime(now.year, now.month, 1);
    if (keyNow.year != _monthKeyNow.year || keyNow.month != _monthKeyNow.month) {
      setState(() {
        _today = now;
        _monthKeyNow = keyNow;
        _monthKeyNext = DateTime(keyNow.year, keyNow.month + 1, 1);
      });
      await _refreshData();
    } else {
      setState(() => _today = now);
    }
  }

  Future<void> _refreshData({bool initial = false}) async {
    setState(() {
      _loading = true;
      if (!initial) _error = null;
    });
    try {
      // PRÉ-CARREGA os dois meses no mesmo serviço do Calendário
      await Future.wait([
        AgendaFederalService.instance.getMonth(_monthKeyNow),
        AgendaFederalService.instance.getMonth(_monthKeyNext),
      ]);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ==========================
  // COMBINAÇÃO + DEDUPLICAÇÃO
  // ==========================
  List<_HomeItem> _combinedForRange(AppState app, DateTime from, DateTime to) {
    final items = <_HomeItem>[];

    // Meses únicos que cobrem o intervalo (evita processar o mesmo mês 2x)
    final monthKeys = <DateTime>{
      DateTime(from.year, from.month, 1),
      DateTime(to.year, to.month, 1),
    };

    // Chaves já vistas para evitar duplicados
    final seen = <String>{};

    // Federais do serviço (mesma fonte do Calendário)
    for (final mk in monthKeys) {
      final list = AgendaFederalService.instance.peekMonth(mk);
      for (final f in list) {
        if (!f.date.isBefore(from) && !f.date.isAfter(to)) {
          final id = '${f.date.toIso8601String()}|FED|${f.code ?? ''}|${f.title}';
          if (seen.add(id)) {
            items.add(_HomeItem(
              date: f.date,
              title: f.title,
              kind: _HomeKind.federal,
              code: f.code,
              sourceUrl: f.sourceUrl,
            ));
          }
        }
      }
    }

    // Locais do AppState (por empresa/obrigação)
    for (final d in app.dues) {
      final v = d.vencimento;
      if (!v.isBefore(from) && !v.isAfter(to)) {
        final ob = obligationById(app, d.obligationId);
        final comp = companyById(app, d.companyId);
        final title = '${ob.nome} — ${comp.nome}';
        final id = '${v.toIso8601String()}|LOC|${d.companyId}|${d.obligationId}';
        if (seen.add(id)) {
          items.add(_HomeItem(
            date: v,
            title: title,
            kind: _HomeKind.local,
            companyId: d.companyId,
            obligationId: d.obligationId,
          ));
        }
      }
    }

    items.sort((a, b) {
      final c = a.date.compareTo(b.date);
      if (c != 0) return c;
      if (a.kind != b.kind) return a.kind == _HomeKind.federal ? -1 : 1;
      return a.title.compareTo(b.title);
    });
    return items;
  }

  List<_HomeItem> _searchInMonth(AppState app, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final begin = _monthKeyNow;
    final end = DateTime(_monthKeyNext.year, _monthKeyNext.month + 1, 0);
    final items = _combinedForRange(app, begin, end);

    return items.where((it) {
      final text = (it.title + (it.code ?? '')).toLowerCase();
      return text.contains(q);
    }).toList(growable: false);
  }

  // ==========================
  // IA
  // ==========================
  String _promptForItem(_HomeItem it) {
    final dd =
        '${it.date.day.toString().padLeft(2, '0')}/${it.date.month.toString().padLeft(2, '0')}/${it.date.year}';
    final code = it.code == null ? '' : ' (código ${it.code})';
    final src = it.sourceUrl == null ? '' : '\nFonte oficial: ${it.sourceUrl}';
    final tipo = it.kind == _HomeKind.federal ? 'obrigação federal' : 'obrigação';
    return 'Explique a $tipo abaixo, em linguagem simples, considerando vencimento em $dd$code. '
        'Inclua: quem deve cumprir, base legal, como preparar/entregar, comprovantes, multas por atraso e boas práticas.\n\n'
        '${it.title}$src';
  }

  Future<void> _openAskAI(BuildContext context, String question) async {
    try {
      context.push('/learning', extra: question);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: question));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pergunta copiada. Abra a tela "Aprender" para colar.')),
      );
    }
  }

  // =========
  // BUILD
  // =========
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider); // seus dados locais (empresas/obrigações/vencimentos)

    final theme = Theme.of(context);

    final query = _searchCtrl.text;
    final searching = query.trim().isNotEmpty;

    // próximas 2 semanas
    final from = DateTime(_today.year, _today.month, _today.day);
    final to = from.add(const Duration(days: 13));
    final upcoming = _combinedForRange(app, from, to);

    final results = searching ? _searchInMonth(app, query) : const <_HomeItem>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
      body: RefreshIndicator(
        onRefresh: () => _refreshData(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Busca
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Pesquisar obrigações…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                  tooltip: 'Limpar',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  'Não foi possível atualizar do gov.br:\n$_error',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),

            // Resultados da busca
            if (searching) ...[
              const _SectionHeader(title: 'Resultados'),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nenhum item encontrado para “$query”.',
                      style: theme.textTheme.bodyMedium),
                )
              else
                ...results.map((it) => _ItemTile(
                  it: it,
                  onTap: () => _openAskAI(context, _promptForItem(it)),
                )),
              const SizedBox(height: 16),
            ],

            // Próximas obrigações (14 dias)
            const _SectionHeader(title: 'Próximas obrigações (14 dias)'),
            if (upcoming.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Nada por aqui nas próximas duas semanas.',
                    style: theme.textTheme.bodyMedium),
              )
            else
              ...upcoming.map((it) => _ItemTile(
                it: it,
                onTap: () => _openAskAI(context, _promptForItem(it)),
              )),
            const SizedBox(height: 24),

            Text(
              'Dica: toque em qualquer item para perguntar direto para a IA. '
                  'Puxe para baixo para atualizar.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(title, style: theme.textTheme.titleMedium),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final _HomeItem it;
  final VoidCallback onTap;
  const _ItemTile({required this.it, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dd = it.date.day.toString().padLeft(2, '0');
    final mm = it.date.month.toString().padLeft(2, '0');

    final color = it.kind == _HomeKind.federal
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;

    final icon = it.kind == _HomeKind.federal
        ? Icons.flag_outlined
        : Icons.event_note;

    final chipLabel = it.kind == _HomeKind.federal
        ? (it.code == null ? 'FED' : 'FED ${it.code}')
        : 'LOCAL';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
			  backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(it.title),
        subtitle: Text('$dd/$mm/${it.date.year} • $chipLabel'),
        trailing: IconButton(
          tooltip: 'Perguntar para IA',
          icon: const Icon(Icons.auto_awesome),
          onPressed: onTap,
        ),
      ),
    );
  }
}
