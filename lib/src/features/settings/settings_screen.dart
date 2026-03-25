// lib/src/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/agenda_federal_service.dart';
import '../../shared/ai_settings_store.dart';
import '../../shared/calendar_service.dart';

/// =======================================================
/// Chaves centralizadas de ajustes (persistência)
/// =======================================================
class AppSettingsKeys {
  static const autoUpdateOnMonthTurn = 'settings.autoUpdateOnMonthTurn';
  static const checkOnResume = 'settings.checkOnResume';
  static const reminderDays = 'settings.reminderDays';
  static const showFederalBadge = 'settings.showFederalBadge';
  static const weekStartsMonday = 'settings.weekStartsMonday';
  static const ufDefault = 'settings.ufDefault';
  static const municipioDefault = 'settings.municipioDefault';
  static const iaAutoAsk = 'settings.iaAutoAsk';
  static const iaIncludeSource = 'settings.iaIncludeSource';
  static const themeMode = 'settings.themeMode'; // system|light|dark
}

/// Helpers simples (getters/gravadores) — opcionais para outras telas usarem.
class AppSettingsStore {
  static Future<T?> _get<T>(String key) async {
    final p = await SharedPreferences.getInstance();
    switch (T) {
      case const (bool):
        return p.getBool(key) as T?;
      case const (int):
        return p.getInt(key) as T?;
      case const (String):
        return p.getString(key) as T?;
      default:
        return null;
    }
  }

  static Future<void> setBool(String key, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  }

  static Future<void> setInt(String key, int v) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(key, v);
  }

  static Future<void> setString(String key, String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, v);
  }

  static Future<bool> getBool(String key, {required bool or}) async =>
      (await _get<bool>(key)) ?? or;
  static Future<int> getInt(String key, {required int or}) async =>
      (await _get<int>(key)) ?? or;
  static Future<String> getString(String key, {required String or}) async =>
      (await _get<String>(key)) ?? or;
}

/// =======================================================
/// Tela de Ajustes remodelada
/// =======================================================
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loading = true;

  // Sincronização / calendário
  bool _autoUpdateOnMonthTurn = true;
  bool _checkOnResume = true;
  bool _weekStartsMonday = true;
  bool _showFederalBadge = true;

  // Notificações
  int _reminderDays = 3;

  // IA
  bool _iaAutoAsk = true;
  bool _iaIncludeSource = true;
  AiProviderId _primaryAiProvider = AiProviderId.openai;
  Set<AiProviderId> _configuredProviders = <AiProviderId>{};
  final Set<AiProviderId> _savingAiProviders = <AiProviderId>{};
  late final Map<AiProviderId, TextEditingController> _apiKeyCtrls;
  late final Map<AiProviderId, TextEditingController> _modelCtrls;
  final Map<AiProviderId, bool> _showApiKey = {
    for (final provider in AiProviderId.values) provider: false,
  };

  // Locais
  final _ufCtrl = TextEditingController();
  final _munCtrl = TextEditingController();

  // Aparência
  String _themeMode = 'system';

  // Estados de ação
  bool _busyAssets = false;
  bool _busyFederalMonth = false;
  bool _busyFederalAll = false;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrls = {
      for (final provider in AiProviderId.values)
        provider: TextEditingController(),
    };
    _modelCtrls = {
      for (final provider in AiProviderId.values)
        provider: TextEditingController(text: provider.defaultModel),
    };
    _load();
  }

  @override
  void dispose() {
    _ufCtrl.dispose();
    _munCtrl.dispose();
    for (final controller in _apiKeyCtrls.values) {
      controller.dispose();
    }
    for (final controller in _modelCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    _autoUpdateOnMonthTurn = await AppSettingsStore.getBool(
      AppSettingsKeys.autoUpdateOnMonthTurn,
      or: true,
    );
    _checkOnResume = await AppSettingsStore.getBool(
      AppSettingsKeys.checkOnResume,
      or: true,
    );
    _weekStartsMonday = await AppSettingsStore.getBool(
      AppSettingsKeys.weekStartsMonday,
      or: true,
    );
    _showFederalBadge = await AppSettingsStore.getBool(
      AppSettingsKeys.showFederalBadge,
      or: true,
    );
    _reminderDays = await AppSettingsStore.getInt(
      AppSettingsKeys.reminderDays,
      or: 3,
    );
    _iaAutoAsk = await AppSettingsStore.getBool(
      AppSettingsKeys.iaAutoAsk,
      or: true,
    );
    _iaIncludeSource = await AppSettingsStore.getBool(
      AppSettingsKeys.iaIncludeSource,
      or: true,
    );
    _ufCtrl.text = await AppSettingsStore.getString(
      AppSettingsKeys.ufDefault,
      or: '',
    );
    _munCtrl.text = await AppSettingsStore.getString(
      AppSettingsKeys.municipioDefault,
      or: '',
    );
    _themeMode = await AppSettingsStore.getString(
      AppSettingsKeys.themeMode,
      or: 'system',
    );

    final aiSnapshot = await AiSettingsStore.instance.load();
    _primaryAiProvider = aiSnapshot.primaryProvider;
    for (final config in aiSnapshot.providers) {
      _apiKeyCtrls[config.provider]!.text = config.apiKey;
      _modelCtrls[config.provider]!.text = config.model;
    }
    _syncConfiguredProviders();

    if (mounted) setState(() => _loading = false);
  }

  void _syncConfiguredProviders() {
    _configuredProviders = AiProviderId.values
        .where((provider) => _apiKeyCtrls[provider]!.text.trim().isNotEmpty)
        .toSet();
  }

  Future<void> _savePrimaryAiProvider(AiProviderId provider) async {
    setState(() => _primaryAiProvider = provider);
    await AiSettingsStore.instance.savePrimaryProvider(provider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'IA principal definida como ${provider.label}. As demais configuradas serão usadas como secundárias.',
        ),
      ),
    );
  }

  Future<void> _saveAiProvider(AiProviderId provider) async {
    setState(() => _savingAiProviders.add(provider));
    try {
      await AiSettingsStore.instance.saveProviderConfig(
        provider: provider,
        apiKey: _apiKeyCtrls[provider]!.text,
        model: _modelCtrls[provider]!.text,
      );
      _syncConfiguredProviders();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${provider.label} salvo em Ajustes > IA.')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingAiProviders.remove(provider));
      }
    }
  }

  Future<void> _clearAiProvider(AiProviderId provider) async {
    setState(() => _savingAiProviders.add(provider));
    try {
      await AiSettingsStore.instance.clearProvider(provider);
      _apiKeyCtrls[provider]!.text = '';
      _modelCtrls[provider]!.text = provider.defaultModel;
      _syncConfiguredProviders();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${provider.label} removido.')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingAiProviders.remove(provider));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.read(calendarServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Calendário & Sincronização',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _autoUpdateOnMonthTurn,
                  title: const Text('Atualizar na virada do mês'),
                  subtitle: const Text(
                    'Baixa a Agenda Tributária automaticamente à meia-noite.',
                  ),
                  onChanged: (v) async {
                    setState(() => _autoUpdateOnMonthTurn = v);
                    await AppSettingsStore.setBool(
                      AppSettingsKeys.autoUpdateOnMonthTurn,
                      v,
                    );
                  },
                ),
                SwitchListTile(
                  value: _checkOnResume,
                  title: const Text('Checar ao voltar do background'),
                  subtitle: const Text(
                    'Ao reabrir o app, verifica se mudou o mês e atualiza.',
                  ),
                  onChanged: (v) async {
                    setState(() => _checkOnResume = v);
                    await AppSettingsStore.setBool(
                      AppSettingsKeys.checkOnResume,
                      v,
                    );
                  },
                ),
                SwitchListTile(
                  value: _weekStartsMonday,
                  title: const Text('Semana começa na segunda'),
                  onChanged: (v) async {
                    setState(() => _weekStartsMonday = v);
                    await AppSettingsStore.setBool(
                      AppSettingsKeys.weekStartsMonday,
                      v,
                    );
                  },
                ),
                SwitchListTile(
                  value: _showFederalBadge,
                  title: const Text('Mostrar selo FED no calendário'),
                  onChanged: (v) async {
                    setState(() => _showFederalBadge = v);
                    await AppSettingsStore.setBool(
                      AppSettingsKeys.showFederalBadge,
                      v,
                    );
                  },
                ),
                const Divider(height: 24),
                Text('Notificações', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Avisar antes:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _reminderDays,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('no dia')),
                        DropdownMenuItem(value: 1, child: Text('1 dia')),
                        DropdownMenuItem(value: 3, child: Text('3 dias')),
                        DropdownMenuItem(value: 5, child: Text('5 dias')),
                        DropdownMenuItem(value: 7, child: Text('7 dias')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _reminderDays = v);
                        await AppSettingsStore.setInt(
                          AppSettingsKeys.reminderDays,
                          v,
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text('IA', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.key_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Para consultar a IA, configure ao menos uma chave de API.',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Você pode cadastrar OpenAI, Gemini e DeepSeek, definir a principal e deixar as demais como secundárias. '
                          'Se a principal falhar, o app tenta automaticamente as outras que estiverem configuradas.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'As chaves ficam salvas localmente no aparelho.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusChip(
                              label: 'Principal: ${_primaryAiProvider.label}',
                              active: true,
                            ),
                            _StatusChip(
                              label: _configuredProviders.isEmpty
                                  ? 'Nenhuma IA configurada'
                                  : '${_configuredProviders.length} IA(s) configurada(s)',
                              active: _configuredProviders.isNotEmpty,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AiProviderId>(
                          value: _primaryAiProvider,
                          decoration: const InputDecoration(
                            labelText: 'IA principal',
                            border: OutlineInputBorder(),
                          ),
                          items: AiProviderId.values
                              .map(
                                (provider) => DropdownMenuItem(
                                  value: provider,
                                  child: Text(provider.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            _savePrimaryAiProvider(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _iaAutoAsk,
                  title: const Text('Rodar explicação automaticamente'),
                  subtitle: const Text(
                    'Ao abrir a tela de IA a partir de um item, envia a pergunta imediatamente.',
                  ),
                  onChanged: (v) async {
                    setState(() => _iaAutoAsk = v);
                    await AppSettingsStore.setBool(AppSettingsKeys.iaAutoAsk, v);
                  },
                ),
                SwitchListTile(
                  value: _iaIncludeSource,
                  title: const Text('Incluir fonte oficial no prompt'),
                  onChanged: (v) async {
                    setState(() => _iaIncludeSource = v);
                    await AppSettingsStore.setBool(
                      AppSettingsKeys.iaIncludeSource,
                      v,
                    );
                  },
                ),
                const SizedBox(height: 8),
                for (final provider in AiProviderId.values) ...[
                  _AiProviderCard(
                    provider: provider,
                    apiKeyController: _apiKeyCtrls[provider]!,
                    modelController: _modelCtrls[provider]!,
                    configured: _configuredProviders.contains(provider),
                    isPrimary: provider == _primaryAiProvider,
                    revealKey: _showApiKey[provider] ?? false,
                    saving: _savingAiProviders.contains(provider),
                    onRevealToggle: () {
                      setState(() {
                        _showApiKey[provider] = !(_showApiKey[provider] ?? false);
                      });
                    },
                    onChanged: () => setState(_syncConfiguredProviders),
                    onSave: () => _saveAiProvider(provider),
                    onClear: () => _clearAiProvider(provider),
                  ),
                  const SizedBox(height: 12),
                ],
                const Divider(height: 24),
                Text(
                  'Feriados locais (padrões)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ufCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'UF (ex.: SP)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) => AppSettingsStore.setString(
                    AppSettingsKeys.ufDefault,
                    v.trim().toUpperCase(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _munCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Município (IBGE ou nome)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) => AppSettingsStore.setString(
                    AppSettingsKeys.municipioDefault,
                    v.trim(),
                  ),
                ),
                const Divider(height: 24),
                Text('Aparência', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'system', label: Text('Sistema')),
                    ButtonSegment(value: 'light', label: Text('Claro')),
                    ButtonSegment(value: 'dark', label: Text('Escuro')),
                  ],
                  selected: {_themeMode},
                  onSelectionChanged: (s) async {
                    final v = s.first;
                    setState(() => _themeMode = v);
                    await AppSettingsStore.setString(
                      AppSettingsKeys.themeMode,
                      v,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Ações', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.refresh),
                          title: const Text(
                            'Atualizar calendário (recarregar assets)',
                          ),
                          subtitle: const Text(
                            'Recarrega o arquivo embutido em assets/data/obrigacoes.json',
                          ),
                          onTap: _busyAssets
                              ? null
                              : () async {
                                  setState(() => _busyAssets = true);
                                  try {
                                    await svc.load();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Calendário recarregado.'),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Falha ao recarregar: $e'),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _busyAssets = false);
                                    }
                                  }
                                },
                          trailing: _busyAssets
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                        ),
                        ListTile(
                          leading: const Icon(Icons.flag_circle_outlined),
                          title: const Text(
                            'Atualizar agenda federal (mês atual)',
                          ),
                          subtitle: const Text(
                            'Limpa cache do mês atual e baixa novamente do gov.br',
                          ),
                          onTap: _busyFederalMonth
                              ? null
                              : () async {
                                  setState(() => _busyFederalMonth = true);
                                  try {
                                    final now = DateTime.now();
                                    final monthKey = DateTime(now.year, now.month, 1);
                                    final fresh = await AgendaFederalService
                                        .instance
                                        .refreshNow(monthKey);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Agenda federal atualizada: ${fresh.length} itens em '
                                          '${now.month.toString().padLeft(2, '0')}/${now.year}',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Falha ao atualizar a agenda federal: $e',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _busyFederalMonth = false);
                                    }
                                  }
                                },
                          trailing: _busyFederalMonth
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete_sweep_outlined),
                          title: const Text(
                            'Limpar cache da agenda federal (todos os meses)',
                          ),
                          subtitle: const Text(
                            'Apaga cache em memória e disco; força nova coleta quando necessário',
                          ),
                          onTap: _busyFederalAll
                              ? null
                              : () async {
                                  setState(() => _busyFederalAll = true);
                                  try {
                                    await AgendaFederalService.instance.clearAllCache();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Cache da agenda federal limpo.',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Falha ao limpar cache: $e'),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _busyFederalAll = false);
                                    }
                                  }
                                },
                          trailing: _busyFederalAll
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'As preferências entram em vigor imediatamente nos módulos que as leem. '
                  'Notificações dependem de integração com o agendador (ex.: flutter_local_notifications).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle_outline : Icons.info_outline,
        size: 18,
      ),
      label: Text(label),
    );
  }
}

class _AiProviderCard extends StatelessWidget {
  final AiProviderId provider;
  final TextEditingController apiKeyController;
  final TextEditingController modelController;
  final bool configured;
  final bool isPrimary;
  final bool revealKey;
  final bool saving;
  final VoidCallback onRevealToggle;
  final VoidCallback onChanged;
  final VoidCallback onSave;
  final VoidCallback onClear;

  const _AiProviderCard({
    required this.provider,
    required this.apiKeyController,
    required this.modelController,
    required this.configured,
    required this.isPrimary,
    required this.revealKey,
    required this.saving,
    required this.onRevealToggle,
    required this.onChanged,
    required this.onSave,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(provider.label, style: theme.textTheme.titleSmall),
                ),
                if (isPrimary) const _StatusChip(label: 'Principal', active: true),
                const SizedBox(width: 8),
                _StatusChip(
                  label: configured ? 'Configurada' : 'Sem chave',
                  active: configured,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(provider.helperText, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: modelController,
              decoration: InputDecoration(
                labelText: 'Modelo',
                hintText: provider.defaultModel,
                helperText: 'Padrão sugerido: ${provider.defaultModel}',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: apiKeyController,
              obscureText: !revealKey,
              decoration: InputDecoration(
                labelText: 'Chave da API',
                hintText: 'Cole aqui a chave do ${provider.label}',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onRevealToggle,
                  icon: Icon(
                    revealKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  ),
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Salvar'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: saving ? null : onClear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Limpar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
