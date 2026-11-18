import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/installer.dart';
import '../core/models.dart';
import '../necsoura/necsoura_account_screen.dart';
import 'auth_dialog.dart';
import 'game_actions.dart';
import 'profile.dart';
import 'two_factor.dart';
import 'shared.dart';

enum NavStyle { dock, top }

/// Same as the version in pubspec.yaml; a test keeps them equal.
const appVersion = '1.3.0';

enum SettingsSection {
  account('Аккаунт', Icons.account_circle_rounded, '',
      'Имя, почта, пароль и устройства'),
  profile(
      'Профиль',
      Icons.badge_rounded,
      'Что другие видят в Keep Pixel. В других сервисах профиль остаётся прежним.',
      'Фото, шапка и имя в Keep Pixel'),
  interface(
      'Интерфейс',
      Icons.tune_rounded,
      'Как выглядит и с чего открывается приложение.',
      'Меню и начальная страница'),
  games(
      'Игры',
      Icons.sports_esports_rounded,
      'Папки с играми на дисках. Новые игры ставятся в папку по умолчанию, при установке можно выбрать другую.',
      'Папки с играми на дисках'),
  storage(
      'Память',
      Icons.sd_storage_rounded,
      'Сколько места Keep Pixel занимает на телефоне.',
      'Место на телефоне и кэш'),
  about('О программе', Icons.info_rounded, '', 'Версия и ссылки');

  final String label, description, hint;
  final IconData icon;
  const SettingsSection(this.label, this.icon, this.description, this.hint);
}

/// Settings: categories on the left, the chosen one on the right.
/// On a phone the categories are a list that opens each one as a page.
class SettingsView extends StatefulWidget {
  final PixelApi api;

  /// Null where games are not installed, as on the website.
  final GameInstaller? installer;
  final SettingsSection? section;

  /// Null where the player has no choice of menu or start page.
  final NavStyle? navStyle;
  final ValueChanged<NavStyle>? onNavStyle;
  final int? startPage;
  final ValueChanged<int>? onStartPage;
  final VoidCallback onSignIn;
  final VoidCallback? onBack;
  const SettingsView(
      {super.key,
      required this.api,
      required this.installer,
      required this.onSignIn,
      this.section,
      this.navStyle,
      this.onNavStyle,
      this.startPage,
      this.onStartPage,
      this.onBack});
  @override
  State<SettingsView> createState() => SettingsViewState();
}

class SettingsViewState extends State<SettingsView> {
  late SettingsSection? selected = widget.section;
  Future<PixelProfile>? _profile;
  (int, int)? _profileVersion;

  void show(SettingsSection section) => setState(() => selected = section);

  /// The same profile for the account chip and the profile editor.
  Future<PixelProfile>? get profile {
    final api = widget.api;
    if (!api.signedIn) return null;
    final version = (api.sessionGeneration, api.profileRevision);
    if (version != _profileVersion) {
      _profileVersion = version;
      _profile = api.profile();
    }
    return _profile;
  }

  bool _available(SettingsSection section) => switch (section) {
        SettingsSection.interface =>
          widget.navStyle != null || widget.startPage != null,
        SettingsSection.games => widget.installer?.supported ?? false,
        SettingsSection.storage => widget.installer != null &&
            !widget.installer!.supported &&
            phoneSystem,
        _ => true,
      };

  Widget _pane(SettingsSection section) => switch (section) {
        SettingsSection.account =>
          _AccountPane(api: widget.api, onSignIn: widget.onSignIn),
        SettingsSection.profile => _ProfilePane(
            api: widget.api, profile: profile, onSignIn: widget.onSignIn),
        SettingsSection.interface => _InterfacePane(
            navStyle: widget.navStyle,
            onNavStyle: widget.onNavStyle,
            startPage: widget.startPage,
            onStartPage: widget.onStartPage),
        SettingsSection.games => _GamesPane(installer: widget.installer!),
        SettingsSection.storage => _StoragePane(installer: widget.installer!),
        SettingsSection.about => _AboutPane(api: widget.api),
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.api,
      builder: (context, _) => LayoutBuilder(
          builder: (context, box) =>
              box.maxWidth >= 640 ? _wide(context) : _narrow(context)));

  Widget _wide(BuildContext context) {
    final current = selected ?? SettingsSection.account;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          width: 236,
          decoration: const BoxDecoration(
              color: Kp.surface,
              border: Border(right: BorderSide(color: Kp.line))),
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (widget.onBack != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BackRow(label: 'Настройки', onBack: widget.onBack!)),
            _AccountChip(
                profile: profile,
                cached: widget.api.cachedProfile,
                onTap: () => show(SettingsSection.account)),
            const SizedBox(height: 12),
            for (final section in SettingsSection.values)
              if (_available(section))
                _SectionTile(
                    key: ValueKey('settings-${section.name}'),
                    section: section,
                    selected: section == current,
                    onTap: () => show(section)),
          ])),
      Expanded(
          child: KeyedSubtree(key: ValueKey(current), child: _pane(current))),
    ]);
  }

  Widget _narrow(BuildContext context) {
    final current = selected;
    return PopScope(
        // Pages of the shell stay built behind each other: only the visible
        // one may catch the back button.
        canPop: !TickerMode.valuesOf(context).enabled ||
            (current == null && widget.onBack == null),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (current != null) {
            setState(() => selected = null);
          } else {
            widget.onBack?.call();
          }
        },
        child: current == null
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                    if (widget.onBack != null)
                      _BackRow(label: 'Настройки', onBack: widget.onBack!)
                    else
                      const Text('Настройки', style: _pageTitle),
                    const SizedBox(height: 14),
                    _AccountChip(
                        profile: profile,
                        cached: widget.api.cachedProfile,
                        onTap: () => show(SettingsSection.account)),
                    const SizedBox(height: 14),
                    KpPanel(
                        padding: const EdgeInsets.all(6),
                        child: Column(children: [
                          for (final section in SettingsSection.values)
                            if (_available(section))
                              _SectionTile(
                                  key: ValueKey('settings-${section.name}'),
                                  section: section,
                                  selected: false,
                                  compact: true,
                                  onTap: () => show(section)),
                        ])),
                  ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _BackRow(
                        label: current.label,
                        onBack: () => setState(() => selected = null))),
                Expanded(
                    child: _Compact(
                        child: KeyedSubtree(
                            key: ValueKey(current), child: _pane(current)))),
              ]));
  }
}

const _pageTitle =
    TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.5);
const _note = TextStyle(color: muted, fontSize: 13, height: 1.6);

class _BackRow extends StatelessWidget {
  final String label;
  final VoidCallback onBack;
  const _BackRow({required this.label, required this.onBack});
  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(
            tooltip: 'Назад',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded)),
        const SizedBox(width: 4),
        Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3))),
      ]);
}

/// Marks a settings page shown on its own on a phone: the bar above already
/// names it, and the floating dock covers the bottom.
class _Compact extends InheritedWidget {
  const _Compact({required super.child});
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Compact>() != null;
  @override
  bool updateShouldNotify(_Compact old) => false;
}

class _SectionTile extends StatelessWidget {
  final SettingsSection section;
  final bool selected, compact;
  final VoidCallback onTap;
  const _SectionTile(
      {super.key,
      required this.section,
      required this.selected,
      required this.onTap,
      this.compact = false});
  @override
  Widget build(BuildContext context) => compact ? _phone() : _desktop();

  /// A phone row: the icon in its own tile, a hint and a chevron.
  Widget _phone() => Semantics(
      button: true,
      child: Hovered(
          onTap: onTap,
          builder: (context, hover) => AnimatedContainer(
              duration: Kp.motion,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                  borderRadius: Kp.r14,
                  color: hover ? Kp.raised : Colors.transparent),
              child: Row(children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        borderRadius: Kp.r14,
                        gradient: LinearGradient(colors: [
                          Kp.blue.withValues(alpha: .45),
                          Kp.violet.withValues(alpha: .45)
                        ])),
                    child: Icon(section.icon, size: 22, color: Colors.white)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(section.label,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(section.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 12)),
                    ])),
                const Icon(Icons.chevron_right_rounded,
                    size: 22, color: Kp.muted),
              ]))));

  Widget _desktop() => Semantics(
      button: true,
      selected: selected,
      child: Hovered(
          onTap: onTap,
          builder: (context, hover) => AnimatedContainer(
              duration: Kp.motion,
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                  borderRadius: Kp.r14,
                  gradient: selected ? Kp.gradient : null,
                  color: selected
                      ? null
                      : hover
                          ? Kp.raised
                          : Colors.transparent),
              child: Row(children: [
                Icon(section.icon,
                    size: 19,
                    color: selected
                        ? Colors.white
                        : hover
                            ? Kp.lilac
                            : Kp.muted),
                const SizedBox(width: 11),
                Expanded(
                    child: Text(section.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : Kp.text))),
              ]))));
}

/// Who is signed in, at the top of the categories.
class _AccountChip extends StatelessWidget {
  final Future<PixelProfile>? profile;
  final PixelProfile? cached;
  final VoidCallback onTap;
  const _AccountChip({required this.profile, required this.onTap, this.cached});
  @override
  Widget build(BuildContext context) => FutureBuilder<PixelProfile>(
      future: profile,
      initialData: cached,
      builder: (context, state) {
        final p = profile == null ? null : state.data ?? cached;
        final signedOut = profile == null;
        return Hovered(
            onTap: onTap,
            builder: (context, hover) => AnimatedContainer(
                duration: Kp.motion,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: hover ? Kp.raised : Kp.bg,
                    borderRadius: Kp.r14,
                    border: Border.all(color: Kp.line)),
                child: Row(children: [
                  SizedBox.square(
                      dimension: 40,
                      child: ClipOval(
                          child: signedOut
                              ? const ColoredBox(
                                  color: Kp.raised,
                                  child: Icon(Icons.person_rounded,
                                      color: Kp.muted))
                              : Artwork(p?.fields['avatar'] ?? '',
                                  label: p?.name ?? 'Keep Pixel'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            signedOut ? 'Войти' : p?.name ?? 'Аккаунт Necsoura',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                            p == null || p.username.isEmpty
                                ? 'Аккаунт Necsoura'
                                : '@${p.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 12)),
                      ])),
                ])));
      });
}

/// A scrolling category page with its title.
class _Pane extends StatelessWidget {
  final SettingsSection section;
  final List<Widget> children;
  const _Pane({required this.section, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final compact = _Compact.of(context);
        final gutter = box.maxWidth > 560 ? 28.0 : 16.0;
        return ListView(
            padding: EdgeInsets.fromLTRB(
                gutter, compact ? 8 : 22, gutter, compact ? 120 : 28),
            children: [
              Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!compact) ...[
                              Text(section.label, style: _pageTitle),
                              const SizedBox(height: 6),
                            ],
                            if (section.description.isNotEmpty)
                              Text(section.description, style: _note),
                            const SizedBox(height: 20),
                            ...children,
                          ]))),
            ]);
      });
}

/// A setting explained in a line or two.
class _Row extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _Row({required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          SelectableText(subtitle!, style: _note),
        ],
      ]));
}

/// One of several options, as a row with a radio mark.
class _Choice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  const _Choice(
      {required this.icon,
      required this.title,
      required this.selected,
      required this.onTap,
      this.subtitle});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      child: Hovered(
          onTap: onTap,
          builder: (context, hover) => AnimatedContainer(
              duration: Kp.motion,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: selected
                      ? Kp.violet.withValues(alpha: .14)
                      : hover
                          ? Kp.raised
                          : Kp.bg,
                  borderRadius: Kp.r14,
                  border: Border.all(
                      width: selected ? 1.5 : 1,
                      color: selected ? Kp.violet : Kp.line)),
              child: Row(children: [
                Icon(icon, color: selected ? Kp.lilac : Kp.muted),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: const TextStyle(color: muted, fontSize: 12)),
                      ],
                    ])),
                const SizedBox(width: 10),
                Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? Kp.lilac : Kp.muted),
              ]))));
}

/// A link or action in a list.
class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _LinkRow(
      {required this.icon,
      required this.title,
      required this.onTap,
      this.subtitle});
  @override
  Widget build(BuildContext context) => Hovered(
      onTap: onTap,
      builder: (context, hover) => AnimatedContainer(
          duration: Kp.motion,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
              borderRadius: Kp.r14, color: hover ? Kp.raised : null),
          child: Row(children: [
            Icon(icon, color: Kp.lilac),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(color: muted, fontSize: 12)),
                ])),
            const Icon(Icons.chevron_right_rounded, color: Kp.muted),
          ])));
}

/// The shared Necsoura account: the same screen as in blast! and Kompot, here
/// as a category. Changes in it apply to every service.
class _AccountPane extends StatelessWidget {
  final PixelApi api;
  final VoidCallback onSignIn;
  const _AccountPane({required this.api, required this.onSignIn});
  @override
  Widget build(BuildContext context) {
    if (!api.signedIn) {
      return StatePanel(
          icon: Icons.account_circle_outlined,
          title: 'Войди в аккаунт Necsoura',
          description:
              'Один аккаунт для Keep Pixel, blast! и Kompot: библиотека, друзья и профиль на любом устройстве.',
          action: 'Войти в Necsoura',
          onAction: onSignIn);
    }
    setupNecsoura(api);
    return LayoutBuilder(
        builder: (context, box) => MediaQuery(
            // The shared screen picks its layout from the width it is given.
            data: MediaQuery.of(context)
                .copyWith(size: Size(box.maxWidth, box.maxHeight)),
            // The shared screen focuses its first row for TV remotes. Here that
            // would only leave a stray outline, so something else takes focus.
            child: FocusScope(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Two-step verification belongs to the Necsoura account,
                  // so it sits here rather than among the app's settings.
                  Padding(
                      padding: EdgeInsets.fromLTRB(
                          16, _Compact.of(context) ? 4 : 20, 16, 0),
                      child: Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: TwoFactorTile(
                                  key: ValueKey(
                                      'twofa-${api.sessionGeneration}'),
                                  api: api)))),
                  Expanded(
                      child: Stack(fit: StackFit.expand, children: [
                    const Focus(autofocus: true, child: SizedBox.shrink()),
                    NecsouraAccountScreen(
                        key: ValueKey('account-${api.sessionGeneration}')),
                  ])),
                ]))));
  }
}

class _ProfilePane extends StatelessWidget {
  final PixelApi api;
  final Future<PixelProfile>? profile;
  final VoidCallback onSignIn;
  const _ProfilePane(
      {required this.api, required this.profile, required this.onSignIn});
  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return StatePanel(
          icon: Icons.badge_outlined,
          title: 'Твой профиль Keep Pixel',
          description:
              'Общие фото и имя Necsoura или своё оформление только для Keep Pixel.',
          action: 'Войти в Necsoura',
          onAction: onSignIn);
    }
    return FutureBuilder<PixelProfile>(
        future: profile,
        initialData: api.cachedProfile,
        builder: (context, state) {
          // While a saved profile reloads, the editor stays on screen.
          final p = state.data ?? api.cachedProfile;
          if (p == null) {
            if (state.hasError) {
              return StatePanel(
                  icon: Icons.cloud_off_rounded,
                  title: 'Профиль недоступен',
                  description: '${state.error}',
                  action: 'Повторить',
                  onAction: api.profileChanged);
            }
            return const Center(child: CircularProgressIndicator());
          }
          return _Pane(section: SettingsSection.profile, children: [
            ProfileEditor(
                key: ValueKey('${p.fields}${p.overrides}'),
                api: api,
                profile: p,
                onSaved: () {
                  api.profileChanged();
                  notice(context, 'Профиль Keep Pixel сохранён');
                }),
          ]);
        });
  }
}

class _InterfacePane extends StatelessWidget {
  final NavStyle? navStyle;
  final ValueChanged<NavStyle>? onNavStyle;
  final int? startPage;
  final ValueChanged<int>? onStartPage;
  const _InterfacePane(
      {required this.navStyle,
      required this.onNavStyle,
      required this.startPage,
      required this.onStartPage});
  @override
  Widget build(BuildContext context) =>
      _Pane(section: SettingsSection.interface, children: [
        if (navStyle != null) ...[
          const KpHeading('Меню'),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _MenuOption(
                style: NavStyle.dock,
                label: 'Плавающий док',
                selected: navStyle == NavStyle.dock,
                onTap: () => onNavStyle?.call(NavStyle.dock)),
            _MenuOption(
                style: NavStyle.top,
                label: 'Верхнее меню',
                selected: navStyle == NavStyle.top,
                onTap: () => onNavStyle?.call(NavStyle.top)),
          ]),
          const SizedBox(height: 28),
        ],
        if (startPage != null) ...[
          const KpHeading('Начальная страница'),
          const SizedBox(height: 8),
          const Text('Что открывать при запуске приложения.', style: _note),
          const SizedBox(height: 14),
          _Choice(
              icon: Icons.storefront_rounded,
              title: 'Магазин',
              subtitle: 'Новые и популярные игры',
              selected: startPage == 0,
              onTap: () => onStartPage?.call(0)),
          _Choice(
              icon: Icons.grid_view_rounded,
              title: 'Библиотека',
              subtitle: 'Сразу к своим играм',
              selected: startPage == 1,
              onTap: () => onStartPage?.call(1)),
        ],
      ]);
}

/// A small drawing of the window with the menu where this option puts it.
class _MenuOption extends StatelessWidget {
  final NavStyle style;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MenuOption(
      {required this.style,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final dock = style == NavStyle.dock;
    return Semantics(
        button: true,
        selected: selected,
        child: Hovered(
            onTap: onTap,
            builder: (context, hover) => AnimatedContainer(
                duration: Kp.motion,
                width: 216,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Kp.surface,
                    borderRadius: Kp.r20,
                    border: Border.all(
                        width: selected ? 2 : 1,
                        color: selected || hover ? Kp.violet : Kp.line)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 108,
                          decoration: const BoxDecoration(
                              color: Kp.bg, borderRadius: Kp.r10),
                          padding: const EdgeInsets.all(8),
                          child: Align(
                              alignment: dock
                                  ? Alignment.bottomCenter
                                  : Alignment.topCenter,
                              child: FractionallySizedBox(
                                  widthFactor: dock ? .62 : 1,
                                  child: Container(
                                      height: dock ? 16 : 12,
                                      decoration: BoxDecoration(
                                          gradient:
                                              selected ? Kp.gradient : null,
                                          color: selected ? null : Kp.line,
                                          borderRadius: BorderRadius.circular(
                                              dock ? 8 : 4)))))),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: Text(label,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700))),
                        if (selected)
                          const Icon(Icons.check_circle_rounded,
                              size: 18, color: Kp.lilac),
                      ]),
                    ]))));
  }
}

class _GamesPane extends StatefulWidget {
  final GameInstaller installer;
  const _GamesPane({required this.installer});
  @override
  State<_GamesPane> createState() => _GamesPaneState();
}

class _GamesPaneState extends State<_GamesPane> {
  late Future<List<LibraryFolder>> folders = widget.installer.libraries();
  bool busy = false;

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    setState(() => busy = true);
    try {
      await action();
      if (done != null && mounted) notice(context, done);
    } catch (e) {
      if (mounted) notice(context, '$e');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          folders = widget.installer.libraries();
        });
      }
    }
  }

  Future<void> _add() async {
    final drives = widget.installer.drives();
    final existing = await folders;
    if (!mounted) return;
    final chosen = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Новая папка с играми'),
                content: SizedBox(
                    width: 460,
                    child: FutureBuilder<List<Drive>>(
                        future: drives,
                        builder: (context, state) {
                          final list = state.data;
                          if (list == null) {
                            return const SizedBox(
                                height: 120,
                                child:
                                    Center(child: CircularProgressIndicator()));
                          }
                          return SingleChildScrollView(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                const Text(
                                    'Выбери диск: на нём появится папка KeepPixelLibrary.',
                                    style: _note),
                                const SizedBox(height: 12),
                                for (final d in list)
                                  _DriveTile(
                                      drive: d,
                                      taken: existing.any((f) =>
                                          f.drive ==
                                              d.root
                                                  .replaceAll(r'\', '')
                                                  .toUpperCase() &&
                                          !f.builtIn),
                                      onTap: () =>
                                          Navigator.pop(context, d.root)),
                                const SizedBox(height: 4),
                                OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 46)),
                                    onPressed: () async {
                                      final dir = await FilePicker.platform
                                          .getDirectoryPath(
                                              dialogTitle:
                                                  'Папка для игр Keep Pixel');
                                      if (dir != null && context.mounted) {
                                        Navigator.pop(context, dir);
                                      }
                                    },
                                    icon: const Icon(
                                        Icons.create_new_folder_rounded),
                                    label: const Text('Выбрать другую папку…')),
                              ]));
                        })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена')),
                ]));
    if (chosen == null) return;
    await _run(() => widget.installer.addLibrary(chosen),
        'Папка добавлена. Её можно выбрать при установке игры');
  }

  @override
  Widget build(BuildContext context) =>
      _Pane(section: SettingsSection.games, children: [
        FutureBuilder<List<LibraryFolder>>(
            future: folders,
            builder: (context, state) {
              final list = state.data;
              if (state.hasError) {
                return Text('${state.error}',
                    style: const TextStyle(color: Kp.error));
              }
              if (list == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final games = list.fold(0, (sum, f) => sum + f.games);
              final bytes = list.fold(0, (sum, f) => sum + f.bytes);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              games == 0
                                  ? 'Игр пока не установлено'
                                  : 'Установлено игр: $games · ${formatBytes(bytes)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      if (busy)
                        const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ]),
                    const SizedBox(height: 12),
                    for (final f in list)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LibraryTile(
                              folder: f,
                              trailing: _FolderMenu(
                                  folder: f,
                                  enabled: !busy,
                                  onDefault: () => _run(
                                      () => widget.installer
                                          .setDefaultLibrary(f.path),
                                      'Новые игры будут ставиться на ${f.drive}'),
                                  onOpen: () => _run(() =>
                                      widget.installer.openFolder(f.path)),
                                  onRemove: () => _run(
                                      () => widget.installer
                                          .removeLibrary(f.path),
                                      'Папка убрана из списка. Файлы на диске не тронуты')))),
                    const SizedBox(height: 4),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48)),
                            onPressed: busy ? null : _add,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Добавить папку на диске'))),
                    const SizedBox(height: 8),
                    const Text(
                        'Чтобы перенести установленную игру, нажми на неё в библиотеке правой кнопкой и выбери «Перенести на другой диск».',
                        style: _note),
                  ]);
            }),
        const SizedBox(height: 20),
        const KpPanel(
            child: _Row(
                title: 'Игровая панель',
                subtitle:
                    'Shift+Tab в игре открывает друзей и профиль поверх неё. Esc возвращает в игру.')),
      ]);
}

class _FolderMenu extends StatelessWidget {
  final LibraryFolder folder;
  final bool enabled;
  final VoidCallback onDefault, onOpen, onRemove;
  const _FolderMenu(
      {required this.folder,
      required this.enabled,
      required this.onDefault,
      required this.onOpen,
      required this.onRemove});
  @override
  Widget build(BuildContext context) => PopupMenuButton<VoidCallback>(
      tooltip: 'Действия с папкой',
      enabled: enabled,
      color: Kp.raised,
      shape: const RoundedRectangleBorder(
          borderRadius: Kp.r14, side: BorderSide(color: Kp.line)),
      onSelected: (action) => action(),
      icon: const Icon(Icons.more_vert_rounded),
      itemBuilder: (_) => [
            if (!folder.isDefault)
              PopupMenuItem(
                  value: onDefault,
                  child: const Text('Ставить новые игры сюда')),
            PopupMenuItem(value: onOpen, child: const Text('Открыть папку')),
            if (!folder.builtIn)
              PopupMenuItem(
                  value: onRemove,
                  enabled: folder.games == 0,
                  child: Text(folder.games == 0
                      ? 'Убрать из списка'
                      : 'Убрать из списка (сначала перенеси игры)')),
          ]);
}

class _DriveTile extends StatelessWidget {
  final Drive drive;
  final bool taken;
  final VoidCallback onTap;
  const _DriveTile(
      {required this.drive, required this.taken, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final free = drive.free, total = drive.total;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Hovered(
            onTap: taken ? null : onTap,
            builder: (context, hover) => AnimatedOpacity(
                duration: Kp.motion,
                opacity: taken ? .5 : 1,
                child: AnimatedContainer(
                    duration: Kp.motion,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: hover && !taken ? Kp.raised : Kp.bg,
                        borderRadius: Kp.r14,
                        border: Border.all(
                            color: hover && !taken ? Kp.violet : Kp.line)),
                    child: Row(children: [
                      const Icon(Icons.storage_rounded, color: Kp.lilac),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(drive.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                                taken
                                    ? 'Папка Keep Pixel уже есть'
                                    : free == null || total == null
                                        ? drive.root
                                        : 'Свободно ${formatBytes(free)} из ${formatBytes(total)}',
                                style: const TextStyle(
                                    color: muted, fontSize: 12)),
                            if (free != null && total != null && total > 0) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                      value: 1 - free / total,
                                      minHeight: 5,
                                      backgroundColor: Kp.line,
                                      color: Kp.indigo)),
                            ],
                          ])),
                    ])))));
  }
}

/// Android and iOS: no drives or folders to choose, only the phone's memory.
bool get phoneSystem =>
    !kIsWeb &&
    const {TargetPlatform.android, TargetPlatform.iOS}
        .contains(defaultTargetPlatform);

class _StoragePane extends StatefulWidget {
  final GameInstaller installer;
  const _StoragePane({required this.installer});
  @override
  State<_StoragePane> createState() => _StoragePaneState();
}

class _StoragePaneState extends State<_StoragePane> {
  late Future<PhoneStorage?> usage = widget.installer.phoneStorage();
  bool busy = false;

  Future<void> _clear() async {
    setState(() => busy = true);
    try {
      await widget.installer.clearCache();
      if (mounted) notice(context, 'Кэш очищен');
    } catch (e) {
      if (mounted) notice(context, '$e');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          usage = widget.installer.phoneStorage();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      _Pane(section: SettingsSection.storage, children: [
        FutureBuilder<PhoneStorage?>(
            future: usage,
            builder: (context, state) {
              final s = state.data;
              if (state.connectionState != ConnectionState.done) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
              }
              if (s == null) {
                return const Text('Не удалось узнать, сколько места занято',
                    style: _note);
              }
              final total = s.total, free = s.free;
              final known = total != null && free != null && total > 0;
              final other =
                  known ? (total - free - s.data - s.cache).clamp(0, total) : 0;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KpPanel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: [Kp.violet, Kp.blue]),
                                    borderRadius: Kp.r14),
                                child: const Icon(Icons.smartphone_rounded,
                                    color: Colors.white)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('Память телефона',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                      known
                                          ? 'Свободно ${formatBytes(free)} из ${formatBytes(total)}'
                                          : 'Keep Pixel занимает ${formatBytes(s.data + s.cache)}',
                                      style: _note),
                                ])),
                          ]),
                          if (known) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                    height: 12,
                                    child: LayoutBuilder(
                                        builder: (context, box) {
                                      double w(int bytes) =>
                                          box.maxWidth * bytes / total;
                                      return Stack(children: [
                                        Container(color: Kp.line),
                                        Row(children: [
                                          Container(
                                              width: w(other),
                                              color: Kp.muted
                                                  .withValues(alpha: .45)),
                                          Container(
                                              width: w(s.data)
                                                  .clamp(s.data > 0 ? 3 : 0,
                                                      box.maxWidth),
                                              color: Kp.violet),
                                          Container(
                                              width: w(s.cache)
                                                  .clamp(s.cache > 0 ? 3 : 0,
                                                      box.maxWidth),
                                              color: Kp.lilac),
                                        ]),
                                      ]);
                                    }))),
                          ],
                          const SizedBox(height: 14),
                          _UsageRow(
                              color: Kp.violet,
                              title: 'Keep Pixel',
                              subtitle: 'Вход, настройки и библиотека',
                              bytes: s.data),
                          _UsageRow(
                              color: Kp.lilac,
                              title: 'Кэш',
                              subtitle: 'Обложки и временные файлы',
                              bytes: s.cache),
                          if (known) ...[
                            _UsageRow(
                                color: Kp.muted.withValues(alpha: .45),
                                title: 'Другие приложения и файлы',
                                bytes: other),
                            _UsageRow(
                                color: Kp.line, title: 'Свободно', bytes: free),
                          ],
                        ])),
                    const SizedBox(height: 14),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50)),
                            onPressed: busy || s.cache == 0 ? null : _clear,
                            icon: busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.cleaning_services_rounded),
                            label: Text(s.cache == 0
                                ? 'Кэш пуст'
                                : 'Очистить кэш · ${formatBytes(s.cache)}'))),
                    const SizedBox(height: 10),
                    const Text(
                        'Очистка кэша не выходит из аккаунта и не трогает настройки: обложки загрузятся снова.',
                        style: _note),
                  ]);
            }),
      ]);
}

class _UsageRow extends StatelessWidget {
  final Color color;
  final String title;
  final String? subtitle;
  final int bytes;
  const _UsageRow(
      {required this.color,
      required this.title,
      required this.bytes,
      this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(color: muted, fontSize: 12)),
        ])),
        Text(formatBytes(bytes),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ]));
}

class _AboutPane extends StatelessWidget {
  final PixelApi api;
  const _AboutPane({required this.api});
  @override
  Widget build(BuildContext context) =>
      _Pane(section: SettingsSection.about, children: [
        KpPanel(
            child: Row(children: [
          Image.asset('assets/images/logo.png', width: 56, height: 56),
          const SizedBox(width: 16),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('keep pixel',
                    style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -.7)),
                SizedBox(height: 4),
                Text('Версия $appVersion', style: _note),
              ])),
        ])),
        const SizedBox(height: 16),
        KpPanel(
            padding: const EdgeInsets.all(6),
            child: Column(children: [
              _LinkRow(
                  icon: Icons.public_rounded,
                  title: 'Страница Keep Pixel',
                  subtitle: 'Новости и загрузка клиента',
                  onTap: () => openLink(
                      context, '${api.accountSite}/services/keeppixel')),
              _LinkRow(
                  icon: Icons.hub_rounded,
                  title: 'Necsoura',
                  subtitle: 'Все сервисы и аккаунт',
                  onTap: () => openLink(context, api.accountSite)),
              _LinkRow(
                  icon: Icons.description_outlined,
                  title: 'Лицензии',
                  subtitle: 'Открытые библиотеки в приложении',
                  onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Keep Pixel',
                      applicationVersion: appVersion)),
            ])),
      ]);
}
