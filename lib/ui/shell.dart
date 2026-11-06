import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'shared.dart';

class PixelShell extends StatefulWidget {
  final PixelApi api;
  final GameInstaller Function()? installerFactory;
  const PixelShell({super.key, required this.api, this.installerFactory});
  @override
  State<PixelShell> createState() => _PixelShellState();
}

class _PixelShellState extends State<PixelShell> with WidgetsBindingObserver {
  int page = 0, revision = 0;
  final visited = <int>{0};
  late final DownloadsController downloads;
  Timer? heartbeat;
  bool _signedIn = false;
  void _syncSession() {
    final entered = widget.api.signedIn && !_signedIn;
    _signedIn = widget.api.signedIn;
    if (entered) _presence();
  }

  AppLifecycleState lifecycle = AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    downloads =
        DownloadsController(widget.api, factory: widget.installerFactory);
    downloads.initialize();
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
    super.dispose();
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
                key: ValueKey('profile-${widget.api.sessionGeneration}'),
                api: widget.api)
            : gate('Твой профиль Keep Pixel',
                'Общие фото и имя Necsoura или своё оформление только для Keep Pixel.'),
        _ => ConnectionSettings(api: widget.api),
      };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([widget.api, downloads.overlay]),
      builder: (context, _) {
        final desktop = !kIsWeb &&
            {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}
                .contains(defaultTargetPlatform);
        final wide = MediaQuery.sizeOf(context).width >= 1000;
        return Stack(children: [
          Scaffold(
            body: SafeArea(
                child: Column(children: [
              if (desktop)
                SizedBox(
                    height: 30,
                    child: WindowTitleBarBox(
                        child: Row(children: [
                      Expanded(child: MoveWindow()),
                      MinimizeWindowButton(),
                      MaximizeWindowButton(),
                      CloseWindowButton()
                    ]))),
              Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: wide ? 24 : 16, vertical: 12),
                  decoration: const BoxDecoration(
                      color: Color(0xFF171D21),
                      border:
                          Border(bottom: BorderSide(color: Color(0xFF2B333B)))),
                  child: Row(children: [
                    Flexible(
                        flex: wide ? 0 : 1,
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                                onTap: () => select(0),
                                child: const _Brand()))),
                    if (wide) ...[
                      const SizedBox(width: 32),
                      for (final (i, label) in [
                        (0, 'Магазин'),
                        (1, 'Библиотека'),
                        (2, 'Друзья'),
                        (3, 'Мой профиль')
                      ])
                        Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: TextButton(
                                onPressed: () => select(i),
                                style: TextButton.styleFrom(
                                    foregroundColor: page == i ? accent : muted,
                                    backgroundColor: page == i
                                        ? accent.withValues(alpha: .08)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 18)),
                                child: Text(label)))
                    ],
                    if (wide) const Spacer() else const SizedBox(width: 8),
                    ListenableBuilder(
                        listenable: downloads,
                        builder: (context, _) => IconButton(
                            tooltip: 'Загрузки',
                            onPressed: () => showDownloads(context, downloads),
                            icon: Badge(
                                isLabelVisible: downloads.active.isNotEmpty,
                                label: Text('${downloads.active.length}'),
                                child: const Icon(Icons.download_outlined,
                                    size: 21)))),
                    IconButton(
                        tooltip: 'Настройки подключения',
                        onPressed: () => select(4),
                        icon: const Icon(Icons.settings_outlined, size: 21)),
                    if (widget.api.signedIn)
                      IconButton(
                          tooltip: 'Профиль аккаунта',
                          onPressed: () => select(3),
                          icon: const CircleAvatar(
                              radius: 15,
                              child: Icon(Icons.person_outline, size: 18)))
                    else
                      TextButton(
                          onPressed: widget.api.ready
                              ? () => showLogin(context, widget.api)
                              : null,
                          child: const Text('Войти')),
                  ])),
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
                    child: IndexedStack(index: page, children: [
                  for (var i = 0; i < 5; i++)
                    if (visited.contains(i))
                      TickerMode(enabled: page == i, child: content(i))
                    else
                      const SizedBox()
                ])),
              ListenableBuilder(
                  listenable: downloads,
                  builder: (context, _) {
                    final jobs = downloads.active.toList();
                    if (jobs.isEmpty) return const SizedBox();
                    final job = jobs.first;
                    return Material(
                        color: const Color(0xFF202B35),
                        child: InkWell(
                            onTap: () => showDownloads(context, downloads),
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: Row(children: [
                                  const Icon(Icons.download,
                                      size: 18, color: accent),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(
                                          '${job.game.title} · ${job.label}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(fontSize: 12))),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                      width: 80,
                                      child: LinearProgressIndicator(
                                          value: job.progress))
                                ]))));
                  }),
            ])),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: page == 4 ? 3 : page,
                    onDestinationSelected: select,
                    destinations: const [
                        NavigationDestination(
                            icon: Icon(Icons.storefront_outlined),
                            label: 'Магазин'),
                        NavigationDestination(
                            icon: Icon(Icons.grid_view_rounded),
                            label: 'Библиотека'),
                        NavigationDestination(
                            icon: Icon(Icons.people_outline), label: 'Друзья'),
                        NavigationDestination(
                            icon: Icon(Icons.person_outline), label: 'Профиль')
                      ]),
          ),
          if (downloads.overlay.visible)
            Positioned.fill(
                child: GamePanel(api: widget.api, overlay: downloads.overlay)),
        ]);
      });
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/logo.png', width: 26, height: 26),
        const SizedBox(width: 9),
        const Text('keep pixel',
            style: TextStyle(
                fontFamily: 'Unbounded',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -.7))
      ]);
}
