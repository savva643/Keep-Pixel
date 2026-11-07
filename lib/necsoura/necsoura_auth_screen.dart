import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'necsoura_api.dart';
import 'necsoura_kit.dart';
import 'necsoura_social_ui.dart';
import 'necsoura_ui.dart';

String _t(String key, [Map<String, String>? args]) => 'necsoura.$key'.tr(namedArgs: args);

/// Вход и регистрация Necsoura — один экран для всех приложений, свой только цвет.
/// Широкий экран (компьютер, телевизор): слева витрина экосистемы, справа форма, по умолчанию QR-код.
/// Телефон: всё в одну колонку, по умолчанию пароль.
class NecsouraAuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final bool startWithRegister;

  const NecsouraAuthScreen({super.key, required this.onSuccess, this.startWithRegister = false});

  @override
  State<NecsouraAuthScreen> createState() => _NecsouraAuthScreenState();
}

enum _Mode { password, qr, register }

class _NecsouraAuthScreenState extends State<NecsouraAuthScreen> {
  NecsouraKit get kit => NecsouraKit.instance;
  _Mode? _mode;
  bool _busy = false;
  String? _error;

  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _rLogin = TextEditingController();
  final _rEmail = TextEditingController();
  final _rPassword = TextEditingController();
  final _rConfirm = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    for (final c in [_login, _password, _rLogin, _rEmail, _rPassword, _rConfirm]) {
      c.dispose();
    }
    _passwordFocus.dispose();
    super.dispose();
  }

  void _setMode(_Mode m) {
    if (_mode == m) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = m;
      _error = null;
    });
  }

  Future<void> _run(Future<NecsouraAuthOutcome> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await action();
      if (!mounted) return;
      switch (r.status) {
        case NecsouraAuthStatus.success:
          _done();
        case NecsouraAuthStatus.twoFactor:
          if (await kit.twoFactor(context) && mounted) _done();
        case NecsouraAuthStatus.failure:
          setState(() => _error = r.error);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done() {
    TextInput.finishAutofillContext();
    widget.onSuccess();
  }

  void _submitLogin() {
    if (!_loginForm.currentState!.validate()) return;
    _run(() => kit.login(_login.text.trim(), _password.text));
  }

  void _submitRegister() {
    if (!_registerForm.currentState!.validate()) return;
    _run(() => kit.register(_rLogin.text.trim(), _rEmail.text.trim(), _rPassword.text));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    _mode ??= widget.startWithRegister ? _Mode.register : (wide ? _Mode.qr : _Mode.password);
    final brand = kit.brand;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NecsouraBackdrop(
        brand: brand,
        child: FocusTraversalGroup(
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 5, child: _BrandPanel(brand: brand, register: _mode == _Mode.register)),
                    Expanded(
                      flex: 4,
                      child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(40), child: _card(wide)))),
                    ),
                  ],
                )
              : SafeArea(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.translucent,
                    child: Center(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                if (Navigator.of(context).canPop()) _BackButton(accent: brand.accent) else const SizedBox(width: 44),
                                const Spacer(),
                                const NecsouraLockup(height: 24),
                                const Spacer(),
                                const SizedBox(width: 44),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _card(wide),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _card(bool wide) {
    final brand = kit.brand;
    final scheme = Theme.of(context).colorScheme;
    final register = _mode == _Mode.register;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide && Navigator.of(context).canPop())
            Align(alignment: Alignment.centerLeft, child: _BackButton(accent: brand.accent)),
          if (wide) const SizedBox(height: 12),
          // «Вход в blast!» — название приложения его цветом
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: c),
            ),
            child: Text.rich(
              key: ValueKey(register),
              TextSpan(children: [
                TextSpan(text: register ? _t('register_to') : _t('login_to')),
                const TextSpan(text: ' '),
                TextSpan(text: brand.appName, style: TextStyle(color: brand.accent, fontWeight: FontWeight.w900)),
              ]),
              textAlign: wide ? TextAlign.left : TextAlign.center,
              // Montserrat Black (900) — как надпись в логотипе
              style: TextStyle(fontSize: wide ? 36 : 30, fontWeight: FontWeight.w900, color: scheme.onSurface, fontFamily: brand.fontFamily, height: 1.15, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t('one_account'),
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: TextStyle(fontSize: 15, color: scheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 26),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: register
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: NecsouraSegmented(
                      accent: brand.accent,
                      index: _mode == _Mode.qr ? 1 : 0,
                      items: [(icon: Icons.password_rounded, label: _t('tab_password')), (icon: Icons.qr_code_2_rounded, label: _t('tab_qr'))],
                      onChanged: (i) => _setMode(i == 1 ? _Mode.qr : _Mode.password),
                    ),
                  ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
              transitionBuilder: (child, a) {
                final fromRight = child.key == const ValueKey(_Mode.register) || child.key == const ValueKey(_Mode.qr);
                return FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: Offset(fromRight ? 0.08 : -0.08, 0), end: Offset.zero).animate(a),
                    child: child,
                  ),
                );
              },
              child: switch (_mode!) {
                _Mode.password => KeyedSubtree(key: const ValueKey(_Mode.password), child: _passwordForm()),
                _Mode.qr => KeyedSubtree(
                    key: const ValueKey(_Mode.qr),
                    child: NecsouraQrPanel(onApproved: (payload) async {
                      if (payload.isNotEmpty) await kit.applySession(payload);
                      if (mounted) _done();
                    }),
                  ),
                _Mode.register => KeyedSubtree(key: const ValueKey(_Mode.register), child: _registerFormView()),
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: scheme.error.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 14))),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(register ? _t('have_account') : _t('no_account'), style: TextStyle(color: scheme.onSurface.withOpacity(0.6))),
                TextButton(
                  onPressed: () => _setMode(register ? (wide ? _Mode.qr : _Mode.password) : _Mode.register),
                  style: TextButton.styleFrom(foregroundColor: brand.accent),
                  child: Text(register ? _t('sign_in') : _t('sign_up'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordForm() {
    final accent = kit.brand.accent;
    return AutofillGroup(
      child: Form(
        key: _loginForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NecsouraField(
              controller: _login,
              label: _t('login_or_email'),
              icon: Icons.person_outline_rounded,
              accent: accent,
              action: TextInputAction.next,
              autofill: const [AutofillHints.username, AutofillHints.email],
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              validator: (v) => (v ?? '').trim().isEmpty ? _t('enter_login') : null,
            ),
            const SizedBox(height: 14),
            NecsouraField(
              controller: _password,
              focusNode: _passwordFocus,
              label: _t('password'),
              icon: Icons.lock_outline_rounded,
              accent: accent,
              password: true,
              action: TextInputAction.done,
              autofill: const [AutofillHints.password],
              onSubmitted: (_) => _submitLogin(),
              validator: (v) => (v ?? '').isEmpty ? _t('enter_password') : null,
            ),
            if (kit.forgotPassword != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => kit.forgotPassword!(context, _login.text.trim()),
                  style: TextButton.styleFrom(foregroundColor: accent),
                  child: Text(_t('forgot')),
                ),
              )
            else
              const SizedBox(height: 18),
            NecsouraButton(text: _t('sign_in'), accent: accent, loading: _busy, onPressed: _submitLogin),
            NecsouraSocialRow(onSignedIn: _done, onError: (e) => setState(() => _error = e)),
          ],
        ),
      ),
    );
  }

  Widget _registerFormView() {
    final accent = kit.brand.accent;
    final scheme = Theme.of(context).colorScheme;
    return AutofillGroup(
      child: Form(
        key: _registerForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NecsouraField(
              controller: _rLogin,
              label: _t('login'),
              icon: Icons.alternate_email_rounded,
              accent: accent,
              action: TextInputAction.next,
              autofill: const [AutofillHints.newUsername],
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.length < 3) return _t('login_short');
                if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(s)) return _t('login_chars');
                return null;
              },
            ),
            const SizedBox(height: 14),
            NecsouraField(
              controller: _rEmail,
              label: _t('email'),
              icon: Icons.mail_outline_rounded,
              accent: accent,
              keyboardType: TextInputType.emailAddress,
              action: TextInputAction.next,
              autofill: const [AutofillHints.email],
              validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim()) ? null : _t('email_bad'),
            ),
            const SizedBox(height: 14),
            NecsouraField(
              controller: _rPassword,
              label: _t('password'),
              icon: Icons.lock_outline_rounded,
              accent: accent,
              password: true,
              action: TextInputAction.next,
              autofill: const [AutofillHints.newPassword],
              validator: (v) => (v ?? '').length < 8 ? _t('password_short') : null,
            ),
            const SizedBox(height: 14),
            NecsouraField(
              controller: _rConfirm,
              label: _t('password_repeat'),
              icon: Icons.lock_reset_rounded,
              accent: accent,
              password: true,
              action: TextInputAction.done,
              onSubmitted: (_) => _submitRegister(),
              validator: (v) => v != _rPassword.text ? _t('password_mismatch') : null,
            ),
            const SizedBox(height: 14),
            Text(_t('terms'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 14),
            NecsouraButton(text: _t('create_account'), accent: accent, loading: _busy, onPressed: _submitRegister),
            NecsouraSocialRow(onSignedIn: _done, onError: (e) => setState(() => _error = e)),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final Color accent;
  const _BackButton({required this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NecsouraPressable(
      accent: accent,
      radius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: scheme.onSurface.withOpacity(0.07), borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: scheme.onSurface),
      ),
    );
  }
}

/// Витрина на широком экране: знак Necsoura, подпись и сервисы экосистемы (текущее — крупнее)
class _BrandPanel extends StatelessWidget {
  final NecsouraBrand brand;
  final bool register;
  const _BrandPanel({required this.brand, required this.register});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand.accent, brand.accentDeep],
        ),
        boxShadow: [BoxShadow(color: brand.accent.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Крупная полупрозрачная «N» на фоне
            Positioned(
              right: -80,
              bottom: -80,
              child: Opacity(opacity: 0.12, child: Image.asset(NecsouraBrand.logo, width: 420, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NecsouraLockup(height: 32, color: Colors.white),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      register ? _t('brand_register') : _t('brand_login'),
                      key: ValueKey(register),
                      style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, fontFamily: brand.fontFamily, height: 1.1, letterSpacing: -0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_t('brand_sub'), style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 17, height: 1.4)),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      for (final s in NecsouraBrand.services.values) ...[
                        _ServiceIcon(icon: s.icon, name: s.name, current: s.name == brand.appName),
                        const SizedBox(width: 18),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  final String icon;
  final String name;
  final bool current;
  const _ServiceIcon({required this.icon, required this.name, required this.current});

  @override
  Widget build(BuildContext context) {
    final size = current ? 64.0 : 52.0;
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.12),
          // Значки на прозрачном фоне — лёгкое «стекло» вместо чёрных квадратов
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(current ? 0.22 : 0.1),
            borderRadius: BorderRadius.circular(size * 0.3),
            border: Border.all(color: Colors.white.withOpacity(current ? 0.8 : 0.18), width: current ? 2 : 1),
          ),
          child: Image.asset(icon, fit: BoxFit.contain),
        ),
        const SizedBox(height: 8),
        Text(name, style: TextStyle(color: Colors.white.withOpacity(current ? 1 : 0.7), fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// QR-код для входа: настоящий код auth-service, обновляется сам, показывает, что его отсканировали.
/// Отсканировать можно в любом приложении Necsoura, где уже выполнен вход (blast!, Kompot).
class NecsouraQrPanel extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> payload) onApproved;
  const NecsouraQrPanel({super.key, required this.onApproved});

  @override
  State<NecsouraQrPanel> createState() => _NecsouraQrPanelState();
}

class _NecsouraQrPanelState extends State<NecsouraQrPanel> with SingleTickerProviderStateMixin {
  NecsouraQrTicket? _ticket;
  String _status = 'loading'; // loading, pending, scanned, rejected, error, approved
  Timer? _poll;
  late final AnimationController _life = AnimationController(vsync: this);
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _life.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _poll?.cancel();
    setState(() => _status = 'loading');
    final flow = NecsouraKit.instance.qrFlow;
    if (flow != null) return _startCustom(flow);
    try {
      final t = await NecsouraKit.instance.api.qrStart();
      if (_disposed) return;
      setState(() {
        _ticket = t;
        _status = 'pending';
      });
      // Полоса жизни кода: когда закончится — новый код
      _life
        ..duration = t.expiresIn - const Duration(seconds: 3)
        ..forward(from: 0).whenComplete(() {
          if (!_disposed && _ticket == t && _status != 'approved') _start();
        });
      _schedule(t);
    } catch (_) {
      if (!_disposed) setState(() => _status = 'error');
    }
  }

  /// Вход по QR силами приложения: оно само опрашивает сервер и входит, мы только рисуем код
  Future<void> _startCustom(Future<void> Function({required void Function(String) onQr, required bool Function() isCancelled}) flow) async {
    try {
      await flow(
        isCancelled: () => _disposed,
        onQr: (data) {
          if (_disposed) return;
          setState(() {
            _ticket = NecsouraQrTicket(data, '', const Duration(minutes: 2), data: data);
            _status = 'pending';
          });
          _life
            ..duration = const Duration(seconds: 117)
            ..forward(from: 0);
        },
      );
      if (!_disposed) setState(() => _status = 'approved');
      await widget.onApproved(const {});
    } catch (_) {
      if (!_disposed) setState(() => _status = 'error');
    }
  }

  void _schedule(NecsouraQrTicket t) {
    _poll = Timer(const Duration(seconds: 2), () async {
      if (_disposed || _ticket != t) return;
      final r = await NecsouraKit.instance.api.qrPoll(t);
      if (_disposed || _ticket != t) return;
      final s = r['status']?.toString() ?? 'error';
      if (s == 'approved') {
        _life.stop();
        setState(() => _status = 'approved');
        await widget.onApproved(r);
        return;
      }
      if (s == 'expired') return _start();
      if (s == 'rejected') {
        setState(() => _status = 'rejected');
        Timer(const Duration(milliseconds: 1800), () => !_disposed ? _start() : null);
        return;
      }
      if (s == 'scanned' || s == 'pending') {
        if (s != _status) setState(() => _status = s);
      }
      _schedule(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = NecsouraKit.instance.brand;
    final scheme = Theme.of(context).colorScheme;
    final ticket = _ticket;
    final dim = _status == 'scanned' || _status == 'rejected' || _status == 'approved';
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 264,
            height: 264,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Сколько живёт код — кольцо вокруг
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _life,
                    builder: (_, __) => CustomPaint(painter: _LifeRing(1 - _life.value, brand.accent, scheme.onSurface.withOpacity(0.08))),
                  ),
                ),
                Container(
                  width: 236,
                  height: 236,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _status == 'error'
                        ? Center(key: const ValueKey('e'), child: Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black.withOpacity(0.4)))
                        : ticket == null || _status == 'loading'
                            ? Center(key: const ValueKey('l'), child: CircularProgressIndicator(color: brand.accent, strokeWidth: 2.5))
                            : AnimatedOpacity(
                                key: ValueKey(ticket.sessionId),
                                opacity: dim ? 0.12 : 1,
                                duration: const Duration(milliseconds: 250),
                                child: QrImageView(
                                  data: ticket.qrData,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF111114)),
                                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF111114)),
                                  embeddedImage: const AssetImage(NecsouraBrand.logo),
                                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(44, 44)),
                                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                                ),
                              ),
                  ),
                ),
                // Отсканировали / отклонили — значок поверх
                AnimatedScale(
                  scale: dim ? 1 : 0,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _status == 'rejected' ? scheme.error : brand.accent,
                      boxShadow: [BoxShadow(color: (_status == 'rejected' ? scheme.error : brand.accent).withOpacity(0.4), blurRadius: 20)],
                    ),
                    child: Icon(
                      _status == 'rejected' ? Icons.close_rounded : (_status == 'approved' ? Icons.check_rounded : Icons.phonelink_ring_rounded),
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            switch (_status) {
              'scanned' => _t('qr_scanned'),
              'rejected' => _t('qr_rejected'),
              'approved' => _t('qr_approved'),
              'error' => _t('qr_error'),
              _ => _t('qr_title'),
            },
            key: ValueKey(_status),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface, fontFamily: brand.fontFamily),
          ),
        ),
        const SizedBox(height: 14),
        if (_status == 'error')
          NecsouraButton(text: _t('retry'), accent: brand.accent, icon: Icons.refresh_rounded, onPressed: _start)
        else
          for (final (i, step) in [_t('qr_step1'), _t('qr_step2'), _t('qr_step3')].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: brand.accent.withOpacity(0.16), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: TextStyle(color: brand.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(step, style: TextStyle(fontSize: 14.5, height: 1.35, color: scheme.onSurface.withOpacity(0.75)))),
                ],
              ),
            ),
      ],
    );
  }
}

class _LifeRing extends CustomPainter {
  final double left;
  final Color color;
  final Color track;
  _LifeRing(this.left, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(32)).deflate(2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(r, paint..color = track);
    final path = Path()..addRRect(r);
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * left.clamp(0.0, 1.0)), paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_LifeRing old) => old.left != left || old.color != color;
}
