import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../necsoura/necsoura_api.dart';
import '../necsoura/necsoura_auth_screen.dart';
import '../necsoura/necsoura_kit.dart';
import '../necsoura/necsoura_ui.dart';
import 'shared.dart';

/// Connects the shared Necsoura screens (lib/necsoura, same as blast! and
/// Kompot) to this app's session. Called before opening them because the
/// server addresses can change in the settings.
void setupNecsoura(PixelApi api) {
  NecsouraKit.instance = NecsouraKit(
    brand: const NecsouraBrand(
        appName: 'Keep Pixel',
        appIcon: 'assets/images/keeppixel_logo.png',
        accent: Kp.violet,
        accentDeep: Kp.blue),
    api: NecsouraApi(
        authBase: api.authUrl,
        profileBase: PixelApi.defaultProfile,
        token: () async => api.sessionToken,
        refresh: api.refreshSession,
        deviceHeaders: () async =>
            {'Content-Type': 'application/json', ...api.deviceHeaders}),
    login: (login, password) async {
      try {
        return await api.login(login, password)
            ? NecsouraAuthOutcome.success
            : NecsouraAuthOutcome.twoFactor;
      } catch (e) {
        return NecsouraAuthOutcome.failure('$e');
      }
    },
    register: (login, email, password) async {
      try {
        await api.register(login, email, password);
        return NecsouraAuthOutcome.success;
      } catch (e) {
        return NecsouraAuthOutcome.failure('$e');
      }
    },
    twoFactor: (context, {globalId, twoFactorToken}) async {
      if (twoFactorToken != null) api.pendingTwoFactor = twoFactorToken;
      return await showDialog<bool>(
              context: context, builder: (_) => _TwoFactorDialog(api: api)) ??
          false;
    },
    applySession: api.applySession,
    logout: (context) async {
      await api.logout();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    },
    onProfileChanged: (_) => api.profileChanged(),
    forgotPassword: (context, _) =>
        openLink(context, '${api.accountSite}/auth/login'),
    pickImage: () async {
      final picked = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
      final file = picked?.files.single;
      return file?.bytes == null
          ? null
          : (bytes: file!.bytes!, name: file.name);
    },
    authScheme: 'keeppixel-auth',
  );
}

Future<bool> showLogin(BuildContext context, PixelApi api) async {
  setupNecsoura(api);
  return await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (route) => NecsouraAuthScreen(
              onSuccess: () => Navigator.of(route).pop(true)))) ??
      false;
}

class _TwoFactorDialog extends StatefulWidget {
  final PixelApi api;
  const _TwoFactorDialog({required this.api});
  @override
  State<_TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<_TwoFactorDialog> {
  final code = TextEditingController();
  bool busy = false, backup = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || code.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.confirm2fa(code.text, backup: backup);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Подтвердите вход'),
          content: SizedBox(
              width: 360,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: code,
                        enabled: !busy,
                        autofocus: true,
                        decoration: InputDecoration(
                            labelText:
                                backup ? 'Резервный код' : 'Код из приложения'),
                        onSubmitted: (_) => submit()),
                    TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  backup = !backup;
                                  error = null;
                                }),
                        child: Text(backup
                            ? 'Код из приложения'
                            : 'Использовать резервный код')),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Kp.error)),
                  ])),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Проверка…' : 'Подтвердить'))
          ]);
}
