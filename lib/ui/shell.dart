import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';
import '../core/downloads.dart';
import '../core/installer.dart';
import 'auth_dialog.dart';
import 'catalog.dart';
import 'downloads.dart';
import 'friends.dart';
import 'game_overlay.dart';
import 'library.dart';
import 'profile.dart';
import 'settings.dart';
import 'settings_window.dart';
import 'shared.dart';

class PixelShell extends StatefulWidget {
  final PixelApi api;
  final GameInstaller Function()? installerFactory;

  /// Set only by previews; normally it comes from the player's settings.
  final NavStyle? navStyle;
  final bool web;
  final void Function(DownloadsController)? onDownloads;
  const PixelShell(
      {super.key,
      required this.api,
      this.installerFactory,
      this.navStyle,
      this.web = kIsWeb,
      this.onDownloads});
  @override
  State<PixelShell> createState() => _PixelShellState();
}

class _PixelShellState extends State<PixelShell> with WidgetsBindingObserver {
  int page = 0, revision = 0;
  SettingsSection? _settingsSection;
  int _settingsOpened = 0;
  final visited = <int>{0};
  late final DownloadsController downloads;
  Timer? heartbeat;
  final storeSearch = TextEditingController();
  bool _signedIn = false;
  NavStyle _navStyle = NavStyle.dock;
  int _startPage = 0;
  void _syncSession() {
    final entered = widget.api.signedIn && !_signedIn;
    _signedIn = widget.api.signedIn;
    if (entered) _presence();
    if (_windowedSettings) unawaited(SettingsWindow.pushSession(widget.api));
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      if (prefs.getString('keep_pixel_nav_style') == NavStyle.top.name) {
        _navStyle = NavStyle.top;
      }
      if (!widget.web && prefs.getInt('keep_pixel_start_page') == 1) {
        _startPage = 1;
        if (page == 0) {
          page = 1;
          visited.add(1);
        }
      }
    });
  }

  void _setStartPage(int value) {
    setState(() => _startPage = value);
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setInt('keep_pixel_start_page', value)));
  }

  void _setNavStyle(NavStyle style) {
    setState(() => _navStyle = style);
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setString('keep_pixel_nav_style', style.name)));
  }

  AppLifecycleState lifecycle = AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    downloads =
        DownloadsController(widget.api, factory: widget.installerFactory);
    downloads.initialize();
    widget.onDownloads?.call(downloads);
    _loadPreferences();
    if (_windowedSettings) {
      SettingsWindow.listen(
          api: widget.api,
          onNavStyle: _setNavStyle,
          onStartPage: _setStartPage,
          onEndpoints: _saveEndpoints,
          onSignIn: () => showLogin(context, widget.api));
    }
    widget.api.addListener(_syncSession);
    scheduleMicrotask(_syncSession);
    heartbeat = Timer.periodic(const Duration(seconds: 40), (_) => _presence());
  }

  void _presence() {
    if (widget.api.signedIn) {
      unawaited(widget.api
          .presence(
              status: downloads.activeGameId != null
                  ? 'in_game'
                  : lifecycle == AppLifecycleState.resumed
                      ? 'online'
                      : 'away',
              gameId: downloads.activeGameId)
          .catchError((_) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    lifecycle = state;
    _presence();
  }

  @override
  void dispose() {
    heartbeat?.cancel();
    widget.api.removeListener(_syncSession);
    WidgetsBinding.instance.removeObserver(this);
    downloads.dispose();
    storeSearch.dispose();
    super.dispose();
  }

  bool get _windowedSettings => _desktop && SettingsWindow.supported;

  Future<String> _saveEndpoints(String shop, String account) async {
    await widget.api.setEndpoints(shop, account);
    return widget.api.checkConnection();
  }

  void openSettings([SettingsSection? section]) {
    if (_windowedSettings) {
      SettingsWindow.open(
          navStyle: widget.navStyle ?? _navStyle,
          startPage: _startPage,
          section: section);
    } else {
      setState(() {
        _settingsSection = section;
        _settingsOpened++;
      });
      select(4);
    }
  }

  void select(int index) {
    setState(() {
      page = index;
      visited.add(index);
    });
  }

  Widget gate(String title, String description) => StatePanel(
      icon: Icons.account_circle_outlined,
      title: title,
      description: description,
      action: 'Войти в Necsoura',
      onAction: () => showLogin(context, widget.api));
  Widget content(int i) => switch (i) {
        0 => CatalogPage(
            key: ValueKey('store-${widget.api.sessionGeneration}'),
            api: widget.api,
            downloads: downloads,
            search: storeSearch,
            searchInTopBar: MediaQuery.sizeOf(context).width >= _wideLayout,
            onOpenFriends: () => select(2),
            onSignIn: () => showLogin(context, widget.api),
            onLibraryChanged: () => setState(() => revision++)),
        1 => widget.api.signedIn
            ? LibraryPage(
                key: ValueKey(
                    'library-$revision-${widget.api.sessionGeneration}'),
                api: widget.api,
                downloads: downloads,
                onStore: () => select(0))
            : gate('Твои игры будут здесь',
                'Войди в Necsoura, чтобы открыть библиотеку на любом устройстве.'),
        2 => widget.api.signedIn
            ? FriendsPage(
                key: ValueKey('friends-${widget.api.sessionGeneration}'),
                api: widget.api,
                active: page == 2)
            : gate('Играй вместе с друзьями',
                'Войди, чтобы найти друзей, принять заявки и видеть, кто в сети.'),
        3 => widget.api.signedIn
            ? ProfilePage(
                key: ValueKey(
                    'profile-${widget.api.sessionGeneration}-${widget.api.profileRevision}'),
                api: widget.api,
                onSettings: openSettings)
            : StatePanel(
                icon: Icons.account_circle_outlined,
                title: 'Твой профиль Keep Pixel',
                description:
                    'Общие фото и имя Necsoura или своё оформление только для Keep Pixel.',
                action: 'Войти в Necsoura',
                onAction: () => showLogin(context, widget.api),
                secondaryAction: 'Настройки',
                onSecondaryAction: openSettings),
        _ => SettingsView(
            key: ValueKey('settings-$_settingsOpened'),
            api: widget.api,
            installer: widget.web
                ? null
                : widget.installerFactory?.call() ?? GameInstaller(),
            section: _settingsSection,
            navStyle: _desktop ? widget.navStyle ?? _navStyle : null,
            onNavStyle: _setNavStyle,
            startPage: widget.web ? null : _startPage,
            onStartPage: _setStartPage,
            onSaveEndpoints: _saveEndpoints,
            onSignIn: () => showLogin(context, widget.api),
            onBack: () => select(3)),
      };
  bool get _desktop =>
      !widget.web &&
      {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}
          .contains(defaultTargetPlatform);

  // The website has no library or installs, like Steam's: those live in the
  // client. Website on a wide screen: top menu. Computer: the player's choice.
  // Phone or a narrow window: floating dock.
  List<_NavItem> get _items =>
      widget.web ? _navItems.where((i) => i.page != 1).toList() : _navItems;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([widget.api, downloads.overlay]),
      builder: (context, _) {
        final desktop = _desktop;
        final wide = MediaQuery.sizeOf(context).width >= _wideLayout;
        final style = widget.navStyle ?? _navStyle;
        final dock = !wide || (!widget.web && style == NavStyle.dock);
        final canDownload = !widget.web && downloads.supported;
        final pages = PagePulse(
            trigger: page,
            child: IndexedStack(index: page, children: [
              for (var i = 0; i < 5; i++)
                if (visited.contains(i))
                  TickerMode(enabled: page == i, child: content(i))
                else
                  const SizedBox()
            ]));
        return Stack(children: [
          Scaffold(
            body: Stack(children: [
              const KpBackdrop(),
              SafeArea(
                  child: Column(children: [
                _TopBar(
                    desktop: desktop,
                    wide: wide,
                    inlineNav: wide && !dock,
                    items: _items,
                    downloadsButton: !dock && canDownload,
                    getClient: widget.web && wide,
                    page: page,
                    search: storeSearch,
                    api: widget.api,
                    downloads: downloads,
                    onSelect: select),
                if (downloads.overlay.error != null)
                  MaterialBanner(
                      content: Text(downloads.overlay.error!),
                      actions: [
                        TextButton(
                            onPressed: () => select(2),
                            child: const Text('Открыть друзей'))
                      ]),
                if (!widget.api.ready)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else
                  Expanded(
                      child: dock
                          ? Stack(children: [
                              Positioned.fill(
                                  child: MediaQuery(
                                      data: MediaQuery.of(context).copyWith(
                                          padding: MediaQuery.paddingOf(context)
                                              .copyWith(
                                                  bottom: _dockClearance)),
                                      child: Padding(
                                          padding: EdgeInsets.only(
                                              bottom: page == 0
                                                  ? 0
                                                  : _dockClearance),
                                          child: pages))),
                              const Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 130,
                                  child: IgnorePointer(
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                        Kp.bg,
                                        Color(0x000A0B12)
                                      ]))))),
                              Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: wide ? _dockGap : 10,
                                  child: Center(
                                      child: _Dock(
                                          page: page,
                                          items: _items,
                                          compact: !wide,
                                          canDownload: canDownload,
                                          downloads: downloads,
                                          onSelect: select)))
                            ])
                          : pages),
                if (!dock)
                  ListenableBuilder(
                      listenable: downloads,
                      builder: (context, _) {
                        final jobs = downloads.active.toList();
                        if (jobs.isEmpty) return const SizedBox();
                        final job = jobs.first;
                        return Material(
                            color: Kp.raised,
                            child: InkWell(
                                onTap: () => showDownloads(context, downloads),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    child: Row(children: [
                                      const Icon(Icons.download_rounded,
                                          size: 18, color: Kp.lilac),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Text(
                                              '${job.game.title} · ${job.label}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12))),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                          width: 80,
                                          child: LinearProgressIndicator(
                                              value: job.progress))
                                    ]))));
                      }),
              ])),
            ]),
          ),
          if (downloads.overlay.visible)
            Positioned.fill(
                child: GamePanel(api: widget.api, overlay: downloads.overlay)),
        ]);
      });
}

const _wideLayout = 760.0;
const _dockGap = 18.0, _dockHeight = 68.0;
const _dockClearance = _dockGap + _dockHeight + 18;

typedef _NavItem = ({int page, String label, IconData icon});
const List<_NavItem> _navItems = [
  (page: 0, label: 'Магазин', icon: Icons.storefront_rounded),
  (page: 1, label: 'Библиотека', icon: Icons.grid_view_rounded),
  (page: 2, label: 'Друзья', icon: Icons.people_alt_rounded),
  (page: 3, label: 'Профиль', icon: Icons.person_rounded),
];

class _Dock extends StatelessWidget {
  final int page;
  final List<_NavItem> items;
  final bool compact, canDownload;
  final DownloadsController downloads;
  final void Function(int) onSelect;
  const _Dock(
      {required this.page,
      required this.items,
      required this.compact,
      required this.canDownload,
      required this.downloads,
      required this.onSelect});
  @override
  Widget build(BuildContext context) {
    Widget fit(Widget item) => compact ? Expanded(child: item) : item;
    Widget nav(_NavItem item) => fit(_DockItem(
        label: item.label,
        selected: page == item.page || (page == 4 && item.page == 3),
        compact: compact,
        onTap: () => onSelect(item.page),
        icon: (color) => Icon(item.icon, size: 22, color: color)));
    final profile = items.last;
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 0),
        child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: Kp.r24, boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .5),
                  blurRadius: 28,
                  offset: const Offset(0, 10))
            ]),
            child: ClipRRect(
                borderRadius: Kp.r24,
                child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                        height: _dockHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                            color: Kp.surface.withValues(alpha: .86),
                            borderRadius: Kp.r24,
                            border: Border.all(color: Kp.line)),
                        child: Row(
                            mainAxisSize:
                                compact ? MainAxisSize.max : MainAxisSize.min,
                            children: [
                              for (final item in items)
                                if (item != profile) nav(item),
                              if (canDownload)
                                fit(ListenableBuilder(
                                    listenable: downloads,
                                    builder: (context, _) => _DockItem(
                                        label: 'Загрузки',
                                        selected: false,
                                        compact: compact,
                                        onTap: () =>
                                            showDownloads(context, downloads),
                                        icon: (color) => _DownloadGlyph(
                                            color: color,
                                            jobs: downloads.active.toList())))),
                              nav(profile),
                            ]))))));
  }
}

class _DownloadGlyph extends StatelessWidget {
  final Color color;
  final List<DownloadJob> jobs;
  const _DownloadGlyph({required this.color, required this.jobs});
  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Icon(Icons.download_rounded, size: 22, color: color);
    }
    final progress =
        jobs.map((j) => j.progress).reduce((a, b) => a + b) / jobs.length;
    return SizedBox.square(
        dimension: 22,
        child: OverflowBox(
            maxWidth: 30,
            maxHeight: 30,
            child: Stack(alignment: Alignment.center, children: [
              ProgressRing(value: progress, size: 30),
              const Icon(Icons.download_rounded, size: 15, color: Kp.lilac)
            ])));
  }
}

class _DockItem extends StatelessWidget {
  final String label;
  final bool selected, compact;
  final VoidCallback onTap;
  final Widget Function(Color color) icon;
  const _DockItem(
      {required this.label,
      required this.selected,
      required this.compact,
      required this.onTap,
      required this.icon});
  @override
  Widget build(BuildContext context) => Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
          button: true,
          selected: selected,
          child: Hovered(
              onTap: onTap,
              builder: (context, hover) => AnimatedContainer(
                  duration: Kp.motion,
                  curve: Curves.easeOut,
                  width: compact ? null : 84,
                  margin:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
                  transform: Matrix4.translationValues(0, hover ? -2 : 0, 0),
                  decoration: BoxDecoration(
                      borderRadius: Kp.r20,
                      gradient: selected ? Kp.gradient : null,
                      color: selected
                          ? null
                          : hover
                              ? Kp.raised
                              : Colors.transparent),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon(selected
                            ? Colors.white
                            : hover
                                ? Kp.lilac
                                : Kp.muted),
                        const SizedBox(height: 3),
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(
                                fontSize: compact ? 10 : 11,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected ? Colors.white : Kp.muted))
                      ])))));
}

class _TopBar extends StatelessWidget {
  final bool desktop, wide, inlineNav, downloadsButton, getClient;
  final List<_NavItem> items;
  final int page;
  final TextEditingController search;
  final PixelApi api;
  final DownloadsController downloads;
  final void Function(int) onSelect;
  const _TopBar(
      {required this.desktop,
      required this.wide,
      required this.inlineNav,
      required this.downloadsButton,
      required this.getClient,
      required this.items,
      required this.page,
      required this.search,
      required this.api,
      required this.downloads,
      required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final row = Row(children: [
      Flexible(
          flex: wide ? 0 : 1,
          child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Hovered(
                  onTap: () => onSelect(0),
                  builder: (_, __) => const _Brand()))),
      if (inlineNav) ...[
        const SizedBox(width: 24),
        for (final item in items) _TopNavItem(item, page, onSelect),
      ],
      if (wide) ...[
        const SizedBox(width: 24),
        Expanded(
            child: Align(
                alignment: inlineNav ? Alignment.centerRight : Alignment.center,
                child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: inlineNav ? 300 : 480),
                    child: _SearchField(
                        controller: search, onActivate: () => onSelect(0))))),
        const SizedBox(width: 16),
      ] else
        const Spacer(),
      if (getClient) ...[
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
            onPressed: () =>
                openLink(context, '${api.accountSite}/services/keeppixel'),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Скачать клиент')),
        const SizedBox(width: 8),
      ],
      if (downloadsButton)
        ListenableBuilder(
            listenable: downloads,
            builder: (context, _) => IconButton(
                tooltip: 'Загрузки',
                onPressed: () => showDownloads(context, downloads),
                icon: _DownloadGlyph(
                    color: Kp.muted, jobs: downloads.active.toList()))),
      if (!api.signedIn)
        OutlinedButton(
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            onPressed: api.ready ? () => showLogin(context, api) : null,
            child: const Text('Войти')),
      if (desktop) ...[
        const SizedBox(width: 10),
        WindowButtons(
            onMinimize: appWindow.minimize,
            onMaximize: appWindow.maximizeOrRestore,
            maximized: appWindow.isMaximized,
            onClose: appWindow.close),
      ],
    ]);
    return Container(
        decoration: const BoxDecoration(
            color: Kp.bg, border: Border(bottom: BorderSide(color: Kp.line))),
        child: Stack(children: [
          if (desktop) Positioned.fill(child: MoveWindow()),
          Padding(
              padding: EdgeInsets.fromLTRB(
                  wide ? 24 : 16, 10, wide ? (desktop ? 12 : 24) : 12, 10),
              child: row),
        ]));
  }
}

class _TopNavItem extends StatelessWidget {
  final _NavItem item;
  final int page;
  final void Function(int) onSelect;
  const _TopNavItem(this.item, this.page, this.onSelect);
  @override
  Widget build(BuildContext context) {
    final selected = page == item.page || (page == 4 && item.page == 3);
    return Hovered(
        onTap: () => onSelect(item.page),
        builder: (context, hover) => AnimatedContainer(
            duration: Kp.motion,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
                borderRadius: Kp.r14,
                gradient: selected ? Kp.gradient : null,
                color: selected
                    ? null
                    : hover
                        ? Kp.raised
                        : Colors.transparent),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(item.icon,
                  size: 16,
                  color: selected
                      ? Colors.white
                      : hover
                          ? Kp.lilac
                          : Kp.muted),
              const SizedBox(width: 7),
              Text(item.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : Kp.muted))
            ])));
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onActivate;
  const _SearchField({required this.controller, required this.onActivate});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 40,
      child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => TextField(
              controller: controller,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 14),
              onChanged: (_) => onActivate(),
              decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Поиск игр и приложений',
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: Kp.muted),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить поиск',
                          iconSize: 16,
                          onPressed: controller.clear,
                          icon: const Icon(Icons.close_rounded))))));
}

class PagePulse extends StatefulWidget {
  final Object trigger;
  final Widget child;
  const PagePulse({super.key, required this.trigger, required this.child});
  @override
  State<PagePulse> createState() => _PagePulseState();
}

class _PagePulseState extends State<PagePulse>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  late final curve = CurvedAnimation(parent: controller, curve: Curves.easeOut);
  @override
  void didUpdateWidget(PagePulse old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) controller.forward(from: 0);
  }

  @override
  void dispose() {
    curve.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: curve,
      child: SlideTransition(
          position: Tween(begin: const Offset(0, .012), end: Offset.zero)
              .animate(curve),
          child: widget.child));
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/logo.png', width: 26, height: 26),
        const SizedBox(width: 10),
        const Text('keep pixel',
            style: TextStyle(
                fontFamily: 'Unbounded',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -.7))
      ]);
}
