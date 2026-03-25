
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class SpotifyAuthRepository {
  static const _kStorage = FlutterSecureStorage();
  static const _kAccessKey = 'sp_access_token';
  static const _kRefreshKey = 'sp_refresh_token';
  static const _kExpiryKey = 'sp_expires_at';
  static const _kVerifierKey = 'sp_code_verifier';

  String get clientId => dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  String get redirectUri => dotenv.env['SPOTIFY_REDIRECT_URI'] ?? 'contadorplus://auth/callback';
  String get scopes => dotenv.env['SPOTIFY_SCOPES'] ?? 'user-read-email';

  Uri get _authUri {
    final verifier = _randomString(64);
    final challenge = _sha256Base64Url(verifier);
    // Save verifier for later exchange
    _kStorage.write(key: _kVerifierKey, value: verifier);

    final params = {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': scopes,
    };
    return Uri.https('accounts.spotify.com', '/authorize', params);
  }

  Future<bool> isLoggedIn() async {
    final token = await _kStorage.read(key: _kAccessKey);
    if (token == null) return false;
    final expStr = await _kStorage.read(key: _kExpiryKey);
    if (expStr == null) return false;
    final exp = DateTime.tryParse(expStr);
    if (exp == null) return false;
    if (DateTime.now().isAfter(exp)) {
      // try refresh
      return await _refreshToken();
    }
    return true;
  }

  Future<String?> getValidAccessToken() async {
    final ok = await isLoggedIn();
    if (!ok) return null;
    final expStr = await _kStorage.read(key: _kExpiryKey);
    final exp = DateTime.parse(expStr!);
    if (DateTime.now().isAfter(exp.subtract(const Duration(seconds: 30)))) {
      final refreshed = await _refreshToken();
      if (!refreshed) return null;
    }
    return await _kStorage.read(key: _kAccessKey);
  }

  Future<bool> login() async {
    if (clientId.isEmpty) {
      throw 'SPOTIFY_CLIENT_ID ausente no .env';
    }
    if (redirectUri.isEmpty) {
      throw 'SPOTIFY_REDIRECT_URI ausente no .env';
    }

    final callbackScheme = Uri.parse(redirectUri).scheme;
    final result = await FlutterWebAuth2.authenticate(
      url: _authUri.toString(),
      callbackUrlScheme: callbackScheme,
    );

    final returned = Uri.parse(result);
    final code = returned.queryParameters['code'];
    if (code == null) return false;

    final verifier = await _kStorage.read(key: _kVerifierKey);
    if (verifier == null) return false;

    final body = {
      'client_id': clientId,
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'code_verifier': verifier,
    };

    final resp = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (resp.statusCode != 200) {
      return false;
    }

    final map = json.decode(resp.body) as Map<String, dynamic>;
    final access = map['access_token'] as String;
    final refresh = map['refresh_token'] as String?;
    final expiresIn = map['expires_in'] as int? ?? 3600;
    final expAt = DateTime.now().add(Duration(seconds: expiresIn));

    await _kStorage.write(key: _kAccessKey, value: access);
    if (refresh != null) {
      await _kStorage.write(key: _kRefreshKey, value: refresh);
    }
    await _kStorage.write(key: _kExpiryKey, value: expAt.toIso8601String());
    return true;
  }

  Future<void> logout() async {
    await _kStorage.delete(key: _kAccessKey);
    await _kStorage.delete(key: _kRefreshKey);
    await _kStorage.delete(key: _kExpiryKey);
    await _kStorage.delete(key: _kVerifierKey);
  }

  Future<bool> _refreshToken() async {
    final refresh = await _kStorage.read(key: _kRefreshKey);
    if (refresh == null || refresh.isEmpty) return false;

    final body = {
      'client_id': clientId,
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
    };

    final resp = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (resp.statusCode != 200) {
      return false;
    }

    final map = json.decode(resp.body) as Map<String, dynamic>;
    final access = map['access_token'] as String;
    final expiresIn = map['expires_in'] as int? ?? 3600;
    final expAt = DateTime.now().add(Duration(seconds: expiresIn));

    await _kStorage.write(key: _kAccessKey, value: access);
    await _kStorage.write(key: _kExpiryKey, value: expAt.toIso8601String());
    final newRefresh = map['refresh_token'] as String?;
    if (newRefresh != null && newRefresh.isNotEmpty) {
      await _kStorage.write(key: _kRefreshKey, value: newRefresh);
    }
    return true;
  }

  // Utilities
  static String _randomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  static String _sha256Base64Url(String input) {
    final digest = crypto.sha256.convert(utf8.encode(input));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
