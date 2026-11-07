// Вход через VK / Яндекс / Google / Apple для всех приложений Necsoura: получить у провайдера подтверждение входа.
//
// Возвращает то, что auth-service проверит у самого провайдера (POST auth/oauth/:provider):
//   Google на Android/iOS — idToken из системного входа Google (google_sign_in);
//   Apple на iOS          — identityToken (sign_in_with_apple);
//   VK, Яндекс, Google на Windows — код авторизации из браузера с PKCE (flutter_web_auth_2),
//   код на токен меняет сервер (у Яндекса и Google для этого нужен секрет приложения).
//
// Id приложений — при сборке: --dart-define=VK_CLIENT_ID=... (см. список ниже).
// Кнопка показывается, только если провайдер включён и на сервере, и в сборке.
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'necsoura_kit.dart';

class NecsouraSocialCancelled implements Exception {}

class NecsouraSocialException implements Exception {
  final String message;
  NecsouraSocialException(this.message);
  @override
  String toString() => message;
}

class NecsouraSocial {
  static const vkClientId = String.fromEnvironment('VK_CLIENT_ID');
  static const yandexClientId = String.fromEnvironment('YANDEX_CLIENT_ID');
  /// Web-клиент Google: id_token выпускается для него (Android и iOS)
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  /// Клиент Google типа «Desktop app» для Windows
  static const googleDesktopClientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');

  /// Телефоны и Mac: браузер возвращает в приложение по этой схеме (CallbackActivity /
  /// ASWebAuthenticationSession), у каждого приложения своя: blast-auth, kompot-auth
  static String get _appScheme => NecsouraKit.instance.authScheme;
  /// Windows и Linux: браузер возвращает на локальный адрес, его слушает flutter_web_auth_2
  static const _desktopPort = 47391;

  static TargetPlatform get _os => defaultTargetPlatform;
  static bool get _mobile => !kIsWeb && (_os == TargetPlatform.android || _os == TargetPlatform.iOS);
  /// Возврат по схеме приложения: телефоны и macOS (на Mac возврат на localhost невозможен)
  static bool get _schemeReturn => !kIsWeb && (_mobile || _os == TargetPlatform.macOS);

  /// Google на Mac: iOS-клиент Google (тот же Bundle ID), возврат по его перевёрнутому id
  static String get _googleMacScheme => googleIosClientId.split('.').reversed.join('.');

  static String redirectUri(String provider) {
    // Веб: всплывающее окно провайдера возвращается на страницу auth.html рядом с приложением
    if (kIsWeb) return '${Uri.base.origin}/auth.html';
    if (provider == 'google' && _os == TargetPlatform.macOS) return '$_googleMacScheme:/oauth2redirect';
    if (!_schemeReturn) return 'http://localhost:$_desktopPort/oauth/$provider';
    // Мобильным приложениям VK ID разрешает только свой адрес возврата
    if (provider == 'vk' && _mobile) return 'vk$vkClientId://vk.ru/blank.html';
    return '$_appScheme://oauth/$provider';
  }

  static String _callbackScheme(String provider) {
    if (kIsWeb) return Uri.base.scheme;
    if (provider == 'google' && _os == TargetPlatform.macOS) return _googleMacScheme;
    if (!_schemeReturn) return 'http://localhost:$_desktopPort';
    return provider == 'vk' && _mobile ? 'vk$vkClientId' : _appScheme;
  }

  /// Каким клиентом Google входим через браузер: веб — web-клиент, Mac — iOS-клиент, Windows/Linux — desktop
  static String get _googleWebClientId {
    if (kIsWeb) return googleServerClientId;
    if (_os == TargetPlatform.macOS) return googleIosClientId;
    return googleDesktopClientId;
  }

  /// Есть ли в этой сборке всё нужное для провайдера на этой платформе
  static bool supported(String provider) {
    switch (provider) {
      case 'vk':
        return vkClientId.isNotEmpty;
      case 'yandex':
        return yandexClientId.isNotEmpty;
      case 'google':
        if (kIsWeb) return googleServerClientId.isNotEmpty;
        if (_os == TargetPlatform.android) return googleServerClientId.isNotEmpty;
        if (_os == TargetPlatform.iOS) return googleServerClientId.isNotEmpty && googleIosClientId.isNotEmpty;
        if (_os == TargetPlatform.macOS) return googleIosClientId.isNotEmpty;
        return googleDesktopClientId.isNotEmpty;
      case 'apple':
        return !kIsWeb && (_os == TargetPlatform.iOS || _os == TargetPlatform.macOS);
      default:
        return false;
    }
  }

  static Future<Map<String, dynamic>> signIn(String provider) async {
    switch (provider) {
      case 'google':
        return _mobile ? _googleNative() : _webFlow(provider);
      case 'apple':
        return _apple();
      case 'vk':
      case 'yandex':
        return _webFlow(provider);
    }
    throw NecsouraSocialException('Неизвестный способ входа');
  }

  // ---------- Google (Android/iOS) ----------
  static bool _googleReady = false;

  static Future<Map<String, dynamic>> _googleNative() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        clientId: _os == TargetPlatform.iOS ? googleIosClientId : null,
        serverClientId: googleServerClientId,
      );
      _googleReady = true;
    }
    try {
      final account = await google.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) throw NecsouraSocialException('Google не вернул данные входа');
      // Выбор аккаунта при следующем входе — заново, а не молча прошлым
      await google.signOut();
      return {'idToken': idToken};
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw NecsouraSocialCancelled();
      throw NecsouraSocialException('Вход через Google не удался: ${e.description ?? e.code.name}');
    }
  }

  // ---------- Apple (iOS) ----------
  static Future<Map<String, dynamic>> _apple() async {
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      if (c.identityToken == null) throw NecsouraSocialException('Apple не вернул данные входа');
      final name = [c.givenName, c.familyName].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      return {'idToken': c.identityToken, if (name.isNotEmpty) 'name': name};
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw NecsouraSocialCancelled();
      throw NecsouraSocialException('Вход через Apple не удался: ${e.message}');
    }
  }

  // ---------- VK, Яндекс, Google на Windows: браузер + PKCE ----------
  static String _random(int bytes) {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(bytes, (_) => r.nextInt(256))).replaceAll('=', '');
  }

  static Future<Map<String, dynamic>> _webFlow(String provider) async {
    final verifier = _random(48);
    final challenge = base64Url
        .encode((await Sha256().hash(utf8.encode(verifier))).bytes)
        .replaceAll('=', '');
    final state = _random(16);
    final redirect = redirectUri(provider);

    final Uri url;
    switch (provider) {
      case 'yandex':
        url = Uri.https('oauth.yandex.ru', '/authorize', {
          'response_type': 'code',
          'client_id': yandexClientId,
          'redirect_uri': redirect,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'state': state,
        });
      case 'vk':
        url = Uri.https('id.vk.ru', '/authorize', {
          'response_type': 'code',
          'client_id': vkClientId,
          'redirect_uri': redirect,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'state': state,
          'scope': 'email',
        });
      default: // google на Windows
        url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'response_type': 'code',
          'client_id': _googleWebClientId,
          'redirect_uri': redirect,
          'scope': 'openid email profile',
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'state': state,
          'prompt': 'select_account',
        });
    }

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: _callbackScheme(provider),
        // Windows: системный браузер, а не встроенный webview — Google вход во webview запрещает
        options: const FlutterWebAuth2Options(useWebview: false),
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw NecsouraSocialCancelled();
      throw NecsouraSocialException('Не удалось открыть вход: ${e.message ?? e.code}');
    }

    final q = Uri.parse(result).queryParameters;
    if (q['error'] != null) {
      if (q['error'] == 'access_denied') throw NecsouraSocialCancelled();
      throw NecsouraSocialException(q['error_description'] ?? q['error']!);
    }
    // state защищает от подсунутого чужого кода
    if (q['state'] != state || q['code'] == null) throw NecsouraSocialException('Ответ входа не прошёл проверку');
    return {
      'code': q['code'],
      // Сервер знает несколько приложений провайдера (у сервисов Necsoura они бывают свои) — говорим, каким входили
      'clientId': switch (provider) { 'yandex' => yandexClientId, 'vk' => vkClientId, _ => _googleWebClientId },
      'codeVerifier': verifier,
      'redirectUri': redirect,
      'state': state,
      if (q['device_id'] != null) 'deviceId': q['device_id'],
    };
  }
}
