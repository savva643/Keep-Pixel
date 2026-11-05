import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import 'auth_dialog.dart';
import 'catalog.dart';
import 'profile.dart';
import 'shared.dart';

class PixelShell extends StatefulWidget {
  final PixelApi api;
  const PixelShell({super.key, required this.api});
  @override
  State<PixelShell> createState() => _PixelShellState();
}

class _PixelShellState extends State<PixelShell> {
  int page = 0, revision = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.api,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 1000;
        final desktop = !kIsWeb &&
            {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}
                .contains(defaultTargetPlatform);
        return Scaffold(
          body: SafeArea(
              child: Column(children: [
            if (desktop)
              SizedBox(
                  height: 32,
                  child: WindowTitleBarBox(
                      child: Row(children: [
                    Expanded(child: MoveWindow()),
                    MinimizeWindowButton(),
                    MaximizeWindowButton(),
                    CloseWindowButton()
                  ]))),
            Expanded(
                child: Row(children: [
              if (wide)
                Container(
                    width: 224,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                        color: Color(0xFF151B19),
                        border: Border(
                            right: BorderSide(color: Color(0xFF27302C)))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Brand(),
                          const SizedBox(height: 48),
                          const Text('ТВОЁ ПРОСТРАНСТВО',
                              style: TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                  letterSpacing: 1.3)),
                          const SizedBox(height: 16),
                          for (final (i, label, icon) in [
                            (0, 'Открыть новое', Icons.explore_outlined),
                            (1, 'Библиотека', Icons.grid_view_rounded),
                            (2, 'Мой профиль', Icons.person_outline_rounded)
                          ])
                            Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    selected: page == i,
                                    selectedTileColor:
                                        accent.withValues(alpha: .1),
                                    selectedColor: accent,
                                    leading: Icon(icon, size: 20),
                                    title: Text(label,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500)),
                                    onTap: () => setState(() => page = i))),
                          const Spacer(),
                          Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF222D27),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.hub_outlined, color: accent),
                                    SizedBox(height: 12),
                                    Text('Вместе с Necsoura',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    SizedBox(height: 6),
                                    Text('Один профиль для твоих сервисов.',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: muted,
                                            height: 1.6))
                                  ])),
                          const SizedBox(height: 18),
                          const Text('KEEP PIXEL  /  1.1',
                              style: TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                  letterSpacing: 1.5)),
                        ])),
              Expanded(
                  child: Column(children: [
                Padding(
                    padding: EdgeInsets.fromLTRB(
                        wide ? 40 : 20, 20, wide ? 40 : 20, 16),
                    child: Row(children: [
                      if (!wide)
                        const _Brand()
                      else
                        const Text('Место, где начинается игра',
                            style: TextStyle(color: muted, fontSize: 12)),
                      const Spacer(),
                      if (widget.api.signedIn)
                        IconButton(
                            tooltip: 'Мой профиль',
                            onPressed: () => setState(() => page = 2),
                            icon: const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFF334C3D),
                                child: Icon(Icons.person_outline_rounded,
                                    size: 20, color: accent)))
                      else
                        OutlinedButton(
                            onPressed: widget.api.ready
                                ? () => showLogin(context, widget.api)
                                : null,
                            child: const Text('Войти')),
                    ])),
                if (widget.api.startupError != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(widget.api.startupError!,
                          style: const TextStyle(color: muted))),
                Expanded(
                    child: !widget.api.ready
                        ? const Center(child: CircularProgressIndicator())
                        : switch (page) {
                            0 => CatalogPage(
                                key: ValueKey(
                                    'store-$revision-${widget.api.signedIn}'),
                                api: widget.api,
                                onLibraryChanged: () =>
                                    setState(() => revision++)),
                            1 => widget.api.signedIn
                                ? CatalogPage(
                                    key: ValueKey('library-$revision'),
                                    api: widget.api,
                                    library: true,
                                    onLibraryChanged: () =>
                                        setState(() => revision++))
                                : StatePanel(
                                    icon: Icons.grid_view_rounded,
                                    title: 'Твои игры будут здесь',
                                    description:
                                        'Войди в Necsoura, чтобы открыть библиотеку на любом устройстве.',
                                    action: 'Войти',
                                    onAction: () =>
                                        showLogin(context, widget.api)),
                            _ => widget.api.signedIn
                                ? ProfilePage(
                                    key: ValueKey(
                                        'profile-${widget.api.signedIn}'),
                                    api: widget.api)
                                : StatePanel(
                                    icon: Icons.person_outline_rounded,
                                    title: 'Твой профиль Keep Pixel',
                                    description:
                                        'Фото, шапка и имя из Necsoura — или своё оформление только для этой площадки.',
                                    action: 'Войти',
                                    onAction: () =>
                                        showLogin(context, widget.api)),
                          }),
              ])),
            ])),
          ])),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: page,
                  onDestinationSelected: (i) => setState(() => page = i),
                  destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore_rounded),
                          label: 'Магазин'),
                      NavigationDestination(
                          icon: Icon(Icons.grid_view_rounded),
                          label: 'Библиотека'),
                      NavigationDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          label: 'Профиль')
                    ]),
        );
      });
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/logo.png', width: 30, height: 30),
          const SizedBox(width: 10),
          const Text('keep pixel',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8)),
        ]),
      );
}
