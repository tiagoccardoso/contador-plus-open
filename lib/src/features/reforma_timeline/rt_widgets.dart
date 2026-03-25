// lib/src/features/reforma_timeline/rt_widgets.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'rt_models.dart';
import 'rt_ai.dart';

IconData categoryIcon(RtCategory c) {
  switch (c) {
    case RtCategory.legislativo: return Icons.gavel_outlined;
    case RtCategory.executivo: return Icons.account_balance_outlined;
    case RtCategory.judiciario: return Icons.balance_outlined;
    case RtCategory.receita: return Icons.receipt_long_outlined;
    case RtCategory.orientacao: return Icons.menu_book_outlined;
  }
}

Color categoryColor(BuildContext context, RtCategory c) {
  final scheme = Theme.of(context).colorScheme;
  switch (c) {
    case RtCategory.legislativo: return scheme.primary;
    case RtCategory.executivo: return scheme.tertiary;
    case RtCategory.judiciario: return scheme.secondary;
    case RtCategory.receita: return scheme.error;
    case RtCategory.orientacao: return scheme.primary;
  }
}

String statusLabel(RtStatus s) {
  switch (s) {
    case RtStatus.proposto: return 'Proposto';
    case RtStatus.emTramitacao: return 'Em tramitação';
    case RtStatus.aprovado: return 'Aprovado';
    case RtStatus.vigente: return 'Vigente';
    case RtStatus.revogado: return 'Revogado';
    case RtStatus.pendenteRegulamentacao: return 'Pendente reg.';
  }
}

class RtEventCard extends StatelessWidget {
  final RtEvent e;
  const RtEventCard({super.key, required this.e});

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(context, e.category);
    final dateStr = e.hasPeriod
        ? '${_fmt(e.startDate!)} — ${_fmt(e.endDate!)}'
        : _fmt(e.date ?? e.effectiveDate);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: () => _showDetails(context, e),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(categoryIcon(e.category), color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(e.title, style: Theme.of(context).textTheme.titleMedium),
                    if (e.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(e.subtitle!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      children: [
                        Chip(label: Text(statusLabel(e.status)), visualDensity: VisualDensity.compact),
                        ...e.themes.map((t) => Chip(label: Text(t.name.toUpperCase()), visualDensity: VisualDensity.compact)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$mon/$year';
  }

  void _showDetails(BuildContext context, RtEvent e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.6,
        builder: (_, controller) => _EventDetails(e: e, controller: controller),
      ),
    );
  }
}

class _EventDetails extends StatefulWidget {
  final RtEvent e;
  final ScrollController controller;
  const _EventDetails({required this.e, required this.controller});

  @override
  State<_EventDetails> createState() => _EventDetailsState();
}

class _EventDetailsState extends State<_EventDetails> {
  final _question = TextEditingController();
  String? _answer;
  String? _error;
  bool _loading = false;
  final _ai = RtAiAdapter();

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: widget.controller,
        children: [
          Row(
            children: [
              Icon(categoryIcon(e.category), color: categoryColor(context, e.category)),
              const SizedBox(width: 8),
              Expanded(child: Text(e.title, style: Theme.of(context).textTheme.titleLarge)),
            ],
          ),
          if (e.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(e.subtitle!, style: Theme.of(context).textTheme.titleSmall),
          ],
          const SizedBox(height: 12),
          Text('Resumo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(e.summary),
          const SizedBox(height: 12),
          Text('Impacto prático', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(e.impact),
          const SizedBox(height: 12),
          Text('Fontes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          ...e.sources.map((s) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.link),
            title: Text(s.label),
            subtitle: Text(s.url.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () async { if (await canLaunchUrl(s.url)) { await launchUrl(s.url, mode: LaunchMode.externalApplication); } },
          )),
          const Divider(height: 24),
          Text('Pergunte ao Copiloto', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _question,
            decoration: const InputDecoration(
              hintText: 'Ex.: O que muda para o meu cliente do Simples?',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : _onAsk,
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Text('Perguntar à IA'),
              ),
              const SizedBox(width: 12),
              if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              if (_error != null) Expanded(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
          ),
          if (_answer != null) ...[
            const SizedBox(height: 12),
            Text('Resposta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            SelectableText(_answer!),
          ],
          const SizedBox(height: 8),
          Text('Atualizado em ${_fmt(e.updatedAt)}', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$mon/$year';
  }

  Future<void> _onAsk() async {
    setState(() { _loading = true; _error = null; _answer = null; });
    try {
      final txt = await _ai.askForEvent(widget.e, userQuestion: _question.text);
      setState(() { _answer = txt; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }
}
