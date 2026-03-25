
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/state.dart';
import '../../shared/models.dart';
import '../../shared/openai_service.dart';

class DeadlineScreen extends ConsumerWidget {
  final String id;
  const DeadlineScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final due = dueById(app, id);
    if (due == null) {
      return Scaffold(appBar: AppBar(title: const Text('Prazo')), body: const Center(child: Text('Vencimento não encontrado')));
    }
    final ob = obligationById(app, due.obligationId);
    final comp = companyById(app, due.companyId);
    final openai = OpenAiService();

    return Scaffold(
      appBar: AppBar(title: Text(ob.nome)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('${ob.nome} — ${due.competencia}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Empresa: ${comp.nome} (${comp.uf}) — Regime: ${comp.regime}'),
            Text('Vencimento: ${due.vencimento.day}/${due.vencimento.month}/${due.vencimento.year} — Status: ${due.status}'),
            const Divider(height: 32),
            Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _Checklist(),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final txt = await openai.explainDeadline(
                      empresa: comp.nome, uf: comp.uf, regime: comp.regime,
                      obrigacao: ob.nome, competencia: due.competencia,
                    );
                    // ignore: use_build_context_synchronously
                    showDialog(context: context, builder: (_) => AlertDialog(
                      title: const Text('Copiloto IA'),
                      content: Text(txt),
                      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Fechar'))],
                    ));
                  },
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('Perguntar à IA'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(appStateProvider.notifier).markSent(due.id);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marcado como enviado')));
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Marcar como enviado'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await _exportIcs(due: due, ob: ob, company: comp);
                    await Share.shareXFiles([XFile(file.path)], text: 'Vencimento ${ob.nome} — ${due.competencia}');
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Exportar .ics'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('• Validar eventos pendentes'),
        SizedBox(height: 6),
        Text('• Gerar e transmitir declarações'),
        SizedBox(height: 6),
        Text('• Arquivar número de protocolo'),
      ],
    );
  }
}

Future<File> _exportIcs({required DueDate due, required Obligation ob, required Company company}) async {
  final dt = due.vencimento;
  String two(int n) => n.toString().padLeft(2, '0');
  final dtStart = '${dt.year}${two(dt.month)}${two(dt.day)}T090000';
  final dtEnd   = '${dt.year}${two(dt.month)}${two(dt.day)}T100000';
  final uid = '${due.id}@contadorplus';
  final ics = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//ContadorPlus//BR',
    'BEGIN:VEVENT',
    'UID:$uid',
    'DTSTAMP:${dt.year}${two(dt.month)}${two(dt.day)}T000000Z',
    'DTSTART:$dtStart',
    'DTEND:$dtEnd',
    'SUMMARY:${ob.nome} — ${due.competencia}',
    'DESCRIPTION:Empresa: ${company.nome} (${company.uf}) — Regime: ${company.regime}',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\n');

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${due.id}.ics');
  await file.writeAsString(ics, flush: true);
  return file;
}
