import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProviderId { openai, gemini, deepseek }

extension AiProviderIdX on AiProviderId {
  String get keyName {
    switch (this) {
      case AiProviderId.openai:
        return 'openai';
      case AiProviderId.gemini:
        return 'gemini';
      case AiProviderId.deepseek:
        return 'deepseek';
    }
  }

  String get label {
    switch (this) {
      case AiProviderId.openai:
        return 'OpenAI';
      case AiProviderId.gemini:
        return 'Gemini';
      case AiProviderId.deepseek:
        return 'DeepSeek';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderId.openai:
        return 'gpt-4o-mini';
      case AiProviderId.gemini:
        return 'gemini-2.5-flash';
      case AiProviderId.deepseek:
        return 'deepseek-chat';
    }
  }

  String get helperText {
    switch (this) {
      case AiProviderId.openai:
        return 'Compatível com Chat Completions da OpenAI.';
      case AiProviderId.gemini:
        return 'Usa a Gemini API com chave criada no Google AI Studio.';
      case AiProviderId.deepseek:
        return 'Usa a API compatível com chat da DeepSeek.';
    }
  }
}

AiProviderId? aiProviderFromKey(String? key) {
  switch (key) {
    case 'openai':
      return AiProviderId.openai;
    case 'gemini':
      return AiProviderId.gemini;
    case 'deepseek':
      return AiProviderId.deepseek;
    default:
      return null;
  }
}

class AiProviderConfig {
  final AiProviderId provider;
  final String apiKey;
  final String model;

  const AiProviderConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;
  String get label => provider.label;
}

class AiSettingsSnapshot {
  final AiProviderId primaryProvider;
  final List<AiProviderConfig> providers;

  const AiSettingsSnapshot({
    required this.primaryProvider,
    required this.providers,
  });

  bool get hasAnyConfiguredProvider =>
      providers.any((provider) => provider.isConfigured);

  List<AiProviderConfig> orderedProviders() {
    final orderedIds = <AiProviderId>[
      primaryProvider,
      ...AiProviderId.values.where((provider) => provider != primaryProvider),
    ];

    final byId = {for (final item in providers) item.provider: item};
    return orderedIds
        .map((id) => byId[id])
        .whereType<AiProviderConfig>()
        .toList(growable: false);
  }

  List<AiProviderConfig> orderedConfiguredProviders() {
    return orderedProviders()
        .where((provider) => provider.isConfigured)
        .toList(growable: false);
  }
}

class AiSettingsStore {
  AiSettingsStore._();

  static final AiSettingsStore instance = AiSettingsStore._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const _primaryProviderKey = 'settings.ai.primaryProvider';
  static const _openAiModelKey = 'settings.ai.openai.model';
  static const _geminiModelKey = 'settings.ai.gemini.model';
  static const _deepseekModelKey = 'settings.ai.deepseek.model';

  String _modelKeyFor(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openai:
        return _openAiModelKey;
      case AiProviderId.gemini:
        return _geminiModelKey;
      case AiProviderId.deepseek:
        return _deepseekModelKey;
    }
  }

  String _apiKeyStorageKeyFor(AiProviderId provider) =>
      'settings.ai.${provider.keyName}.apiKey';

  Future<AiSettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = aiProviderFromKey(prefs.getString(_primaryProviderKey)) ??
        AiProviderId.openai;

    final providers = <AiProviderConfig>[];
    for (final provider in AiProviderId.values) {
      final apiKey =
          await _secureStorage.read(key: _apiKeyStorageKeyFor(provider)) ?? '';
      final model = prefs.getString(_modelKeyFor(provider)) ?? provider.defaultModel;
      providers.add(
        AiProviderConfig(
          provider: provider,
          apiKey: apiKey,
          model: model,
        ),
      );
    }

    return AiSettingsSnapshot(primaryProvider: primary, providers: providers);
  }

  Future<void> savePrimaryProvider(AiProviderId provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_primaryProviderKey, provider.keyName);
  }

  Future<void> saveModel(AiProviderId provider, String model) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = model.trim().isEmpty ? provider.defaultModel : model.trim();
    await prefs.setString(_modelKeyFor(provider), clean);
  }

  Future<void> saveApiKey(AiProviderId provider, String apiKey) async {
    final clean = apiKey.trim();
    final storageKey = _apiKeyStorageKeyFor(provider);
    if (clean.isEmpty) {
      await _secureStorage.delete(key: storageKey);
      return;
    }
    await _secureStorage.write(key: storageKey, value: clean);
  }

  Future<void> saveProviderConfig({
    required AiProviderId provider,
    required String apiKey,
    required String model,
  }) async {
    await saveModel(provider, model);
    await saveApiKey(provider, apiKey);
  }

  Future<void> clearProvider(AiProviderId provider) async {
    await saveApiKey(provider, '');
    await saveModel(provider, provider.defaultModel);
  }

  Future<bool> hasAnyConfiguredProvider() async {
    final snapshot = await load();
    return snapshot.hasAnyConfiguredProvider;
  }

  Future<List<AiProviderConfig>> orderedConfiguredProviders() async {
    final snapshot = await load();
    return snapshot.orderedConfiguredProviders();
  }
}
