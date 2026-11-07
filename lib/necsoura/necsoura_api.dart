import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import '../core/auth/necsoura_password.dart';

/// Ошибка запроса к аккаунту Necsoura: текст уже для человека
class NecsouraException implements Exception {
  final String message;
  final String? code;
  NecsouraException(this.message, {this.code});
  @override
  String toString() => message;
}

/// Профиль Necsoura: имя и фото — из Kompot (общие для всех сервисов), логин и почта — из аккаунта
class NecsouraProfile {
  final String globalId;
  final String login;
  final String? email;
  final bool emailVerified;
  final String? name;
  final String? username;
  final String? avatarUrl;
  /// Шапка профиля (картинка над фото) — из Kompot
  final String? backgroundUrl;
  /// Публичный номер аккаунта: у кого нет username, тех находят и видят как @id12
  final int? publicId;

  const NecsouraProfile({
    required this.globalId,
    required this.login,
    this.email,
    this.emailVerified = false,
    this.name,
    this.username,
    this.avatarUrl,
    this.backgroundUrl,
    this.publicId,
  });

  /// Публичный адрес: @username, а если его нет — @id12. Логин не показываем: его знает только владелец
  String get handle => username != null ? '@$username' : (publicId != null ? '@id$publicId' : '');

  /// Что показывать: имя, а если его нет — публичный адрес
  String get displayName {
    if (name?.trim().isNotEmpty ?? false) return name!.trim();
    if (username != null) return username!;
    return publicId != null ? 'id$publicId' : login;
  }

  factory NecsouraProfile.fromKompot(Map<String, dynamic> j) {
    String? str(String k) {
      final v = j[k]?.toString().trim();
      return v == null || v.isEmpty || v == 'null' || v == '0' ? null : v;
    }

    return NecsouraProfile(
      globalId: j['globalId']?.toString() ?? '',
      login: j['login']?.toString() ?? '',
      email: str('email'),
      emailVerified: j['emailVerified'] == true || j['emailVerified'] == 1,
      name: str('kompotName'),
      username: str('kompotUsername'),
      avatarUrl: str('kompotImg'),
      backgroundUrl: str('kompotBackground'),
      publicId: int.tryParse(j['publicId']?.toString() ?? ''),
    );
  }

  NecsouraProfile copyWith({String? name, String? username, String? avatarUrl, bool clearAvatar = false, String? email}) => NecsouraProfile(
        globalId: globalId,
        login: login,
        email: email ?? this.email,
        emailVerified: email != null ? false : emailVerified,
        name: name ?? this.name,
        username: username ?? this.username,
        avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
        backgroundUrl: backgroundUrl,
        publicId: publicId,
      );

  Map<String, dynamic> toJson() => {
        'globalId': globalId,
        'login': login,
        'email': email,
        'emailVerified': emailVerified,
        'kompotName': name,
        'kompotUsername': username,
        'kompotImg': avatarUrl,
        'kompotBackground': backgroundUrl,
        'publicId': publicId,
      };
}

/// Сеанс входа (устройство) из auth-service
class NecsouraSession {
  final String id;
  final bool current;
  final String service;
  final String platform;
  final String deviceName;
  final String deviceType;
  final String? ip;
  final String? location;
  final String? loginMethod;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;

  NecsouraSession.fromJson(Map<String, dynamic> j)
      : id = j['sessionId']?.toString() ?? '',
        current = j['current'] == true,
        service = j['service']?.toString() ?? '',
        platform = j['platform']?.toString() ?? '',
        deviceName = Uri.decodeComponent(j['deviceName']?.toString() ?? ''),
        deviceType = j['deviceType']?.toString() ?? '',
        ip = j['ip']?.toString(),
        location = j['location']?.toString(),
        loginMethod = j['loginMethod']?.toString(),
        createdAt = DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal(),
        lastActiveAt = DateTime.tryParse(j['lastActiveAt']?.toString() ?? '')?.toLocal();
}

/// Кто просит вход по QR (ответ /qr/scan)
class NecsouraQrRequest {
  final String sessionId;
  final String service;
  final String platform;
  final String deviceName;
  final String? ip;
  final String? ephemeralPublicKey;

  NecsouraQrRequest(this.sessionId, Map<String, dynamic> device, this.ephemeralPublicKey)
      : service = device['service']?.toString() ?? '',
        platform = device['platform']?.toString() ?? '',
        deviceName = Uri.decodeComponent(device['deviceName']?.toString() ?? ''),
        ip = device['ip']?.toString();
}

/// Код для входа по QR на новом устройстве
class NecsouraQrTicket {
  final String sessionId;
  final String pollToken;
  final Duration expiresIn;
  final String? _data;
  NecsouraQrTicket(this.sessionId, this.pollToken, this.expiresIn, {String? data}) : _data = data;

  /// Общий формат QR всей экосистемы: его понимают сканеры blast!, Kompot и других приложений
  String get qrData => _data ?? '${NecsouraQr.prefix}$sessionId';
}

class NecsouraQr {
  static const prefix = 'necsoura-login:v1:';

  /// sessionId из любого QR входа: necsoura-login:v1:<id>[:<ключ>] или старый blast://login/<id>
  static ({String sessionId, String? key})? parse(String raw) {
    final data = raw.trim();
    if (data.startsWith(prefix)) {
      final parts = data.substring(prefix.length).split(':');
      if (parts.first.isEmpty) return null;
      return (sessionId: parts.first, key: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null);
    }
    final legacy = RegExp(r'^blast://login/([A-Za-z0-9_-]+)$').firstMatch(data);
    if (legacy != null) return (sessionId: legacy.group(1)!, key: null);
    return null;
  }
}

/// Запросы к аккаунту Necsoura (auth-service) и общему профилю (Kompot API).
/// Токен, его обновление и заголовки устройства даёт приложение.
class NecsouraApi {
  /// …/api/auth
  final String authBase;
  /// …/api (Kompot)
  final String profileBase;
  final Future<String?> Function() token;
  final Future<bool> Function() refresh;
  final Future<Map<String, String>> Function() deviceHeaders;

  NecsouraApi({
    required this.authBase,
    required this.profileBase,
    required this.token,
    required this.refresh,
    required this.deviceHeaders,
  });

  static const _timeout = Duration(seconds: 20);

  Future<(int, dynamic)> _send(String method, Uri uri, {Object? body, bool auth = true}) async {
    Future<http.Response> run(String? t) async {
      final headers = {
        ...await deviceHeaders(),
        'Content-Type': 'application/json',
        if (t != null) 'Authorization': 'Bearer $t',
      };
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      return http.Response.fromStream(await req.send().timeout(_timeout));
    }

    http.Response r;
    try {
      String? t = auth ? await token() : null;
      if (auth && (t == null || t.isEmpty)) throw NecsouraException('Войдите в аккаунт', code: 'no_session');
      r = await run(t);
      if (auth && r.statusCode == 401 && await refresh()) r = await run(await token());
    } on NecsouraException {
      rethrow;
    } on TimeoutException {
      throw NecsouraException('Сервер не отвечает. Проверьте интернет');
    } catch (_) {
      throw NecsouraException('Нет соединения с сервером');
    }
    dynamic data;
    try {
      data = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    return (r.statusCode, data);
  }

  Never _fail(int status, dynamic data, String fallback) {
    final code = data is Map ? (data['code'] ?? data['error'])?.toString() : null;
    const texts = {
      'invalid_old_password': 'Неверный текущий пароль',
      'invalid_password': 'Неверный пароль',
      'too_many_attempts': 'Слишком много попыток. Попробуйте позже',
      'email_in_use': 'Эта почта уже занята',
      'invalid_email': 'Неверный формат почты',
      'session_too_new': 'Завершать другие сеансы можно через 24 часа после входа на этом устройстве',
      'reauth_required': 'Войдите заново',
      'name_too_short': 'Имя — минимум 2 символа',
      'matches_login': 'Имя и username не должны совпадать с логином: он приватный',
      'too_large': 'Файл слишком большой (до 10 МБ)',
      'bad_file': 'Нужна картинка JPEG, PNG, WebP или GIF',
      'heic': 'Это фото в формате HEIC — выберите другое или снимок экрана',
      'bad_username': 'Username: 3–30 латинских букв, цифр или _',
      'reserved_username': 'Такой username занят под адреса @id — выберите другой',
      'username_taken': 'Этот username уже занят',
    };
    throw NecsouraException(texts[code] ?? (status == 404 && fallback.contains('QR') ? 'QR-код устарел' : fallback), code: code);
  }

  // ── Профиль ──

  Future<NecsouraProfile> profile() async {
    final (s, d) = await _send('GET', Uri.parse('$profileBase/users/profile'));
    if (s != 200 || d is! Map) _fail(s, d, 'Не удалось загрузить профиль');
    return NecsouraProfile.fromKompot(Map<String, dynamic>.from(d));
  }

  Future<void> setName(String name) async {
    final (s, d) = await _send('PUT', Uri.parse('$profileBase/users/profile/kompot'), body: {'kompotName': name.trim()});
    if (s != 200) _fail(s, d, 'Не удалось сохранить имя');
  }

  /// Публичный @username (без @). Логин при этом остаётся приватным
  Future<void> setUsername(String username) async {
    final (s, d) = await _send('PUT', Uri.parse('$profileBase/users/profile/kompot'), body: {'kompotUsername': username.trim().replaceFirst('@', '')});
    if (s != 200) _fail(s, d, 'Не удалось сохранить username');
  }

  /// Новое фото профиля; возвращает его адрес
  Future<String> uploadAvatar(Uint8List bytes, String filename) async {
    (bytes, filename) = await _uploadable(bytes, filename);
    Future<http.Response> run(String? t) async {
      final req = http.MultipartRequest('POST', Uri.parse('$profileBase/users/profile/avatar'))
        ..headers.addAll({...await deviceHeaders(), if (t != null) 'Authorization': 'Bearer $t'})
        ..files.add(http.MultipartFile.fromBytes('avatar', bytes, filename: filename));
      return http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
    }

    http.Response r;
    try {
      r = await run(await token());
      if (r.statusCode == 401 && await refresh()) r = await run(await token());
    } catch (_) {
      throw NecsouraException('Не удалось загрузить фото');
    }
    dynamic d;
    try {
      d = jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode != 200 || d is! Map || d['avatarUrl'] == null) _fail(r.statusCode, d, 'Не удалось загрузить фото');
    return d['avatarUrl'].toString();
  }

  static bool _isHeic(Uint8List b) =>
      b.length > 12 &&
      String.fromCharCodes(b.sublist(4, 8)) == 'ftyp' &&
      const {'heic', 'heix', 'hevc', 'heim', 'heis', 'mif1', 'msf1'}.contains(String.fromCharCodes(b.sublist(8, 12)));

  /// Фото с iPhone бывает в HEIC — браузеры и Android его не покажут. Переводим в PNG
  /// системным декодером (на iOS и macOS он умеет HEIC), заодно уменьшаем до 1600 px
  static Future<(Uint8List, String)> _uploadable(Uint8List bytes, String filename) async {
    if (!_isHeic(bytes)) return (bytes, filename);
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = descriptor.width > 1600 ? 1600 / descriptor.width : 1.0;
      final codec = await descriptor.instantiateCodec(targetWidth: (descriptor.width * scale).round(), targetHeight: (descriptor.height * scale).round());
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (png == null) return (bytes, filename);
      final base = filename.contains('.') ? filename.substring(0, filename.lastIndexOf('.')) : filename;
      return (png.buffer.asUint8List(), '$base.png');
    } catch (_) {
      return (bytes, filename); // сервер ответит понятной ошибкой про HEIC
    }
  }

  Future<void> removeAvatar() async {
    final (s, d) = await _send('DELETE', Uri.parse('$profileBase/users/profile/avatar'));
    if (s != 200) _fail(s, d, 'Не удалось удалить фото');
  }

  Future<void> sendVerificationEmail() async {
    final (s, d) = await _send('POST', Uri.parse('$authBase/send-verification-email'), body: {});
    if (s != 200) _fail(s, d, 'Не удалось отправить письмо');
  }

  // ── Пароль и почта (на сервер уходит ключ входа, не пароль) ──

  Future<Map<String, dynamic>> _proof(String login, String password, {required String keyField, required String passwordField}) async {
    final (s, d) = await _send('POST', Uri.parse('$authBase/prelogin'), body: {'login': login}, auth: false);
    if (s != 200 || d is! Map) _fail(s, d, 'Сервер недоступен');
    if (d['scheme'] == 2) {
      final keys = await NecsouraPassword.derive(password, Map<String, dynamic>.from(d['kdf']));
      return {keyField: keys.authKeyBase64};
    }
    return {passwordField: password};
  }

  /// Смена пароля; возвращает ключ шифрования нового пароля (Kompot перешифровывает им бэкап ключей)
  Future<({PasswordKeys keys, int version})> changePassword(String login, String oldPassword, String newPassword) async {
    final body = await _proof(login, oldPassword, keyField: 'oldAuthKey', passwordField: 'oldPassword');
    final kdf = NecsouraPassword.newKdf();
    final keys = await NecsouraPassword.derive(newPassword, kdf);
    final (s, d) = await _send('POST', Uri.parse('$authBase/change-password'),
        body: {...body, 'newAuthKey': keys.authKeyBase64, 'kdf': kdf});
    if (s != 200) _fail(s, d, 'Не удалось сменить пароль');
    return (keys: keys, version: (d is Map ? (d['passwordVersion'] as num?)?.toInt() : null) ?? 1);
  }

  Future<String> changeEmail(String login, String newEmail, String password) async {
    final body = await _proof(login, password, keyField: 'authKey', passwordField: 'password');
    final (s, d) = await _send('POST', Uri.parse('$authBase/change-email'), body: {...body, 'newEmail': newEmail.trim()});
    if (s != 200) _fail(s, d, 'Не удалось сменить почту');
    return (d is Map ? d['email']?.toString() : null) ?? newEmail.trim();
  }

  // ── Сеансы ──

  Future<List<NecsouraSession>> sessions() async {
    final (s, d) = await _send('GET', Uri.parse('$authBase/sessions'));
    if (s != 200 || d is! List) _fail(s, d, 'Не удалось загрузить устройства');
    return d.whereType<Map>().map((e) => NecsouraSession.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> revokeSession(String id) async {
    final (s, d) = await _send('DELETE', Uri.parse('$authBase/sessions/${Uri.encodeComponent(id)}'));
    if (s != 200) _fail(s, d, 'Не удалось завершить сеанс');
  }

  Future<int> revokeOtherSessions() async {
    final (s, d) = await _send('POST', Uri.parse('$authBase/sessions/revoke-others'), body: {});
    if (s != 200) _fail(s, d, 'Не удалось завершить сеансы');
    return (d is Map ? (d['revoked'] as num?)?.toInt() : null) ?? 0;
  }

  // ── Вход через VK / Яндекс / Google / Apple ──

  /// Какие способы входа включены на сервере (пусто — сервер их ещё не умеет)
  Future<Set<String>> oauthProviders() async {
    try {
      final (s, d) = await _send('GET', Uri.parse('$authBase/oauth/providers'), auth: false);
      if (s != 200 || d is! Map) return {};
      return (d['providers'] as List? ?? const []).map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Вход подтверждением провайдера. Ответ: токены, либо requires2FA, либо needsRegistration
  Future<Map<String, dynamic>> oauthLogin(String provider, Map<String, dynamic> proof) async {
    final (s, d) = await _send('POST', Uri.parse('$authBase/oauth/$provider'), body: proof, auth: false);
    if ((s != 200 && s != 202) || d is! Map) _fail(s, d, 'Не удалось войти');
    return Map<String, dynamic>.from(d);
  }

  /// Новый пользователь после входа через провайдера: выбрать логин (и почту, если провайдер её не дал)
  Future<Map<String, dynamic>> oauthRegister(String provider, String registrationToken, String login, {String? email}) async {
    final (s, d) = await _send('POST', Uri.parse('$authBase/oauth/$provider/register'),
        body: {'registrationToken': registrationToken, 'login': login, if (email != null && email.isNotEmpty) 'email': email}, auth: false);
    if (s != 200 && s != 201 || d is! Map) {
      if (d is Map && d['message'] != null) throw NecsouraException(d['message'].toString(), code: d['code']?.toString());
      _fail(s, d, 'Не удалось создать аккаунт');
    }
    return Map<String, dynamic>.from(d);
  }

  /// Привязанные способы входа: ({hasPassword, available, identities})
  Future<({bool hasPassword, Set<String> available, Map<String, ({String? email, String? name})> linked})> identities() async {
    final (s, d) = await _send('GET', Uri.parse('$authBase/oauth/identities'));
    if (s != 200 || d is! Map) _fail(s, d, 'Не удалось загрузить способы входа');
    return (
      hasPassword: d['hasPassword'] != false,
      available: (d['available'] as List? ?? const []).map((e) => e.toString()).toSet(),
      linked: {
        for (final i in (d['identities'] as List? ?? const []).whereType<Map>())
          i['provider'].toString(): (email: i['email']?.toString(), name: i['name']?.toString()),
      },
    );
  }

  Future<void> linkProvider(String provider, Map<String, dynamic> proof) async {
    final (s, d) = await _send('POST', Uri.parse('$authBase/oauth/$provider/link'), body: proof);
    if (s != 200) {
      if (d is Map && d['message'] != null) throw NecsouraException(d['message'].toString(), code: d['code']?.toString());
      _fail(s, d, 'Не удалось привязать');
    }
  }

  Future<void> unlinkProvider(String provider) async {
    final (s, d) = await _send('DELETE', Uri.parse('$authBase/oauth/$provider'));
    if (s != 200) {
      if (d is Map && d['message'] != null) throw NecsouraException(d['message'].toString(), code: d['code']?.toString());
      _fail(s, d, 'Не удалось отвязать');
    }
  }

  // ── Вход по QR ──

  /// Новое устройство: получить код
  Future<NecsouraQrTicket> qrStart() async {
    final (s, d) = await _send('POST', Uri.parse('$authBase/qr/start'), body: {}, auth: false);
    if (s != 200 || d is! Map) _fail(s, d, 'Не удалось создать QR-код');
    return NecsouraQrTicket(d['sessionId'].toString(), d['pollToken'].toString(), Duration(seconds: (d['expiresIn'] as num?)?.toInt() ?? 120));
  }

  /// Новое устройство: статус кода. pending / scanned / rejected / expired / approved (+ токены)
  Future<Map<String, dynamic>> qrPoll(NecsouraQrTicket t) async {
    Future<http.Response> run() async => http
        .get(Uri.parse('$authBase/qr/poll/${t.sessionId}'), headers: {...await deviceHeaders(), 'x-poll-token': t.pollToken})
        .timeout(_timeout);
    try {
      final r = await run();
      final d = jsonDecode(r.body);
      return d is Map ? Map<String, dynamic>.from(d) : {'status': 'error'};
    } catch (_) {
      return {'status': 'error'};
    }
  }

  /// Вошедшее устройство: кто просит вход
  Future<NecsouraQrRequest> qrScan(String sessionId) async {
    final (s, d) = await _send('POST', Uri.parse('$authBase/qr/scan'), body: {'sessionId': sessionId});
    if (s == 409) throw NecsouraException('Этот QR-код уже отсканировали');
    if (s != 200 || d is! Map) _fail(s, d, 'QR-код устарел — обновите его на устройстве');
    return NecsouraQrRequest(sessionId, Map<String, dynamic>.from(d['device'] ?? {}), d['ephemeralPublicKey']?.toString());
  }

  Future<void> qrApprove(String sessionId, {String? e2eePayload}) async {
    final (s, d) = await _send('POST', Uri.parse('$authBase/qr/approve'),
        body: {'sessionId': sessionId, if (e2eePayload != null) 'e2eePayload': e2eePayload});
    if (s != 200) _fail(s, d, 'QR-код устарел — обновите его на устройстве');
  }

  Future<void> qrCancel(String sessionId) async {
    try {
      await _send('POST', Uri.parse('$authBase/qr/cancel'), body: {'sessionId': sessionId});
    } catch (_) {}
  }
}
