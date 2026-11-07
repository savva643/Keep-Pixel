import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Пароль Necsoura без передачи пароля на сервер.
///
///   master  = Argon2id(пароль, соль, параметры аккаунта)
///   authKey = HKDF-SHA256(master, info "necsoura-auth-v1") — отправляется вместо пароля
///   encKey  = HKDF-SHA256(master, info "necsoura-e2ee-v1") — остаётся на устройстве,
///             открывает бэкап ключей шифрования Kompot
///
/// Тот же алгоритм обязан быть во всех клиентах экосистемы (Flutter, сайт).
/// Эталон для проверки — test/necsoura_password_test.dart.
class NecsouraPassword {
  static const Map<String, dynamic> defaultKdf = {
    'algorithm': 'argon2id',
    'memory': 19456, // КиБ (19 МБ) — рекомендация OWASP
    'iterations': 2,
    'parallelism': 1,
  };

  static Map<String, dynamic> newKdf() {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    return {...defaultKdf, 'salt': base64.encode(salt)};
  }

  /// Вычисляется в отдельном изоляте, чтобы не подвешивать интерфейс (~0.5–1.5 с).
  /// В вебе изолятов нет (Isolate.run бросает UnsupportedError — вход и регистрация
  /// в веб-версии падали) — считаем в основном потоке.
  static Future<PasswordKeys> derive(
      String password, Map<String, dynamic> kdf) {
    final params = Map<String, dynamic>.from(kdf);
    if (kIsWeb) return _derive(password, params);
    return Isolate.run(() => _derive(password, params));
  }

  static Future<PasswordKeys> _derive(
      String password, Map<String, dynamic> kdf) async {
    if (kdf['algorithm'] != 'argon2id') {
      throw ArgumentError('Unsupported KDF ${kdf['algorithm']}');
    }
    final argon = Argon2id(
      memory: (kdf['memory'] as num).toInt(),
      iterations: (kdf['iterations'] as num).toInt(),
      parallelism: (kdf['parallelism'] as num).toInt(),
      hashLength: 32,
    );
    final master = await argon.deriveKeyFromPassword(
      password: password,
      nonce: base64.decode(kdf['salt'] as String),
    );
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final auth = await hkdf.deriveKey(
        secretKey: master,
        nonce: const [],
        info: utf8.encode('necsoura-auth-v1'));
    final enc = await hkdf.deriveKey(
        secretKey: master,
        nonce: const [],
        info: utf8.encode('necsoura-e2ee-v1'));
    return PasswordKeys(
      Uint8List.fromList(await auth.extractBytes()),
      Uint8List.fromList(await enc.extractBytes()),
    );
  }
}

class PasswordKeys {
  final Uint8List authKey;
  final Uint8List encKey;
  PasswordKeys(this.authKey, this.encKey);

  String get authKeyBase64 => base64.encode(authKey);
}
