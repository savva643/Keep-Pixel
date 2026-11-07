import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'avatar_cropper.dart';

import 'necsoura_api.dart';
import 'necsoura_kit.dart';
import 'necsoura_qr_scan.dart';
import 'necsoura_social.dart';
import 'necsoura_social_ui.dart';
import 'necsoura_ui.dart';

String _t(String key, [Map<String, String>? args]) => 'necsoura.$key'.tr(namedArgs: args);

/// «Аккаунт Necsoura» — одна страница во всех приложениях: имя и фото (общие с Kompot),
/// пароль и почта, устройства с входом по QR, выход. Свой у приложения только цвет.
class NecsouraAccountScreen extends StatefulWidget {
  const NecsouraAccountScreen({super.key});

  @override
  State<NecsouraAccountScreen> createState() => _NecsouraAccountScreenState();
}

class _NecsouraAccountScreenState extends State<NecsouraAccountScreen> {
  NecsouraKit get kit => NecsouraKit.instance;
  Color get accent => kit.brand.accent;

  NecsouraProfile? _profile;
  List<NecsouraSession>? _sessions;
  ({bool hasPassword, Set<String> available, Map<String, ({String? email, String? name})> linked})? _ids;
  String? _linking;
  String? _error;
  bool _avatarBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([kit.api.profile(), kit.api.sessions().catchError((_) => <NecsouraSession>[])]);
      // Способы входа: сервер без OAuth отвечает 404 — тогда показываем, что привязать пока нельзя
      kit.api.identities().then((ids) {
        if (mounted) setState(() => _ids = ids);
      }).catchError((_) {
        if (mounted) setState(() => _ids = (hasPassword: true, available: <String>{}, linked: <String, ({String? email, String? name})>{}));
      });
      if (!mounted) return;
      setState(() {
        _profile = results[0] as NecsouraProfile;
        _sessions = results[1] as List<NecsouraSession>;
      });
      kit.onProfileChanged?.call(_profile!);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _reloadSessions() async {
    try {
      final s = await kit.api.sessions();
      if (mounted) setState(() => _sessions = s);
    } catch (_) {}
  }

  void _setProfile(NecsouraProfile p) {
    setState(() => _profile = p);
    kit.onProfileChanged?.call(p);
  }

  // ── Имя ──

  Future<void> _editName() async {
    final p = _profile;
    if (p == null) return;
    final controller = TextEditingController(text: p.name ?? '');
    final name = await _sheet<String>(
      title: _t('name'),
      builder: (ctx, close) => _NameForm(controller: controller, accent: accent, onSave: (v) => close(v)),
    );
    if (name == null || name.trim() == (p.name ?? '')) return;
    try {
      await kit.api.setName(name);
      _setProfile(p.copyWith(name: name.trim()));
      if (mounted) necsouraToast(context, _t('name_saved'));
    } catch (e) {
      if (mounted) necsouraToast(context, e.toString(), error: true);
    }
  }

  // ── Username: публичный адрес вместо @id12 ──

  Future<void> _editUsername() async {
    final p = _profile;
    if (p == null) return;
    final controller = TextEditingController(text: p.username ?? '');
    final username = await _sheet<String>(
      title: _t('username'),
      builder: (ctx, close) => _NameForm(
        controller: controller,
        accent: accent,
        onSave: (v) => close(v.replaceFirst('@', '')),
        hint: _t('username_where', {'id': p.publicId != null ? '@id${p.publicId}' : ''}),
        label: _t('username'),
        icon: Icons.alternate_email_rounded,
        validator: (v) {
          final s = (v ?? '').trim().replaceFirst('@', '');
          if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(s)) return _t('username_bad');
          if (RegExp(r'^id\d+$', caseSensitive: false).hasMatch(s)) return _t('username_reserved');
          return null;
        },
      ),
    );
    if (username == null || username == (p.username ?? '')) return;
    try {
      await kit.api.setUsername(username);
      _setProfile(p.copyWith(username: username));
      if (mounted) necsouraToast(context, _t('username_saved'));
    } catch (e) {
      if (mounted) necsouraToast(context, e.toString(), error: true);
    }
  }

  // ── Фото ──

  Future<void> _editAvatar() async {
    final p = _profile;
    if (p == null || _avatarBusy) return;
    final action = p.avatarUrl == null
        ? 'pick'
        : await _sheet<String>(
            title: _t('photo'),
            builder: (ctx, close) => Column(
              children: [
                NecsouraGroup(children: [
                  NecsouraTile(icon: Icons.photo_library_outlined, title: _t('photo_pick'), accent: accent, autofocus: true, onTap: () => close('pick')),
                  NecsouraTile(
                    icon: Icons.delete_outline_rounded,
                    title: _t('photo_remove'),
                    accent: accent,
                    color: Theme.of(ctx).colorScheme.error,
                    onTap: () => close('remove'),
                  ),
                ]),
              ],
            ),
          );
    if (action == null) return;
    setState(() => _avatarBusy = true);
    try {
      if (action == 'remove') {
        await kit.api.removeAvatar();
        _setProfile(p.copyWith(clearAvatar: true));
      } else {
        final file = await kit.pickImage();
        if (file == null || !mounted) return;
        final cropped = await cropAvatar(context, file.bytes);
        if (cropped == null) return;
        final url = await kit.api.uploadAvatar(cropped, 'avatar.png');
        _setProfile(p.copyWith(avatarUrl: url));
        if (mounted) necsouraToast(context, _t('photo_saved'));
      }
    } catch (e) {
      if (mounted) necsouraToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  // ── Пароль и почта ──

  Future<void> _changePassword() async {
    final p = _profile;
    if (p == null) return;
    final ok = await _sheet<bool>(
      title: _t('password_change'),
      builder: (ctx, close) => _PasswordForm(login: p.login, accent: accent, onDone: () => close(true)),
    );
    if (ok == true && mounted) necsouraToast(context, _t('password_changed'));
  }

  Future<void> _email() async {
    final p = _profile;
    if (p == null) return;
    final email = await _sheet<String>(
      title: _t('email'),
      builder: (ctx, close) => _EmailForm(profile: p, accent: accent, onChanged: (e) => close(e)),
    );
    if (email != null) _setProfile(p.copyWith(email: email));
  }

  // ── Способы входа ──

  Future<void> _toggleProvider(String p) async {
    final ids = _ids;
    if (ids == null || _linking != null) return;
    final linked = ids.linked[p];
    if (linked != null) {
      final yes = await _confirm(_t('social_unlink_q', {'provider': necsouraProviderName(p)}), _t('social_unlink'));
      if (yes != true) return;
      setState(() => _linking = p);
      try {
        await kit.api.unlinkProvider(p);
        setState(() => _ids = (hasPassword: ids.hasPassword, available: ids.available, linked: {...ids.linked}..remove(p)));
      } catch (e) {
        if (mounted) necsouraToast(context, e.toString(), error: true);
      } finally {
        if (mounted) setState(() => _linking = null);
      }
      return;
    }
    if (!ids.available.contains(p) || !NecsouraSocial.supported(p)) {
      necsouraToast(context, _t('social_off', {'provider': necsouraProviderName(p)}));
      return;
    }
    setState(() => _linking = p);
    try {
      await kit.api.linkProvider(p, await NecsouraSocial.signIn(p));
      final fresh = await kit.api.identities();
      if (mounted) {
        setState(() => _ids = fresh);
        necsouraToast(context, _t('social_linked', {'provider': necsouraProviderName(p)}));
      }
    } on NecsouraSocialCancelled {
      // передумал
    } catch (e) {
      if (mounted) necsouraToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _linking = null);
    }
  }

  // ── Устройства ──

  Future<void> _scanQr() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NecsouraQrScanScreen()));
    if (ok == true) {
      if (mounted) necsouraToast(context, _t('qr_device_signed_in'));
      _reloadSessions();
    }
  }

  Future<void> _revoke(NecsouraSession s) async {
    final yes = await _confirm(_t('session_end_q', {'device': _sessionTitle(s)}), _t('session_end'));
    if (yes != true) return;
    try {
      await kit.api.revokeSession(s.id);
      setState(() => _sessions = _sessions?.where((x) => x.id != s.id).toList());
    } catch (e) {
      if (mounted) necsouraToast(context, e.toString(), error: true);
    }
  }

  Future<void> _revokeOthers() async {
    final yes = await _confirm(_t('sessions_end_all_q'), _t('sessions_end_all'));
    if (yes != true) return;
    try {
      final n = await kit.api.revokeOtherSessions();
      if (mounted) necsouraToast(context, _t('sessions_ended', {'n': '$n'}));
      _reloadSessions();
    } catch (e) {
      if (mounted) necsouraToast(context, e.toString(), error: true);
    }
  }

  Future<void> _logout() async {
    final yes = await _confirm(_t('logout_q'), _t('logout'));
    if (yes == true && mounted) await kit.logout(context);
  }

  // ── Общие окна ──

  Future<T?> _sheet<T>({required String title, required Widget Function(BuildContext ctx, void Function([T? value]) close) builder}) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1A1A20) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: scheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(title,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface, fontFamily: kit.brand.fontFamily)),
                      const SizedBox(height: 18),
                      builder(ctx, ([T? v]) => Navigator.of(ctx).pop(v)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _confirm(String text, String action) {
    return _sheet<bool>(
      title: text,
      builder: (ctx, close) => Row(
        children: [
          Expanded(child: NecsouraButton(text: _t('cancel'), accent: accent, outlined: true, autofocus: true, onPressed: () => close(false))),
          const SizedBox(width: 12),
          Expanded(child: NecsouraButton(text: action, accent: accent, color: Theme.of(ctx).colorScheme.error, onPressed: () => close(true))),
        ],
      ),
    );
  }

  // ── Вид ──

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.onSurface),
        title: const NecsouraLockup(height: 22),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _profile == null
            ? Center(
                key: const ValueKey('wait'),
                child: _error == null
                    ? CircularProgressIndicator(color: accent)
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 48, color: scheme.onSurface.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface.withOpacity(0.7))),
                            const SizedBox(height: 18),
                            SizedBox(width: 220, child: NecsouraButton(text: _t('retry'), accent: accent, autofocus: true, onPressed: _load)),
                          ],
                        ),
                      ),
              )
            : FocusTraversalGroup(
                key: const ValueKey('ready'),
                child: RefreshIndicator(
                  color: accent,
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 90),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(width: 240, child: _header()),
                                    const SizedBox(width: 24),
                                    Expanded(child: _sections()),
                                  ],
                                )
                              : Column(children: [_header(), const SizedBox(height: 22), _sections()]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _header() {
    final p = _profile!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        NecsouraPressable(
          accent: accent,
          radius: BorderRadius.circular(70),
          onTap: _editAvatar,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [accent, kit.brand.accentDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: NecsouraAvatar(key: ValueKey(p.avatarUrl), url: p.avatarUrl, name: p.displayName, accent: accent, size: 116),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                  ),
                  child: _avatarBusy
                      ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.photo_camera_rounded, size: 17, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            p.displayName,
            key: ValueKey(p.displayName),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface, fontFamily: kit.brand.fontFamily),
          ),
        ),
        const SizedBox(height: 4),
        if (p.handle.isNotEmpty) Text(p.handle, style: TextStyle(fontSize: 15, color: scheme.onSurface.withOpacity(0.55))),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NecsouraLogo(size: 16),
              const SizedBox(width: 6),
              Text(_t('account_badge'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: accent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sections() {
    final p = _profile!;
    final scheme = Theme.of(context).colorScheme;
    final sessions = _sessions ?? const <NecsouraSession>[];
    final canScan = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NecsouraGroup(title: _t('section_profile'), children: [
          NecsouraTile(
            icon: Icons.badge_outlined,
            title: _t('name'),
            subtitle: p.name ?? _t('name_empty'),
            accent: accent,
            autofocus: true,
            onTap: _editName,
          ),
          NecsouraTile(
            icon: Icons.alternate_email_rounded,
            title: _t('username'),
            subtitle: p.username != null ? '@${p.username}' : _t('username_empty', {'id': p.handle}),
            accent: accent,
            onTap: _editUsername,
          ),
          NecsouraTile(
            icon: Icons.account_circle_outlined,
            title: _t('photo'),
            subtitle: _t('photo_hint'),
            accent: accent,
            onTap: _editAvatar,
          ),
        ]),
        NecsouraGroup(title: _t('section_security'), children: [
          // Логин нужен только для входа и виден только владельцу — как имя аккаунта в Steam
          NecsouraTile(
            icon: Icons.lock_person_outlined,
            title: _t('login'),
            subtitle: '${p.login} · ${_t('login_private')}',
            accent: accent,
          ),
          NecsouraTile(
            icon: Icons.mail_outline_rounded,
            title: _t('email'),
            subtitle: p.email == null ? _t('email_none') : '${p.email} · ${p.emailVerified ? _t('email_verified') : _t('email_unverified')}',
            accent: accent,
            trailing: p.email != null && !p.emailVerified
                ? Icon(Icons.error_outline_rounded, color: Colors.orange.shade400, size: 22)
                : null,
            onTap: _email,
          ),
          ...?kit.extraSecurity?.call(context),
        ]),
        NecsouraGroup(title: _t('section_signin'), children: [
          NecsouraTile(
            icon: Icons.password_rounded,
            title: _t('password'),
            subtitle: _ids?.hasPassword == false ? _t('password_not_set') : _t('password_set'),
            accent: accent,
            onTap: _changePassword,
          ),
          for (final provider in necsouraSocialProviders()) _providerTile(provider),
        ]),
        NecsouraGroup(title: _t('section_devices'), children: [
          if (canScan)
            NecsouraTile(
              icon: Icons.qr_code_scanner_rounded,
              title: _t('qr_scan'),
              subtitle: _t('qr_scan_hint'),
              accent: accent,
              onTap: _scanQr,
            ),
          if (_sessions == null)
            Padding(padding: const EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2)))
          else
            for (final s in sessions)
              NecsouraTile(
                icon: _sessionIcon(s),
                title: _sessionTitle(s),
                subtitle: _sessionSubtitle(s),
                accent: accent,
                trailing: s.current
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: Text(_t('this_device'), style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
                      )
                    : Icon(Icons.close_rounded, color: scheme.onSurface.withOpacity(0.4), size: 20),
                onTap: s.current ? null : () => _revoke(s),
              ),
          if (sessions.where((s) => !s.current).length > 1)
            NecsouraTile(
              icon: Icons.logout_rounded,
              title: _t('sessions_end_all'),
              accent: accent,
              color: scheme.error,
              onTap: _revokeOthers,
            ),
        ]),
        NecsouraButton(text: _t('logout'), accent: accent, outlined: true, color: scheme.error, icon: Icons.logout_rounded, onPressed: _logout),
      ],
    );
  }

  Widget _providerTile(String p) {
    final scheme = Theme.of(context).colorScheme;
    final linked = _ids?.linked[p];
    final who = [linked?.name, linked?.email].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return NecsouraPressable(
      accent: accent,
      radius: BorderRadius.circular(18),
      onTap: _ids == null ? null : () => _toggleProvider(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(width: 32, height: 32, child: Center(child: NecsouraProviderIcon(provider: p, size: 28))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(necsouraProviderName(p), style: TextStyle(fontSize: 16, color: scheme.onSurface, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    linked != null ? (who.isEmpty ? _t('social_linked_short') : who) : _t('social_not_linked'),
                    style: TextStyle(fontSize: 13, color: linked != null ? accent : scheme.onSurface.withOpacity(0.55)),
                  ),
                ],
              ),
            ),
            if (_linking == p)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Container(
                  key: ValueKey(linked != null),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: linked != null ? accent.withOpacity(0.15) : scheme.onSurface.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    linked != null ? _t('social_unlink') : _t('social_link'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: linked != null ? accent : scheme.onSurface.withOpacity(0.75)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _sessionIcon(NecsouraSession s) {
    final p = s.platform.toLowerCase();
    if (s.deviceType == 'tv' || p.contains('tizen') || p.contains('tv')) return Icons.tv_rounded;
    if (p.contains('android') || p.contains('ios')) return Icons.smartphone_rounded;
    if (p.contains('mac')) return Icons.laptop_mac_rounded;
    if (p.contains('web')) return Icons.language_rounded;
    return Icons.computer_rounded;
  }

  String _sessionTitle(NecsouraSession s) {
    final name = s.deviceName.trim();
    if (name.isNotEmpty) return name;
    return s.platform.isEmpty || s.platform == 'unknown' ? _t('device_unknown') : s.platform;
  }

  String _sessionSubtitle(NecsouraSession s) {
    final parts = <String>[NecsouraBrand.serviceName(s.service)];
    if (s.current) {
      parts.add(_t('online'));
    } else if (s.lastActiveAt != null) {
      parts.add(_ago(s.lastActiveAt!));
    }
    if (s.location != null && s.location!.isNotEmpty && s.location != 'Unknown') parts.add(s.location!);
    return parts.join(' · ');
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 2) return _t('online');
    if (d.inHours < 1) return _t('ago_min', {'n': '${d.inMinutes}'});
    if (d.inDays < 1) return _t('ago_hour', {'n': '${d.inHours}'});
    if (d.inDays < 30) return _t('ago_day', {'n': '${d.inDays}'});
    return DateFormat.yMMMd(context.locale.toLanguageTag()).format(t);
  }
}

class _NameForm extends StatefulWidget {
  final TextEditingController controller;
  final Color accent;
  final ValueChanged<String> onSave;
  final String? hint;
  final String? label;
  final IconData icon;
  final String? Function(String?)? validator;
  const _NameForm({
    required this.controller,
    required this.accent,
    required this.onSave,
    this.hint,
    this.label,
    this.icon = Icons.badge_outlined,
    this.validator,
  });

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  final _form = GlobalKey<FormState>();

  void _save() {
    if (_form.currentState!.validate()) widget.onSave(widget.controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.hint ?? _t('name_where'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 14)),
          const SizedBox(height: 14),
          NecsouraField(
            controller: widget.controller,
            label: widget.label ?? _t('name'),
            icon: widget.icon,
            accent: widget.accent,
            autofocus: true,
            action: TextInputAction.done,
            onSubmitted: (_) => _save(),
            validator: widget.validator ?? (v) {
              final s = (v ?? '').trim();
              if (s.length < 2) return _t('name_short');
              if (s.length > 50) return _t('name_long');
              return null;
            },
          ),
          const SizedBox(height: 18),
          NecsouraButton(text: _t('save'), accent: widget.accent, onPressed: _save),
        ],
      ),
    );
  }
}

class _PasswordForm extends StatefulWidget {
  final String login;
  final Color accent;
  final VoidCallback onDone;
  const _PasswordForm({required this.login, required this.accent, required this.onDone});

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final kit = NecsouraKit.instance;
      final r = await kit.api.changePassword(widget.login, _old.text, _new.text);
      await kit.onPasswordChanged?.call(r.keys, r.version);
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NecsouraField(
            controller: _old,
            label: _t('password_current'),
            icon: Icons.lock_outline_rounded,
            accent: widget.accent,
            password: true,
            autofocus: true,
            action: TextInputAction.next,
            validator: (v) => (v ?? '').isEmpty ? _t('enter_password') : null,
          ),
          const SizedBox(height: 12),
          NecsouraField(
            controller: _new,
            label: _t('password_new'),
            icon: Icons.lock_reset_rounded,
            accent: widget.accent,
            password: true,
            action: TextInputAction.next,
            validator: (v) => (v ?? '').length < 8 ? _t('password_short') : null,
          ),
          const SizedBox(height: 12),
          NecsouraField(
            controller: _repeat,
            label: _t('password_repeat'),
            icon: Icons.lock_reset_rounded,
            accent: widget.accent,
            password: true,
            action: TextInputAction.done,
            onSubmitted: (_) => _save(),
            validator: (v) => v != _new.text ? _t('password_mismatch') : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 18),
          NecsouraButton(text: _t('save'), accent: widget.accent, loading: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

class _EmailForm extends StatefulWidget {
  final NecsouraProfile profile;
  final Color accent;
  final ValueChanged<String> onChanged;
  const _EmailForm({required this.profile, required this.accent, required this.onChanged});

  @override
  State<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<_EmailForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _sending = true);
    try {
      await NecsouraKit.instance.api.sendVerificationEmail();
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _change() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = await NecsouraKit.instance.api.changeEmail(widget.profile.login, _email.text, _password.text);
      widget.onChanged(email);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.email != null) ...[
            Row(
              children: [
                Icon(p.emailVerified ? Icons.verified_rounded : Icons.error_outline_rounded,
                    color: p.emailVerified ? widget.accent : Colors.orange.shade400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${p.email}\n${p.emailVerified ? _t('email_verified') : _t('email_unverified')}',
                      style: TextStyle(color: scheme.onSurface, height: 1.4)),
                ),
              ],
            ),
            if (!p.emailVerified) ...[
              const SizedBox(height: 12),
              NecsouraButton(
                text: _sent ? _t('email_sent') : _t('email_send'),
                accent: widget.accent,
                outlined: true,
                loading: _sending,
                icon: _sent ? Icons.mark_email_read_outlined : Icons.send_rounded,
                onPressed: _sent ? null : _verify,
              ),
            ],
            const SizedBox(height: 22),
          ],
          Text(_t('email_change'), style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
          const SizedBox(height: 12),
          NecsouraField(
            controller: _email,
            label: _t('email_new'),
            icon: Icons.mail_outline_rounded,
            accent: widget.accent,
            keyboardType: TextInputType.emailAddress,
            action: TextInputAction.next,
            validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim()) ? null : _t('email_bad'),
          ),
          const SizedBox(height: 12),
          NecsouraField(
            controller: _password,
            label: _t('password_current'),
            icon: Icons.lock_outline_rounded,
            accent: widget.accent,
            password: true,
            action: TextInputAction.done,
            onSubmitted: (_) => _change(),
            validator: (v) => (v ?? '').isEmpty ? _t('enter_password') : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 18),
          NecsouraButton(text: _t('save'), accent: widget.accent, loading: _busy, onPressed: _change),
        ],
      ),
    );
  }
}
