import 'dart:async';

import 'package:dio/dio.dart';

import 'ai_settings_store.dart';

class OpenAiService {
  final Dio _dio;

  OpenAiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 45),
              ),
            );

  Future<bool> hasConfiguredProvider() {
    return AiSettingsStore.instance.hasAnyConfiguredProvider();
  }

  String get missingConfigurationMessage =>
      'Para usar o assistente de IA, configure ao menos uma chave de API em Ajustes > IA. '
      'Você pode cadastrar OpenAI, Gemini e/ou DeepSeek, escolher a principal e deixar as outras como secundárias.';

  Future<String> ask(String question, {String? topicHint}) async {
    final providers = await AiSettingsStore.instance.orderedConfiguredProviders();
    if (providers.isEmpty) return missingConfigurationMessage;

    final systemPrompt =
        'Você é um assistente fiscal focado no Brasil. Cite fontes quando possível e lembre o usuário a confirmar na RFB e na documentação oficial. '
        'Tema: ${topicHint ?? 'Domínio Sistemas / DCTFWeb / EFD-Reinf'}.';

    final failures = <String>[];

    for (final provider in providers) {
      try {
        final text = await _askWithProvider(
          provider,
          question: question,
          systemPrompt: systemPrompt,
        );
        if (text.trim().isNotEmpty) {
          return _appendDominioLinks(text.trim(), question);
        }
        failures.add('Resposta vazia em ${provider.label}');
      } on TimeoutException {
        failures.add('Tempo limite em ${provider.label}');
      } on DioException catch (e) {
        failures.add(_describeProviderFailure(provider, e));
      } catch (_) {
        failures.add('Falha inesperada em ${provider.label}');
      }
    }

    final extra = failures.isEmpty ? '' : ' Tentativas: ${failures.join('; ')}.';
    return 'Não foi possível obter a resposta da IA agora.$extra';
  }

  Future<String> _askWithProvider(
    AiProviderConfig provider, {
    required String question,
    required String systemPrompt,
  }) {
    switch (provider.provider) {
      case AiProviderId.openai:
        return _askOpenAiCompatible(
          provider,
          endpoint: 'https://api.openai.com/v1/chat/completions',
          question: question,
          systemPrompt: systemPrompt,
        );
      case AiProviderId.deepseek:
        return _askOpenAiCompatible(
          provider,
          endpoint: 'https://api.deepseek.com/chat/completions',
          question: question,
          systemPrompt: systemPrompt,
        );
      case AiProviderId.gemini:
        return _askGemini(
          provider,
          question: question,
          systemPrompt: systemPrompt,
        );
    }
  }

  Future<String> _askOpenAiCompatible(
    AiProviderConfig provider, {
    required String endpoint,
    required String question,
    required String systemPrompt,
  }) async {
    final response = await _dio.post(
      endpoint,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': provider.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': question},
        ],
        'temperature': 0.2,
        'max_tokens': 350,
      },
    ).timeout(const Duration(seconds: 40));

    final choices = response.data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw StateError('Resposta sem choices');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      throw StateError('Resposta sem message');
    }

    final message = firstChoice['message'];
    if (message is! Map) {
      throw StateError('Resposta sem message');
    }

    return _extractTextContent(message['content']);
  }

  Future<String> _askGemini(
    AiProviderConfig provider, {
    required String question,
    required String systemPrompt,
  }) async {
    final modelPath = 'models/${Uri.encodeComponent(provider.model)}';
    final apiKey = Uri.encodeQueryComponent(provider.apiKey);
    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/$modelPath:generateContent?key=$apiKey';

    final response = await _dio.post(
      endpoint,
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
      data: {
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': question}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 350,
        }
      },
    ).timeout(const Duration(seconds: 40));

    final candidates = response.data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw StateError('Resposta sem candidates');
    }

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map) {
      throw StateError('Resposta sem content');
    }

    final content = firstCandidate['content'];
    if (content is! Map) {
      throw StateError('Resposta sem content');
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw StateError('Resposta sem parts');
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write(part['text'] as String);
      }
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) throw StateError('Resposta vazia');
    return text;
  }

  String _extractTextContent(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part['text'] is String) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.write(part['text'] as String);
        }
      }
      final text = buffer.toString().trim();
      if (text.isNotEmpty) return text;
    }
    throw StateError('Conteúdo textual não encontrado');
  }

  String _describeProviderFailure(AiProviderConfig provider, DioException error) {
    final statusCode = error.response?.statusCode;
    final label = provider.label;
    if (statusCode == 401 || statusCode == 403) {
      return 'chave inválida ou sem permissão em $label';
    }
    if (statusCode == 429) {
      return 'limite excedido em $label';
    }
    return 'erro ${statusCode ?? 'de rede'} em $label';
  }

  String _appendDominioLinks(String content, String contextText) {
    final hay = ('${content} ${contextText}').toLowerCase();
    final List<Map<String, String>> links = [];

    if (hay.contains('dctfweb') ||
        hay.contains('s-1299') ||
        hay.contains('sem movimento')) {
      links.addAll([
        {
          't': 'Como transmitir DCTFWeb (Domínio)',
          'u':
              'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=5015'
        },
        {
          't': 'DCTFWeb com S-1299 (fechamento eSocial)',
          'u':
              'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=8204'
        },
        {
          't': 'DCTFWeb sem movimento',
          'u':
              'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=8406'
        },
      ]);
    }
    if (hay.contains('reinf') || hay.contains('r-2010')) {
      links.addAll([
        {
          't': 'Configurar EFD-Reinf (Domínio)',
          'u':
              'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=6020'
        },
        {
          't': 'R-2010 Serviços Tomados (Domínio)',
          'u':
              'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=5105'
        },
      ]);
    }
    if (hay.contains('efd-contrib') ||
        hay.contains('pis') ||
        hay.contains('cofins')) {
      links.addAll([
        {
          't': 'Como gerar EFD-Contribuições (Domínio)',
          'u':
              'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=3973'
        },
        {
          't': 'Configurações do EFD-Contribuições',
          'u':
              'https://suporte.dominioatendimento.com/central/faces/solucao.html?codigo=6044'
        },
      ]);
    }

    if (links.isEmpty) return content;
    final buf = StringBuffer(content.trim());
    buf.writeln('\n\nLeituras recomendadas — Central de Soluções (Domínio/Thomson Reuters):');
    for (final link in links) {
      buf.writeln('• ${link['t']}: ${link['u']}');
    }
    return buf.toString();
  }

  Future<String> explainDeadline({
    required String empresa,
    required String uf,
    required String regime,
    required String obrigacao,
    required String competencia,
  }) async {
    final prompt = [
      'Contexto: Empresa: $empresa ($uf), Regime: $regime.',
      'Obrigação: $obrigacao, Competência: $competencia.',
      'Explique um checklist objetivo (preparar, conferir, transmitir), riscos/penalidades por atraso e referências (RFB/Domínio).',
      'Finalize lembrando: confirme sempre na Agenda Tributária da RFB e na Central de Soluções da Domínio.',
    ].join('\n');
    return ask(prompt, topicHint: obrigacao);
  }
}
