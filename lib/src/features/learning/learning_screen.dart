// lib/src/features/learning/learning_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/openai_service.dart';
import '../reforma/reforma_section_learn.dart';
import '../settings/settings_screen.dart' show AppSettingsKeys, AppSettingsStore;

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final TextEditingController _controller = TextEditingController();
  final OpenAiService _svc = OpenAiService();

  String? _answer;
  bool _loading = false;
  bool _initializedFromRoute = false;
  bool _hasConfiguredAi = false;

  @override
  void initState() {
    super.initState();
    _refreshAiStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshAiStatus();
    if (!_initializedFromRoute) {
      _initializedFromRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeInitFromRoute();
      });
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshAiStatus() async {
    final hasConfiguredAi = await _svc.hasConfiguredProvider();
    if (!mounted) return;
    setState(() => _hasConfiguredAi = hasConfiguredAi);
  }

  Future<void> _maybeInitFromRoute() async {
    final st = GoRouterState.of(context);
    final extra = st.extra;
    String? q;
    if (extra is String) q = extra;
    q ??= st.uri.queryParameters['q'];

    if (q != null && q.trim().isNotEmpty) {
      _controller.text = q;
      final auto = await AppSettingsStore.getBool(AppSettingsKeys.iaAutoAsk, or: true);
      if (!mounted) return;
      if (auto) _ask(auto: true);
    }
  }

  Future<void> _ask({bool auto = false}) async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      if (!auto) _answer = null;
    });
    try {
      final res = await _svc.ask(
        q,
        topicHint: 'Agenda Tributária / Receita Federal / DCTFWeb / EFD-Reinf',
      );
      if (!mounted) return;
      setState(() => _answer = res);
      await _refreshAiStatus();
    } catch (_) {
      if (mounted) {
        setState(() => _answer = 'Não foi possível obter a resposta agora.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprender (Pergunte para IA)'),
        actions: [
          IconButton(
            tooltip: 'Enviar',
            onPressed: _loading ? null : () => _ask(),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_hasConfiguredAi) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Para usar a consulta com IA, configure sua chave de API em Ajustes.',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Você pode configurar OpenAI, Gemini e/ou DeepSeek, escolher a principal e deixar as outras como secundárias.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Abrir Ajustes'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Pergunta',
                hintText: 'Descreva a obrigação, dúvida ou procedimento…',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : () => _ask(),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Perguntar'),
                ),
                const SizedBox(width: 12),
                if (_loading)
                  const Expanded(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_answer != null) ...[
              Text('Resposta da IA', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: SelectableText(_answer!),
              ),
              const SizedBox(height: 24),
            ],
            Text('Referências rápidas', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.launch),
                  label: const Text('DCTFWeb — Transmitir (Domínio)'),
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=5015',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.launch),
                  label: const Text('EFD-Reinf — Configurar (Domínio)'),
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=6020',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const ReformaSectionLearn(),
          ],
        ),
      ),
    );
  }
}
