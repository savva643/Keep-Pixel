import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/api.dart';
import 'shared.dart';

String _t(String key) => 'twofa.$key'.tr();

/// The row in the Necsoura account settings that leads to 2FA.
class TwoFactorTile extends StatefulWidget {
  final PixelApi api;
  const TwoFactorTile({super.key, required this.api});
  @override
  State<TwoFactorTile> createState() => _TwoFactorTileState();
}

class _TwoFactorTileState extends State<TwoFactorTile> {
  late Future<({bool enabled, bool backupCodes, int? backupLeft})> status =
      widget.api.twoFactorStatus();

  Future<void> _open() async {
    await showTwoFactor(context, widget.api);
    if (mounted) setState(() => status = widget.api.twoFactorStatus());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: status,
      builder: (context, state) {
        final on = state.data?.enabled ?? false;
        final subtitle = state.hasError
            ? _t('unavailable')
            : state.hasData
                ? _t(on ? 'on' : 'off')
                : _t('loading');
        return Hovered(
            onTap: _open,
            builder: (context, hover) => AnimatedContainer(
                duration: Kp.motion,
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: BoxDecoration(
                    color: hover ? Kp.raised : Kp.surface,
                    borderRadius: Kp.r20,
                    border: Border.all(color: hover ? Kp.violet : Kp.line)),
                child: Row(children: [
                  _Badge(on: on, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_t('title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    on && !state.hasError ? Kp.online : muted)),
                      ])),
                  const Icon(Icons.chevron_right_rounded, color: muted),
                ])));
      });
}

/// Two-factor authentication of the Necsoura account: a window over the app
/// on a big screen, the whole screen on a phone.
Future<void> showTwoFactor(BuildContext context, PixelApi api) {
  final screen = MediaQuery.sizeOf(context);
  if (screen.width < 640 || screen.height < 560) {
    return Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
            backgroundColor: Kp.bg,
            body: SafeArea(child: TwoFactorView(api: api)))));
  }
  return showDialog(
      context: context,
      builder: (_) => Dialog(
          backgroundColor: Kp.bg,
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.all(32),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
              side: BorderSide(color: Kp.line)),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: 580, maxHeight: (screen.height - 64).clamp(0, 820)),
              child: TwoFactorView(api: api))));
}

enum _Stage { loading, failed, ready }

class TwoFactorView extends StatefulWidget {
  final PixelApi api;
  const TwoFactorView({super.key, required this.api});
  @override
  State<TwoFactorView> createState() => _TwoFactorViewState();
}

class _TwoFactorViewState extends State<TwoFactorView> {
  _Stage stage = _Stage.loading;
  bool enabled = false, hasBackup = false, busy = false, unsupported = false;
  int? backupLeft;
  ({String secret, String? otpauth, String? qrImage})? setup;
  List<String> codes = const [];
  final code = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      stage = _Stage.loading;
      error = null;
    });
    try {
      final s = await widget.api.twoFactorStatus();
      if (!mounted) return;
      setState(() {
        enabled = s.enabled;
        hasBackup = s.backupCodes;
        backupLeft = s.backupLeft;
        stage = _Stage.ready;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        unsupported = e.status == 404;
        error = unsupported ? _t('unavailable') : e.message;
        stage = _Stage.failed;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          stage = _Stage.failed;
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on ApiError catch (e) {
      if (mounted) setState(() => error = _explain(e));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _toggle(bool on) {
    if (on) {
      _run(() async {
        try {
          final s = await widget.api.twoFactorSetup();
          if (mounted) setState(() => setup = s);
        } on ApiError catch (e) {
          // Turned on from another device meanwhile.
          if (e.code != 'two_factor_enabled') rethrow;
          await _load();
        }
      });
    } else {
      _confirm(_t('disable_title'), _t('disable_text'), _t('disable'),
          (code) async {
        await widget.api.twoFactorDisable(code);
        if (!mounted) return;
        setState(() {
          enabled = false;
          hasBackup = false;
          backupLeft = null;
          codes = const [];
        });
        notice(context, _t('disabled'));
      }, danger: true);
    }
  }

  Future<void> _verify() async {
    if (code.text.trim().length < 6) return;
    await _run(() async {
      final fresh = await widget.api.twoFactorVerify(code.text);
      if (!mounted) return;
      code.clear();
      setState(() {
        enabled = true;
        setup = null;
        codes = fresh;
        hasBackup = fresh.isNotEmpty;
        backupLeft = fresh.length;
      });
      notice(context, _t('enabled_ok'));
    });
  }

  void _regenerate() =>
      _confirm(_t('regen_title'), _t('regen_text'), _t('create'), (code) async {
        final fresh = await widget.api.twoFactorBackupCodes(code);
        if (mounted) {
          setState(() {
            codes = fresh;
            hasBackup = fresh.isNotEmpty;
            backupLeft = fresh.length;
          });
        }
      }, backupAllowed: false);

  String _explain(ApiError e) => switch (e.code) {
        'invalid_code' => _t('err_invalid_code'),
        'too_many_attempts' => _t('err_too_many'),
        'two_factor_not_setup' || 'two_factor_disabled' => _t('err_state'),
        _ => e.message,
      };

  /// Asks to confirm with a code: the server wants one to turn 2FA off or
  /// to replace the backup codes.
  Future<void> _confirm(String title, String text, String action,
      Future<void> Function(String code) run,
      {bool danger = false, bool backupAllowed = true}) async {
    final field = TextEditingController();
    final entered = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(title),
                content: SizedBox(
                    width: 380,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(text,
                              style:
                                  const TextStyle(color: muted, height: 1.5)),
                          const SizedBox(height: 16),
                          TextField(
                              controller: field,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              maxLength: backupAllowed ? 32 : 6,
                              keyboardType: backupAllowed
                                  ? TextInputType.text
                                  : TextInputType.number,
                              inputFormatters: backupAllowed
                                  ? null
                                  : [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3),
                              decoration: InputDecoration(
                                  counterText: '',
                                  hintText: _t(backupAllowed
                                      ? 'code_or_backup'
                                      : 'code_label')),
                              onSubmitted: (v) => v.trim().isEmpty
                                  ? null
                                  : Navigator.pop(context, v)),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_t('cancel'))),
                  ListenableBuilder(
                      listenable: field,
                      builder: (context, _) => FilledButton(
                          style: danger
                              ? FilledButton.styleFrom(
                                  backgroundColor: Kp.error)
                              : null,
                          onPressed: field.text.trim().isEmpty
                              ? null
                              : () => Navigator.pop(context, field.text),
                          child: Text(action))),
                ]));
    // The dialog still shows the field while it fades out.
    Future.delayed(const Duration(seconds: 1), field.dispose);
    if (entered != null && entered.trim().isNotEmpty) {
      await _run(() => run(entered));
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    notice(context, _t('copied'));
  }

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              IconButton(
                  tooltip: _t('close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(_t('title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
            ])),
        Flexible(
            child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: _body())),
      ]);

  List<Widget> _body() {
    if (stage == _Stage.loading) {
      return const [
        Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()))
      ];
    }
    if (stage == _Stage.failed) {
      return [
        const _Hero(on: false),
        const SizedBox(height: 16),
        _Card(
            icon: unsupported ? Icons.cloud_off_rounded : Icons.error_outline,
            color: unsupported ? muted : Kp.error,
            title: unsupported ? _t('unavailable') : _t('load_error'),
            subtitle: unsupported ? null : error,
            below: unsupported
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(_t('retry'))))),
      ];
    }
    return [
      _Hero(on: enabled),
      const SizedBox(height: 16),
      _Card(
          icon: Icons.phonelink_lock_rounded,
          color: Kp.violet,
          title: _t('app_codes'),
          subtitle: _t(enabled ? 'on' : 'off'),
          subtitleColor: enabled ? Kp.online : null,
          trailing: Switch(
              value: enabled || setup != null,
              onChanged: busy
                  ? null
                  : (v) => setup != null && !v
                      ? setState(() => setup = null)
                      : _toggle(v))),
      if (setup != null) ...[
        const SizedBox(height: 12),
        _setupCard(setup!),
      ],
      if (enabled) ...[
        const SizedBox(height: 12),
        _backupCard(),
      ],
      if (error != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: Kp.error))),
    ];
  }

  Widget _setupCard(({String secret, String? otpauth, String? qrImage}) s) {
    final Widget qr = s.qrImage != null
        ? Image.memory(base64Decode(s.qrImage!.split(',').last),
            width: 180, height: 180, filterQuality: FilterQuality.none)
        : QrImageView(
            data: s.otpauth ??
                'otpauth://totp/Necsoura?secret=${s.secret}&issuer=Necsoura',
            size: 180,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white);
    return _Card(
        icon: Icons.qr_code_2_rounded,
        color: Kp.indigo,
        title: _t('setup_title'),
        below:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 14),
          _Step(n: 1, title: _t('step_scan'), hint: _t('step_scan_hint')),
          const SizedBox(height: 12),
          Center(
              child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                      color: Colors.white, borderRadius: Kp.r14),
                  child: qr)),
          const SizedBox(height: 12),
          Text(_t('step_key'),
              style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                  color: Kp.bg,
                  borderRadius: Kp.r14,
                  border: Border.all(color: Kp.line)),
              child: Row(children: [
                Expanded(
                    child: SelectableText(s.secret,
                        style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1))),
                IconButton(
                    tooltip: _t('copy'),
                    onPressed: () => _copy(s.secret),
                    icon: const Icon(Icons.copy_rounded, size: 18)),
              ])),
          const SizedBox(height: 16),
          _Step(n: 2, title: _t('step_code')),
          const SizedBox(height: 10),
          TextField(
              controller: code,
              enabled: !busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
              decoration:
                  InputDecoration(hintText: _t('code_label'), counterText: ''),
              onChanged: (v) {
                if (v.length == 6) _verify();
              },
              onSubmitted: (_) => _verify()),
          const SizedBox(height: 12),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: busy ? null : _verify,
              child: Text(busy ? _t('checking') : _t('confirm'))),
        ]));
  }

  Widget _backupCard() {
    final has = codes.isNotEmpty;
    return _Card(
        icon: Icons.key_rounded,
        color: const Color(0xFFF5B83D),
        title: _t('backup'),
        subtitle: has
            ? _t('backup_save')
            : backupLeft != null
                ? 'twofa.backup_left'.tr(args: ['$backupLeft'])
                : hasBackup
                    ? _t('backup_ready')
                    : _t('backup_hint'),
        trailing: has
            ? IconButton(
                tooltip: _t('copy'),
                onPressed: () => _copy(codes.join('\n')),
                icon: const Icon(Icons.copy_rounded))
            : null,
        below:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (has) ...[
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, box) {
              final columns = (box.maxWidth / 130).floor().clamp(2, 4);
              return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3,
                  children: [
                    for (final c in codes)
                      Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                              color: Kp.bg,
                              borderRadius: Kp.r10,
                              border: Border.all(color: Kp.line)),
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SelectableText(c,
                                  style: const TextStyle(
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1)))),
                  ]);
            }),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: busy ? null : _regenerate,
              icon: const Icon(Icons.autorenew_rounded),
              label: Text(_t('generate'),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]));
  }
}

class _Badge extends StatelessWidget {
  final bool on;
  final double size;
  const _Badge({required this.on, this.size = 52});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: on
                  ? const [Color(0xFF34C77B), Color(0xFF1E9E61)]
                  : const [Kp.violet, Kp.blue]),
          borderRadius: BorderRadius.circular(size * .3)),
      child: Icon(on ? Icons.verified_user_rounded : Icons.shield_outlined,
          color: Colors.white, size: size * .54));
}

class _Hero extends StatelessWidget {
  final bool on;
  const _Hero({required this.on});
  @override
  Widget build(BuildContext context) {
    final c = on ? Kp.online : Kp.violet;
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            borderRadius: Kp.r20,
            border: Border.all(color: c.withValues(alpha: .25)),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.withValues(alpha: .2), c.withValues(alpha: .04)])),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Badge(on: on),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_t(on ? 'hero_on' : 'hero_off'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(_t('hero_text'),
                    style: const TextStyle(
                        color: muted, fontSize: 13, height: 1.5)),
              ])),
        ]));
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing, below;
  const _Card(
      {required this.icon,
      required this.color,
      required this.title,
      this.subtitle,
      this.subtitleColor,
      this.trailing,
      this.below});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
          color: Kp.surface,
          borderRadius: Kp.r20,
          border: Border.all(color: Kp.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .15), borderRadius: Kp.r14),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor ?? muted,
                          height: 1.4)),
                ],
              ])),
          if (trailing != null) trailing!,
        ]),
        if (below != null) below!,
      ]));
}

class _Step extends StatelessWidget {
  final int n;
  final String title;
  final String? hint;
  const _Step({required this.n, required this.title, this.hint});
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: Kp.violet, shape: BoxShape.circle),
            child: Text('$n',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (hint != null)
            Text(hint!, style: const TextStyle(color: muted, fontSize: 12)),
        ])),
      ]);
}
