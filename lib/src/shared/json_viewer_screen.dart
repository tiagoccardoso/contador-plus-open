import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'cache/disk_cache.dart';
import 'open_link.dart';
import 'widgets/pretty_json_view.dart';

class JsonViewerScreen extends StatefulWidget {
  final String title;
  final Uri url;
  final Duration ttl;

  const JsonViewerScreen({
    super.key,
    required this.title,
    required this.url,
    this.ttl = const Duration(hours: 12),
  });

  @override
  State<JsonViewerScreen> createState() => _JsonViewerScreenState();
}

class _JsonViewerScreenState extends State<JsonViewerScreen> {
  final _cache = DiskCache.instance;
  final _http = http.Client();

  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  Future<dynamic> _load({bool noCache = false}) async {
    // _toJsonVariant pode retornar null; então a lista precisa aceitar Uri?
    // e depois filtramos para Uri.
    final candidates = <Uri?>[
      widget.url,
      _toJsonVariant(widget.url),
    ].whereType<Uri>().toList();

    Object? last;
    for (final u in candidates) {
      final key = 'JSON_VIEW:${u.toString()}';
      if (!noCache) {
        final cached = await _cache.getJson<dynamic>(key, ttlMinutes: widget.ttl.inMinutes);
        if (cached != null) return cached;
      }

      try {
        final res = await _http.get(u, headers: const {'accept': 'application/json'});
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw http.ClientException('HTTP ${res.statusCode}', u);
        }

        final body = utf8.decode(res.bodyBytes).trim();
        if (body.isEmpty) continue;

        dynamic decoded;
        try {
          decoded = jsonDecode(body);
        } catch (_) {
          // Não é JSON; devolve texto cru.
          decoded = body;
        }

        await _cache.putJson(key, decoded);
        return decoded;
      } catch (e) {
        last = e;
      }
    }

    throw last ?? 'Falha ao carregar conteúdo.';
  }

  Uri? _toJsonVariant(Uri u) {
    final s = u.toString();
    if (s.endsWith('.xml')) {
      return Uri.parse(s.substring(0, s.length - 4) + '.json');
    }
    // Alguns serviços do Senado aceitam .json no fim.
    if (!s.endsWith('.json') && !s.contains('?') && !s.endsWith('/')) {
      // Se já tiver extensão tipo .csv, não chuta.
      final last = u.pathSegments.isNotEmpty ? u.pathSegments.last : '';
      if (last.contains('.') && !last.endsWith('.xml')) return null;
      return Uri.parse('$s.json');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Copiar URL',
            icon: const Icon(Icons.link_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.url.toString()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL copiada.')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Abrir no navegador',
            icon: const Icon(Icons.open_in_new_outlined),
            onPressed: () => openExternal(widget.url),
          ),
        ],
      ),
      body: FutureBuilder<dynamic>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorBox(
              message: 'Falha ao carregar.\n\n${snap.error}',
              onRetry: () => setState(() => _future = _load(noCache: true)),
            );
          }

          final data = snap.data;
          if (data is String) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(data),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: PrettyJsonView(data: data),
          );
        },
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
