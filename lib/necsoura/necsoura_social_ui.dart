
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'necsoura_api.dart';
import 'necsoura_kit.dart';
import 'necsoura_social.dart';
import 'necsoura_ui.dart';

String _t(String key, [Map<String, String>? args]) => 'necsoura.$key'.tr(namedArgs: args);

/// Способы входа экосистемы: VK, Яндекс, Google и Apple (только на айфонах)
List<String> necsouraSocialProviders() => [
      'vk',
      'yandex',
      'google',
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) 'apple',
    ];

String necsouraProviderName(String p) => switch (p) {
      'vk' => 'VK ID',
      'yandex' => 'Яндекс ID',
      'google' => 'Google',
      'apple' => 'Apple',
      _ => p,
    };

/// Значок провайдера в его фирменных цветах
class NecsouraProviderIcon extends StatelessWidget {
  final String provider;
  final double size;
  const NecsouraProviderIcon({super.key, required this.provider, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/social_$provider.svg',
      width: size,
      height: size,
      colorFilter: provider == 'apple' ? ColorFilter.mode(Theme.of(context).colorScheme.onSurface, BlendMode.srcIn) : null,
    );
  }
}

/// Подтверждение у провайдера → вход в Necsoura. Новый человек выбирает логин, с 2FA — код.
/// true — вошли
Future<bool> necsouraSocialSignIn(BuildContext context, String provider) async {
  final kit = NecsouraKit.instance;
  final Map<String, dynamic> proof;
  try {
    proof = await NecsouraSocial.signIn(provider);
  } on NecsouraSocialCancelled {
    return false;
  }
  var r = await kit.api.oauthLogin(provider, proof);
  if (r['requires2FA'] == true) {
    if (!context.mounted) return false;
    return kit.twoFactor(context, globalId: r['globalId']?.toString(), twoFactorToken: r['twoFactorToken']?.toString());
  }
  if (r['needsRegistration'] == true) {
    if (!context.mounted) return false;
    final done = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickLoginSheet(provider: provider, data: r),
    );
    if (done == null) return false;
    r = done;
  }
  if (r['token'] == null) throw NecsouraException(_t('social_failed'));
  await kit.applySession(r);
  return true;
}

/// «или» и кнопки VK / Яндекс / Google / Apple под формой входа
class NecsouraSocialRow extends StatefulWidget {
  final VoidCallback onSignedIn;
  final ValueChanged<String> onError;
  const NecsouraSocialRow({super.key, required this.onSignedIn, required this.onError});

  @override
  State<NecsouraSocialRow> createState() => _NecsouraSocialRowState();
}

class _NecsouraSocialRowState extends State<NecsouraSocialRow> {
  Set<String> _server = {};
  String? _busy;

  @override
  void initState() {
    super.initState();
    NecsouraKit.instance.api.oauthProviders().then((s) {
      if (mounted) setState(() => _server = s);
    });
  }

  bool _ready(String p) => _server.contains(p) && NecsouraSocial.supported(p);

  Future<void> _tap(String p) async {
    if (_busy != null) return;
    if (!_ready(p)) {
      necsouraToast(context, _t('social_off', {'provider': necsouraProviderName(p)}));
      return;
    }
    final kit = NecsouraKit.instance;
    if (kit.socialLogin != null) return kit.socialLogin!(context, p);
    setState(() => _busy = p);
    try {
      if (await necsouraSocialSignIn(context, p)) widget.onSignedIn();
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = NecsouraKit.instance.brand.accent;
    final providers = necsouraSocialProviders();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Divider(color: scheme.onSurface.withOpacity(0.12))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_t('or_with'), style: TextStyle(color: scheme.onSurface.withOpacity(0.5), fontSize: 13.5)),
            ),
            Expanded(child: Divider(color: scheme.onSurface.withOpacity(0.12))),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < providers.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: NecsouraPressable(
                    accent: accent,
                    radius: BorderRadius.circular(16),
                    onTap: () => _tap(providers[i]),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _ready(providers[i]) ? 1 : 0.45,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
                        ),
                        alignment: Alignment.center,
                        child: _busy == providers[i]
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                            : NecsouraProviderIcon(provider: providers[i], size: 26),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Первый вход через провайдера: придумать логин Necsoura (имя и почту провайдер уже дал)
class _PickLoginSheet extends StatefulWidget {
  final String provider;
  final Map<String, dynamic> data;
  const _PickLoginSheet({required this.provider, required this.data});

  @override
  State<_PickLoginSheet> createState() => _PickLoginSheetState();
}

class _PickLoginSheetState extends State<_PickLoginSheet> {
  late final _login = TextEditingController(text: widget.data['suggestedLogin']?.toString() ?? '');
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await NecsouraKit.instance.api.oauthRegister(widget.provider, widget.data['registrationToken'].toString(), _login.text.trim());
      if (mounted) Navigator.of(context).pop(r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = NecsouraKit.instance.brand.accent;
    final name = widget.data['name']?.toString();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A20) : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  NecsouraProviderIcon(provider: widget.provider, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name == null || name.isEmpty ? _t('social_new') : _t('social_hello', {'name': name}),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(_t('social_pick_login'), style: TextStyle(color: scheme.onSurface.withOpacity(0.65), height: 1.4)),
                const SizedBox(height: 16),
                NecsouraField(
                  controller: _login,
                  label: _t('login'),
                  icon: Icons.alternate_email_rounded,
                  accent: accent,
                  autofocus: true,
                  action: TextInputAction.done,
                  onSubmitted: (_) => _create(),
                  validator: (v) => RegExp(r'^[a-zA-Z0-9_.\-]{3,32}$').hasMatch((v ?? '').trim()) ? null : _t('login_chars'),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: scheme.error))),
                const SizedBox(height: 16),
                NecsouraButton(text: _t('create_account'), accent: accent, loading: _busy, onPressed: _create),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
