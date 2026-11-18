import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'auth/necsoura_password.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'password.dart';

class ApiError implements Exception {
  final String message, code;
  final int status;
  const ApiError(this.message, {this.code = '', this.status = 0});
  @override
  String toString() => message;
}

/// A second window's link to the window that owns the session: tokens are
/// stored and refreshed in one place, otherwise the windows would invalidate
/// each other's refresh tokens.
class SessionOwner {
  final Future<String?> Function() renew;
  final Future<void> Function(Map<String, dynamic> session) apply;
  final Future<void> Function() logout;
  final Future<void> Function() profileChanged;
  const SessionOwner(
      {required this.renew,
      required this.apply,
      required this.logout,
      required this.profileChanged});
}

class PixelApi extends ChangeNotifier {
  static const defaultApi = String.fromEnvironment('KEEP_PIXEL_API_URL',
      defaultValue: 'https://keeppixel.necsoura.ru');
  static const defaultAuth = String.fromEnvironment('NECSOURA_AUTH_URL',
      defaultValue: 'https://necsoura.ru/api/auth');
  static const defaultProfile = String.fromEnvironment('NECSOURA_PROFILE_URL',
      defaultValue: 'https://kompot.necsoura.ru/api');
  String apiUrl, authUrl;
  int profileRevision = 0;
  String _device = '';
  int sessionGeneration = 0;
  bool get persistentSession => canPersistSession;
  final http.Client client;
  final FlutterSecureStorage storage;
  final SessionOwner? owner;
  String? _token, _refresh, _pending2fa;
  Future<void>? _refreshing;
  bool ready = false;
  String? startupError;
  PixelApi(
      {this.apiUrl = defaultApi,
      this.authUrl = defaultAuth,
      http.Client? client,
      this.storage = const FlutterSecureStorage(),
      this.owner})
      : client = client ?? http.Client();
  String get accountSite {
    final u = Uri.parse(authUrl);
    return Uri(
            scheme: u.scheme,
            host: u.host,
            port: u.port == 3001 ? null : (u.hasPort ? u.port : null))
        .origin;
  }

  bool get signedIn => _token != null;
  String? get sessionToken => _token;

  /// How this client introduces itself; the account's session list shows it.
  Map<String, String> get deviceHeaders {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    return {
      'x-app-service': 'keeppixel',
      'platform': platform,
      'device-name': 'Keep Pixel ($platform)',
      'device-type': kIsWeb
          ? 'web'
          : const {TargetPlatform.android, TargetPlatform.iOS}
                  .contains(defaultTargetPlatform)
              ? 'mobile'
              : 'desktop',
      if (_device.isNotEmpty) 'device-fingerprint': _device,
    };
  }

  void profileChanged() {
    profileRevision++;
    notifyListeners();
    owner?.profileChanged();
  }

  /// In a second window: takes over what the owner of the session reports.
  void adoptSession(
      {required String? token,
      required String apiUrl,
      required String authUrl,
      required String device}) {
    if ((token == null) != (_token == null) ||
        apiUrl != this.apiUrl ||
        authUrl != this.authUrl) {
      sessionGeneration++;
    }
    _token = token;
    this.apiUrl = apiUrl;
    this.authUrl = authUrl;
    _device = device;
    ready = true;
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _device = prefs.getString('keep_pixel_device') ?? '';
      if (_device.isEmpty) {
        final random = Random.secure();
        _device = List.generate(16,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
        await prefs.setString('keep_pixel_device', _device);
      }
      await prefs.remove('keep_pixel_api_url');
      await prefs.remove('keep_pixel_auth_url');
      final saved = canPersistSession
          ? await storage.read(key: 'keep_pixel_session_v2')
          : null;
      if (saved != null) {
        final j = jsonDecode(saved) as Map;
        if (j['apiUrl'] != apiUrl || j['authUrl'] != authUrl) {
          await storage.delete(key: 'keep_pixel_session_v2');
        } else {
          _token = j['token'] as String?;
          _refresh = j['refreshToken'] as String?;
        }
      }
      final cached = _token == null ? null : prefs.getString(_profileKey);
      if (cached != null) {
        cachedProfile = PixelProfile.fromJson(
            Map<String, dynamic>.from(jsonDecode(cached) as Map));
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
    final generation = sessionGeneration;
    final request = http.Request(
        method, Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/$path'));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...deviceHeaders
    });
    if (authenticated) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(
              await client.send(request).timeout(const Duration(seconds: 20)))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiError(
          'Сервер ${request.url.host}:${request.url.port} долго не отвечает. Проверьте адрес и доступность Docker.');
    } on http.ClientException {
      throw ApiError(
          'Нет соединения с ${request.url.scheme}://${request.url.authority}. Проверьте адрес сервера, порт и Docker.');
    }
    if (generation != sessionGeneration) {
      throw const ApiError('Сервер или сеанс изменён. Повторите действие.');
    }
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiError(
          '${request.url.host}:${request.url.port} вернул ${response.statusCode} вместо API JSON. Проверьте адрес и маршрут сервиса.',
          status: response.statusCode);
    }
    if (response.statusCode == 401 &&
        authenticated &&
        retry &&
        (_refresh != null || owner != null)) {
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
    final generation = sessionGeneration;
    if (j['token'] is! String || (j['token'] as String).isEmpty) {
      throw const ApiError('Сервер не выдал сеанс');
    }
    if (owner != null) {
      await owner!.apply(j);
      _token = j['token'] as String;
      notifyListeners();
      return;
    }
    final token = j['token'] as String,
        refresh = j['refreshToken'] as String? ?? _refresh;
    if (canPersistSession) {
      await storage.write(
          key: 'keep_pixel_session_v2',
          value: jsonEncode({
            'token': token,
            'refreshToken': refresh,
            'apiUrl': apiUrl,
            'authUrl': authUrl
          }));
    }
    if (generation != sessionGeneration) {
      throw const ApiError('Сервер или сеанс изменён');
    }
    _token = token;
    _refresh = refresh;
    notifyListeners();
  }

  Future<void> applySession(Map<String, dynamic> payload) => _save(payload);
  Future<bool> refreshSession() async {
    if (_refresh == null && owner == null) return false;
    try {
      await (_refreshing ??= _renew().whenComplete(() => _refreshing = null));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _renew() async {
    if (owner != null) {
      final token = await owner!.renew();
      if (token == null) {
        await _clear();
        throw const ApiError('Войдите в Necsoura', status: 401);
      }
      _token = token;
      return;
    }
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

  Future<void> register(String login, String email, String password) async {
    final kdf = NecsouraPassword.newKdf();
    final keys = await NecsouraPassword.derive(password, kdf);
    await _save(Map<String, dynamic>.from(
        await _call(authUrl, 'register', method: 'POST', body: {
      'login': login.trim(),
      'email': email.trim(),
      'authKey': keys.authKeyBase64,
      'kdf': kdf,
      'gameNickname': login.trim()
    })));
  }

  // After a social sign-in the shared screens hand over the pending 2FA token.
  set pendingTwoFactor(String token) => _pending2fa = token;

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

  /// Where the auth service keeps two-step verification of the Necsoura
  /// account, relative to [authUrl]. Same requests and answers as Kompot's
  /// users/2fa routes.
  static const twoFactorPath = '2fa';

  Future<({bool enabled, bool backupCodes, int? backupLeft})>
      twoFactorStatus() async {
    final r = Map<String, dynamic>.from(
        await _call(authUrl, '$twoFactorPath/status', authenticated: true)
            as Map);
    bool flag(Object? v) => v == true || v == 1;
    final left = r['backupCodesLeft'];
    return (
      enabled: flag(r['isEnabled']),
      backupCodes: flag(r['backupCodesGenerated']),
      backupLeft: left is num ? left.toInt() : null
    );
  }

  /// A new secret, not active until [twoFactorVerify] accepts a code.
  Future<({String secret, String? otpauth, String? qrImage})>
      twoFactorSetup() async {
    final r = Map<String, dynamic>.from(await _call(
        authUrl, '$twoFactorPath/setup',
        method: 'POST', body: {}, authenticated: true) as Map);
    final otpauth = r['otpauthUrl'] ?? r['otpauth_url'] ?? r['otpauth'];
    final image = r['qrCodeData'];
    return (
      secret: '${r['secret'] ?? ''}',
      otpauth: otpauth is String && otpauth.startsWith('otpauth://')
          ? otpauth
          : image is String && image.startsWith('otpauth://')
              ? image
              : null,
      qrImage: image is String && image.startsWith('data:image/') ? image : null
    );
  }

  /// Turns verification on; the answer brings the first backup codes.
  Future<List<String>> twoFactorVerify(String code) async {
    final r = await _call(authUrl, '$twoFactorPath/verify',
        method: 'POST', body: {'code': code.trim()}, authenticated: true);
    return _codes(r);
  }

  /// Needs a code from the app or a backup code.
  Future<void> twoFactorDisable(String code) =>
      _call(authUrl, '$twoFactorPath/disable',
          method: 'POST', body: {'code': code.trim()}, authenticated: true);

  /// New backup codes for a code from the app; the old ones stop working.
  Future<List<String>> twoFactorBackupCodes(String code) async =>
      _codes(await _call(authUrl, '$twoFactorPath/backup-codes',
          method: 'POST', body: {'code': code.trim()}, authenticated: true));

  List<String> _codes(Object? r) => r is Map && r['backupCodes'] is List
      ? [for (final c in r['backupCodes'] as List) '$c']
      : const [];

  Future<void> _clear() async {
    sessionGeneration++;
    unawaited(_forgetProfile());
    _token = null;
    _refresh = null;
    _pending2fa = null;
    notifyListeners();
    if (owner == null && canPersistSession) {
      await storage.delete(key: 'keep_pixel_session_v2');
    }
  }

  Future<void> logout() async {
    if (owner != null) {
      await owner!.logout();
      await _clear();
      return;
    }
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

  Future<List<Game>> games(
          {String query = '',
          int offset = 0,
          String filter = 'all',
          String sort = 'newest'}) async =>
      (await _call(
              apiUrl,
              'games?${Uri(queryParameters: {
                    'q': query,
                    'limit': '40',
                    'offset': '$offset',
                    'filter': filter,
                    'sort': sort
                  }).query}') as List)
          .map((j) => Game.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  Future<Game> game(String id) async => Game.fromJson(
      Map<String, dynamic>.from(await _call(apiUrl, 'games/$id')));
  Future<Map<String, dynamic>> buildManifest(String id) async =>
      Map<String, dynamic>.from(
          await _call(apiUrl, 'games/$id/download', authenticated: true));
  Future<List<Game>> library() async =>
      (await _call(apiUrl, 'library', authenticated: true) as List)
          .map((j) => Game.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  Future<void> claim(String id) async => _call(apiUrl, 'library/$id',
      method: 'POST', body: {}, authenticated: true);

  /// The last profile seen, shown at once while a fresh copy loads. It stays
  /// on this device only and is wiped when the player signs out.
  PixelProfile? cachedProfile;
  static const _profileKey = 'keep_pixel_profile_cache';

  Future<PixelProfile> profile() async {
    final generation = sessionGeneration;
    final j = Map<String, dynamic>.from(
        await _call(apiUrl, 'me', authenticated: true));
    final p = PixelProfile.fromJson(j);
    if (generation == sessionGeneration) {
      cachedProfile = p;
      try {
        await (await SharedPreferences.getInstance())
            .setString(_profileKey, jsonEncode(j));
      } catch (_) {
        // Only the quick start is lost.
      }
    }
    return p;
  }

  Future<void> _forgetProfile() async {
    final old = cachedProfile;
    cachedProfile = null;
    for (final url in [old?.fields['avatar'], old?.fields['banner']]) {
      if (url != null && url.isNotEmpty) {
        unawaited(
            CachedNetworkImage.evictFromCache(url).catchError((_) => false));
      }
    }
    try {
      await (await SharedPreferences.getInstance()).remove(_profileKey);
    } catch (_) {}
  }

  Future<PixelProfile> publicProfile(String id) async =>
      PixelProfile.fromJson(Map<String, dynamic>.from(
          await _call(apiUrl, 'people/$id', authenticated: true)));

  /// Stores a picture for a Keep Pixel profile override in the shared uploads,
  /// which does not touch the Kompot profile itself.
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    Future<http.Response> send() async {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$defaultProfile/files/upload'))
        ..headers.addAll({...deviceHeaders, 'Authorization': 'Bearer $_token'})
        ..fields['type'] = 'image'
        ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename));
      return http.Response.fromStream(await client.send(request));
    }

    var response = await send();
    if (response.statusCode == 401 && await refreshSession()) {
      response = await send();
    }
    final data = response.statusCode == 200
        ? jsonDecode(utf8.decode(response.bodyBytes))
        : null;
    final record = data is Map ? data['fileRecord'] : null;
    final name = record is Map
        ? record['fileName'] ?? record['file_name'] ?? record['filename']
        : null;
    if (name is! String || name.isEmpty) {
      throw const ApiError('Не удалось загрузить картинку');
    }
    return '${Uri.parse(apiUrl).origin}/uploads/$name';
  }

  Future<PixelProfile> updateProfile(Map<String, dynamic> patch) async =>
      PixelProfile.fromJson(Map<String, dynamic>.from(await _call(apiUrl, 'me',
          method: 'PATCH', body: {'overrides': patch}, authenticated: true)));
  static String normalizeEndpoint(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ApiError(
          'Укажите HTTP/HTTPS-адрес без логина, пароля и параметров');
    }
    return uri.toString().replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> setEndpoints(String api, String auth) async {
    final nextApi = normalizeEndpoint(api), nextAuth = normalizeEndpoint(auth);
    if (nextApi == apiUrl && nextAuth == authUrl) return;
    await _clear();
    apiUrl = nextApi;
    authUrl = nextAuth;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('keep_pixel_api_url', apiUrl);
    await prefs.setString('keep_pixel_auth_url', authUrl);
    startupError = null;
    notifyListeners();
  }

  Future<String> checkConnection() async {
    final health = await _call(apiUrl, 'health');
    if (health is! Map || health['status'] != 'ok') {
      throw const ApiError('По этому адресу отвечает другой сервис');
    }
    final pre = await _call(authUrl, 'prelogin',
        method: 'POST', body: {'login': 'keep_pixel_connection_check'});
    if (pre is! Map || ![1, 2].contains(pre['scheme'])) {
      throw const ApiError(
          'Адрес аккаунтов не соответствует Necsoura Auth API');
    }
    return 'Магазин и аккаунты доступны';
  }

  Future<List<PixelFriend>> friends({String section = ''}) async =>
      (await _call(apiUrl, 'friends${section.isEmpty ? '' : '/$section'}',
              authenticated: true) as List)
          .map((x) => PixelFriend.fromJson(Map<String, dynamic>.from(x)))
          .toList();
  Future<List<PixelFriend>> searchPeople(String query) async =>
      (await _call(apiUrl, 'people?${Uri(queryParameters: {'q': query}).query}',
              authenticated: true) as List)
          .map((x) => PixelFriend.fromJson(Map<String, dynamic>.from(x)))
          .toList();
  Future<void> requestFriend(String userId) async =>
      _call(apiUrl, 'friends/requests',
          method: 'POST', body: {'friend_id': userId}, authenticated: true);
  Future<void> friendAction(PixelFriend friend, String action) async {
    final target =
        ['accept', 'reject'].contains(action) ? friend.relationId : friend.id;
    await _call(
        apiUrl, 'friends/$target${action == 'remove' ? '' : '/$action'}',
        method: action == 'remove' ? 'DELETE' : 'POST',
        body: {},
        authenticated: true);
  }

  Future<bool> checkLicense(String gameId) async =>
      (await _call(apiUrl, 'license/check',
          method: 'POST',
          body: {'game_id': gameId},
          authenticated: true) as Map)['success'] ==
      true;

  Future<void> presence({String status = 'online', String? gameId}) async =>
      _call(apiUrl, 'me/presence',
          method: 'POST',
          body: {'status': status, 'game_id': gameId},
          authenticated: true);
  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
