import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'password.dart';

class ApiError implements Exception {
  final String message, code;
  final int status;
  const ApiError(this.message, {this.code = '', this.status = 0});
  @override
  String toString() => message;
}

class PixelApi extends ChangeNotifier {
  static const defaultApi = String.fromEnvironment('KEEP_PIXEL_API_URL',
      defaultValue: 'https://necsoura.ru/api/keeppixel');
  static const defaultAuth = String.fromEnvironment('NECSOURA_AUTH_URL',
      defaultValue: 'https://auth.keep-pixel.ru/api/auth');
  final String apiUrl, authUrl;
  final http.Client client;
  final FlutterSecureStorage storage;
  String? _token, _refresh, _pending2fa;
  Future<void>? _refreshing;
  bool ready = false;
  String? startupError;
  PixelApi(
      {this.apiUrl = defaultApi,
      this.authUrl = defaultAuth,
      http.Client? client,
      this.storage = const FlutterSecureStorage()})
      : client = client ?? http.Client();
  bool get signedIn => _token != null;
  Future<void> initialize() async {
    try {
      final saved = await storage.read(key: 'keep_pixel_session_v2');
      if (saved != null) {
        final j = jsonDecode(saved) as Map;
        _token = j['token'] as String?;
        _refresh = j['refreshToken'] as String?;
      }
    } catch (_) {
      startupError = 'Не удалось открыть сохранённый сеанс. Войдите снова.';
    }
    ready = true;
    notifyListeners();
  }

  Future<dynamic> _call(String base, String path,
      {String method = 'GET',
      Map<String, dynamic>? body,
      bool authenticated = false,
      bool retry = true}) async {
    if (authenticated && _token == null) {
      throw const ApiError('Войдите в Necsoura', status: 401);
    }
    final request = http.Request(
        method, Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/$path'));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-app-service': 'keeppixel',
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name
    });
    if (authenticated) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(
              await client.send(request).timeout(const Duration(seconds: 20)))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiError('Сервер долго не отвечает. Попробуйте ещё раз.');
    } on http.ClientException {
      throw const ApiError('Нет соединения с сервером. Проверьте интернет.');
    }
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiError(
          'Сервер вернул некорректный ответ (${response.statusCode})',
          status: response.statusCode);
    }
    if (response.statusCode == 401 &&
        authenticated &&
        retry &&
        _refresh != null) {
      await (_refreshing ??= _renew().whenComplete(() => _refreshing = null));
      return _call(base, path,
          method: method, body: body, authenticated: true, retry: false);
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && authenticated) await _clear();
      final j = data is Map ? data : {};
      const messages = {
        'invalid_credentials': 'Неверный логин или пароль',
        'invalid_code': 'Неверный код подтверждения',
        'too_many_attempts': 'Слишком много попыток. Повторите позже',
        'session_revoked': 'Сеанс завершён. Войдите снова'
      };
      throw ApiError(
          messages[j['code']] ?? '${j['message'] ?? 'Ошибка сервера'}',
          code: '${j['code'] ?? ''}',
          status: response.statusCode);
    }
    return data;
  }

  Future<void> _save(Map<String, dynamic> j) async {
    if (j['token'] is! String || (j['token'] as String).isEmpty) {
      throw const ApiError('Сервер не выдал сеанс');
    }
    final token = j['token'] as String,
        refresh = j['refreshToken'] as String? ?? _refresh;
    await storage.write(
        key: 'keep_pixel_session_v2',
        value: jsonEncode({'token': token, 'refreshToken': refresh}));
    _token = token;
    _refresh = refresh;
    notifyListeners();
  }

  Future<void> _renew() async {
    try {
      await _save(Map<String, dynamic>.from(await _call(authUrl, 'refresh',
          method: 'POST', body: {'refreshToken': _refresh})));
    } on ApiError catch (e) {
      if (e.status == 401 || e.status == 403) await _clear();
      rethrow;
    }
  }

  Future<bool> login(String login, String password) async {
    final pre = await _call(authUrl, 'prelogin',
        method: 'POST', body: {'login': login.trim()}) as Map;
    final body = <String, dynamic>{'login': login.trim()};
    if (pre['scheme'] == 2) {
      body['authKey'] = await compute(
          deriveAuthKey, {'password': password, 'kdf': pre['kdf']});
    } else {
      body['password'] = password;
    }
    final result = Map<String, dynamic>.from(
        await _call(authUrl, 'login', method: 'POST', body: body));
    if (result['requires2FA'] == true) {
      _pending2fa = result['twoFactorToken'] as String;
      return false;
    }
    await _save(result);
    return true;
  }

  Future<void> confirm2fa(String code, {bool backup = false}) async {
    if (_pending2fa == null) throw const ApiError('Войдите заново');
    final result = await _call(
        authUrl, backup ? 'login/backup-code' : 'login/2fa',
        method: 'POST',
        body: {
          'twoFactorToken': _pending2fa,
          backup ? 'backupCode' : 'code': code.trim()
        });
    await _save(Map<String, dynamic>.from(result));
    _pending2fa = null;
  }

  Future<void> _clear() async {
    _token = null;
    _refresh = null;
    _pending2fa = null;
    notifyListeners();
    await storage.delete(key: 'keep_pixel_session_v2');
  }

  Future<void> logout() async {
    if (_token != null) {
      try {
        await _call(authUrl, 'logout',
            method: 'POST', body: {}, authenticated: true);
      } on ApiError {
        /* Always allow local logout; other sessions remain managed at Necsoura. */
      }
    }
    await _clear();
  }

  Future<List<Game>> games({String query = '', int offset = 0}) async =>
      (await _call(
              apiUrl,
              'games?${Uri(queryParameters: {
                    'q': query,
                    'limit': '40',
                    'offset': '$offset'
                  }).query}') as List)
          .map((j) => Game.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  Future<Game> game(int id) async => Game.fromJson(
      Map<String, dynamic>.from(await _call(apiUrl, 'games/$id')));
  Future<Map<String, dynamic>> buildManifest(int id) async =>
      Map<String, dynamic>.from(
          await _call(apiUrl, 'games/$id/download', authenticated: true));
  Future<List<Game>> library() async =>
      (await _call(apiUrl, 'library', authenticated: true) as List)
          .map((j) => Game.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  Future<void> claim(int id) async => _call(apiUrl, 'library/$id',
      method: 'POST', body: {}, authenticated: true);
  Future<PixelProfile> profile() async =>
      PixelProfile.fromJson(Map<String, dynamic>.from(
          await _call(apiUrl, 'me', authenticated: true)));
  Future<PixelProfile> updateProfile(Map<String, dynamic> patch) async =>
      PixelProfile.fromJson(Map<String, dynamic>.from(await _call(apiUrl, 'me',
          method: 'PATCH', body: {'overrides': patch}, authenticated: true)));
  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
