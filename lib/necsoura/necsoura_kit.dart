import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/auth/necsoura_password.dart';
import 'necsoura_api.dart';
import 'necsoura_ui.dart';

enum NecsouraAuthStatus { success, twoFactor, failure }

class NecsouraAuthOutcome {
  final NecsouraAuthStatus status;
  final String? error;
  const NecsouraAuthOutcome(this.status, [this.error]);
  static const success = NecsouraAuthOutcome(NecsouraAuthStatus.success);
  static const twoFactor = NecsouraAuthOutcome(NecsouraAuthStatus.twoFactor);
  const NecsouraAuthOutcome.failure(String message) : this(NecsouraAuthStatus.failure, message);
}

/// Всё, что общим экранам аккаунта нужно от приложения: цвет, запросы и то, как приложение
/// хранит сессию. Задаётся один раз при запуске ([NecsouraKit.instance]).
class NecsouraKit {
  final NecsouraBrand brand;
  final NecsouraApi api;

  /// Вход по логину и паролю
  final Future<NecsouraAuthOutcome> Function(String login, String password) login;
  /// Регистрация
  final Future<NecsouraAuthOutcome> Function(String login, String email, String password) register;
  /// Второй шаг входа (код 2FA); true — вошли. После входа через соцсеть приходят globalId и twoFactorToken
  final Future<bool> Function(BuildContext context, {String? globalId, String? twoFactorToken}) twoFactor;
  /// Вход подтвердили (QR, соцсеть): сохранить токены из ответа сервера (token, refreshToken, globalId, login)
  final Future<void> Function(Map<String, dynamic> payload) applySession;
  /// Выход из аккаунта на этом устройстве
  final Future<void> Function(BuildContext context) logout;

  /// Профиль поменялся (имя, фото) — обновить шапку приложения
  final void Function(NecsouraProfile profile)? onProfileChanged;
  /// Пароль сменили (Kompot перешифровывает им бэкап ключей переписки)
  final Future<void> Function(PasswordKeys keys, int passwordVersion)? onPasswordChanged;
  /// Подтверждаем вход по QR: что передать новому устройству (ключи шифрования Kompot)
  final Future<String?> Function(NecsouraQrRequest request)? qrPayload;
  /// Дополнительные строки в «Вход и безопасность» (например, двухфакторная защита в Kompot)
  final List<Widget> Function(BuildContext context)? extraSecurity;
  /// Восстановление пароля — если приложение его поддерживает
  final void Function(BuildContext context, String login)? forgotPassword;
  /// Выбрать картинку для фото профиля (у приложений разные плагины выбора файлов)
  final Future<({Uint8List bytes, String name})?> Function() pickImage;
  /// Свой вход по QR (Kompot кладёт в код ключ, чтобы новое устройство получило ключи переписки):
  /// показывает данные QR через onQr, завершается после входа. Нет — общий вход по QR.
  final Future<void> Function({required void Function(String qrData) onQr, required bool Function() isCancelled})? qrFlow;
  /// Схема возврата из браузера после входа через VK / Яндекс (у каждого приложения своя)
  final String authScheme;
  /// Свой вход через соцсеть (Kompot: экраны регистрации и ключи переписки). Нет — общий
  final Future<void> Function(BuildContext context, String provider)? socialLogin;

  NecsouraKit({
    required this.brand,
    required this.api,
    required this.login,
    required this.register,
    required this.twoFactor,
    required this.applySession,
    required this.logout,
    this.onProfileChanged,
    this.onPasswordChanged,
    this.qrPayload,
    this.extraSecurity,
    this.forgotPassword,
    required this.pickImage,
    this.qrFlow,
    required this.authScheme,
    this.socialLogin,
  });

  static late NecsouraKit instance;
}
