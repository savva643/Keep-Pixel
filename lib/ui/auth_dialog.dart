import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
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

/// Sign-in: a window over the app on big screens, closed with the back
/// button, Esc or a click outside; the whole screen on a phone.
Future<bool> showLogin(BuildContext context, PixelApi api) async {
  setupNecsoura(api);
  final screen = MediaQuery.sizeOf(context);
  if (screen.width < 760 || screen.height < 560) {
    return await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (route) => NecsouraAuthScreen(
                onSuccess: () => Navigator.of(route).pop(true)))) ??
        false;
  }
  return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: .6),
          builder: (route) => Dialog(
              insetPadding: const EdgeInsets.all(32),
              clipBehavior: Clip.antiAlias,
              backgroundColor: Kp.bg,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                  side: BorderSide(color: Kp.line)),
              child: SizedBox(
                  width: (screen.width - 64).clamp(0, 1080),
                  height: (screen.height - 64).clamp(0, 720),
                  child: NecsouraAuthScreen(
                      onSuccess: () => Navigator.of(route).pop(true))))) ??
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
          icon: const Icon(Icons.verified_user_rounded,
              color: Kp.lilac, size: 36),
          title: Text('twofa.login_title'.tr()),
          content: SizedBox(
              width: 380,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        (backup ? 'twofa.login_backup_text' : 'twofa.login_text')
                            .tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: muted, height: 1.5)),
                    const SizedBox(height: 16),
                    TextField(
                        key: ValueKey(backup),
                        controller: code,
                        enabled: !busy,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType:
                            backup ? TextInputType.text : TextInputType.number,
                        maxLength: backup ? 32 : 6,
                        inputFormatters: backup
                            ? null
                            : [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4),
                        decoration: InputDecoration(
                            counterText: '',
                            hintText: (backup
                                    ? 'twofa.login_backup'
                                    : 'twofa.login_app')
                                .tr()),
                        onChanged: (v) {
                          if (!backup && v.length == 6) submit();
                        },
                        onSubmitted: (_) => submit()),
                    const SizedBox(height: 6),
                    TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  backup = !backup;
                                  code.clear();
                                  error = null;
                                }),
                        child: Text(
                            (backup ? 'twofa.use_app' : 'twofa.use_backup').tr(),
                            textAlign: TextAlign.center)),
                    if (error != null)
                      Text(error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Kp.error)),
                  ])),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: Text('twofa.cancel'.tr())),
            FilledButton(
                onPressed: busy ? null : submit,
                child: Text((busy ? 'twofa.checking' : 'twofa.confirm').tr()))
          ]);
}
