import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';

/// Cache simples em disco baseado em arquivos JSON.
///
/// - Cada chave vira um arquivo `.json` (nome seguro via SHA1 da chave).
/// - Salva `{ ts, data }`.
/// - Suporta TTL por leitura e também leitura "stale" (ignorando TTL).
/// - Faz *prune* leve para não crescer sem limite.
class DiskCache {
  DiskCache._();
  static final DiskCache instance = DiskCache._();

  Directory? _dir;
  DateTime? _lastPrune;
  final _rnd = Random();

  Future<Directory> _baseDir() async {
    if (_dir != null) return _dir!;
    final d = await getApplicationSupportDirectory();
    final cache = Directory('${d.path}/cache_camara_v2');
    if (!cache.existsSync()) cache.createSync(recursive: true);
    _dir = cache;
    return cache;
  }

  String _safeName(String key) {
    // Evita nomes gigantes e caracteres inválidos no SO.
    final digest = crypto.sha1.convert(utf8.encode(key)).toString();
    return '$digest.json';
  }

  Future<File> _fileFor(String key) async {
    final dir = await _baseDir();
    return File('${dir.path}/${_safeName(key)}');
  }

  Future<void> putJson(String key, Object? value) async {
    final f = await _fileFor(key);
    final wrapped = {'ts': DateTime.now().toIso8601String(), 'data': value};
    await f.writeAsString(json.encode(wrapped), flush: true);
    // Prune ocasional, sem travar a UI.
    // Rodar com probabilidade baixa também evita loops de escrita.
    if (_rnd.nextInt(20) == 0) {
      // ignore: unawaited_futures
      prune();
    }
  }

  /// Retorna o JSON salvo se não expirado.
  ///
  /// - [ttlMinutes] define tempo máximo em minutos.
  /// - Se `ttlMinutes == null`, nunca expira.
  Future<T?> getJson<T>(String key, {int? ttlMinutes}) async {
    final f = await _fileFor(key);
    if (!f.existsSync()) return null;
    try {
      final raw = await f.readAsString();
      final m = json.decode(raw) as Map<String, dynamic>;
      final ts = DateTime.tryParse(m['ts']?.toString() ?? '');
      if (ttlMinutes != null && ts != null) {
        final exp = ts.add(Duration(minutes: ttlMinutes));
        if (DateTime.now().isAfter(exp)) return null;
      }
      return m['data'] as T?;
    } catch (_) {
      // Cache corrompido: elimina para não crashar sempre.
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      return null;
    }
  }

  /// Retorna o JSON ignorando TTL ("stale"), útil como fallback em falha de rede.
  Future<T?> getJsonStale<T>(String key) async {
    return getJson<T>(key, ttlMinutes: null);
  }

  /// Remove arquivos antigos e limita o número total.
  ///
  /// Defaults conservadores: 30 dias e 900 arquivos.
  Future<void> prune({int maxAgeDays = 30, int maxFiles = 900}) async {
    final now = DateTime.now();
    if (_lastPrune != null && now.difference(_lastPrune!).inHours < 12) return;
    _lastPrune = now;

    final dir = await _baseDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    // Apaga muito antigos.
    final cutoff = now.subtract(Duration(days: maxAgeDays));
    for (final f in files) {
      try {
        final stat = f.statSync();
        if (stat.modified.isBefore(cutoff)) {
          f.deleteSync();
        }
      } catch (_) {}
    }

    // Recalcula e limita quantidade.
    final remaining = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    if (remaining.length <= maxFiles) return;

    remaining.sort((a, b) {
      try {
        return a.statSync().modified.compareTo(b.statSync().modified);
      } catch (_) {
        return 0;
      }
    });

    final toDelete = remaining.take(remaining.length - maxFiles);
    for (final f in toDelete) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }
}
