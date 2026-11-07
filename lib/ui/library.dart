import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/downloads.dart';
import '../core/library_prefs.dart';
import '../core/models.dart';
import '../core/storage.dart';
import 'game_actions.dart';
import 'shared.dart';

enum _Filter { all, installed, favorites, hidden }

enum _Sort {
  title('По названию'),
  recent('Недавно запущенные'),
  playtime('Время в игре');

  final String label;
  const _Sort(this.label);
}

class LibraryPage extends StatefulWidget {
  final PixelApi api;
  final DownloadsController downloads;
  final VoidCallback onStore;
  const LibraryPage(
      {super.key,
      required this.api,
      required this.downloads,
      required this.onStore});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Game> games = [];
  List<PixelFriend> friends = [];

  /// Null shows the library home, like Steam.
  String? selected;
  bool loading = true;
  String? error;
  String query = '';
  _Filter filter = _Filter.all;
  _Sort sort = _Sort.title;

  DownloadsController get downloads => widget.downloads;
  LibraryPrefs get prefs => downloads.prefs;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await widget.api.library();
      if (mounted) {
        setState(() {
          games = list;
          if (!games.any((g) => g.id == selected)) selected = null;
        });
      }
      unawaited(widget.api.friends().then((f) {
        if (mounted) setState(() => friends = f);
      }).catchError((_) {}));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  GameActions actionsFor(Game g) => GameActions(context,
      api: widget.api, downloads: downloads, game: g, onChanged: load);

  List<Game> get visible {
    final q = query.trim().toLowerCase();
    final list = games.where((g) {
      if (q.isNotEmpty && !g.title.toLowerCase().contains(q)) return false;
      return switch (filter) {
        _Filter.all => !prefs.isHidden(g.id),
        _Filter.installed => downloads.hasInstall(g) && !prefs.isHidden(g.id),
        _Filter.favorites => prefs.isFavorite(g.id),
        _Filter.hidden => prefs.isHidden(g.id),
      };
    }).toList();
    int byTitle(Game a, Game b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    list.sort(switch (sort) {
      _Sort.title => byTitle,
      _Sort.recent => (a, b) {
          final x = prefs.lastPlayed(a.id), y = prefs.lastPlayed(b.id);
          if (x == null && y == null) return byTitle(a, b);
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        },
      _Sort.playtime => (a, b) {
          final c = prefs.playTime(b.id).compareTo(prefs.playTime(a.id));
          return c != 0 ? c : byTitle(a, b);
        },
    });
    return list;
  }

  (String, DateTime)? _lastTap;

  /// A click opens the game at once; a second click on the same game soon
  /// after starts it, as a double click does in Steam.
  void tapTile(Game g, {required bool wide}) {
    final now = DateTime.now(), last = _lastTap;
    _lastTap = (g.id, now);
    if (wide &&
        last != null &&
        last.$1 == g.id &&
        now.difference(last.$2) < const Duration(milliseconds: 450) &&
        downloads.isCurrent(g) &&
        !downloads.isRunning(g)) {
      _lastTap = null;
      unawaited(actionsFor(g).play());
      return;
    }
    open(g, wide: wide);
  }

  void open(Game g, {required bool wide}) {
    if (wide) {
      setState(() => selected = g.id);
    } else {
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => SizedBox(
              height: MediaQuery.sizeOf(context).height * .9,
              child: LibraryGamePage(
                  key: ValueKey(g.id),
                  initial: g,
                  actions: actionsFor,
                  friends: friends)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([downloads, prefs]),
      builder: (context, _) {
        if (loading && games.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (error != null) {
          return StatePanel(
              icon: Icons.cloud_off_rounded,
              title: 'Библиотека недоступна',
              description: error!,
              action: 'Повторить',
              onAction: load);
        }
        if (games.isEmpty) {
          return StatePanel(
              icon: Icons.grid_view_rounded,
              title: 'Твоя библиотека пока пуста',
              description:
                  'Добавь игру в магазине. Она появится здесь на всех устройствах.',
              action: 'Открыть магазин',
              onAction: widget.onStore);
        }
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 900;
          final list = visible;
          final game = games.where((g) => g.id == selected).firstOrNull;
          if (!wide) {
            return _sidebar(list, wide: false);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
                width: 300,
                decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Kp.line))),
                child: _sidebar(list, wide: true)),
            Expanded(
                child: game == null
                    ? _LibraryHome(
                        games: list,
                        all: games,
                        prefs: prefs,
                        downloads: downloads,
                        friends: friends,
                        actions: actionsFor,
                        onOpen: (g) => open(g, wide: true))
                    : LibraryGamePage(
                        key: ValueKey(game.id),
                        initial: game,
                        actions: actionsFor,
                        friends: friends,
                        embedded: true)),
          ]);
        });
      });

  Widget _sidebar(List<Game> list, {required bool wide}) {
    final favorites = filter == _Filter.all
        ? list.where((g) => prefs.isFavorite(g.id)).toList()
        : <Game>[];
    final rest = list.where((g) => !favorites.contains(g)).toList();
    final recent = wide
        ? <Game>[]
        : (games
            .where(
                (g) => prefs.lastPlayed(g.id) != null && !prefs.isHidden(g.id))
            .toList()
          ..sort((a, b) =>
              prefs.lastPlayed(b.id)!.compareTo(prefs.lastPlayed(a.id)!)));
    final bottom = wide ? 24.0 : 120.0;
    return CustomScrollView(slivers: [
      SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, wide ? 8 : 4),
          sliver: SliverList.list(children: [
            Row(children: [
              Expanded(
                  child: Text('Библиотека',
                      style: TextStyle(
                          fontSize: wide ? 18 : 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4))),
              _SortButton(
                  sort: sort, onChanged: (s) => setState(() => sort = s)),
              IconButton(
                  tooltip: 'Обновить библиотеку',
                  onPressed: load,
                  icon: const Icon(Icons.refresh_rounded, size: 20)),
            ]),
            const SizedBox(height: 10),
            TextField(
                decoration: const InputDecoration(
                    hintText: 'Поиск в библиотеке',
                    prefixIcon: Icon(Icons.search, size: 20)),
                onChanged: (s) => setState(() => query = s)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (f, label) in [
                (_Filter.all, 'Все'),
                (_Filter.installed, 'Установленные'),
                (_Filter.favorites, 'Избранное'),
                if (prefs.hidden.isNotEmpty || filter == _Filter.hidden)
                  (_Filter.hidden, 'Скрытые'),
              ])
                KpChip(
                    label: label,
                    selected: filter == f,
                    onTap: () => setState(() => filter = f)),
            ]),
          ])),
      if (recent.isNotEmpty && query.isEmpty && filter == _Filter.all) ...[
        const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            sliver: SliverToBoxAdapter(child: KpHeading('Недавние'))),
        SliverToBoxAdapter(
            child: SizedBox(
                height: 150,
                child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.take(8).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => SizedBox(
                        width: 240,
                        child: _RecentCard(
                            game: recent[i],
                            prefs: prefs,
                            actions: () => actionsFor(recent[i]),
                            onTap: () => open(recent[i], wide: false)))))),
      ],
      if (wide)
        SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            sliver: SliverToBoxAdapter(
                child: _NavTile(
                    icon: Icons.home_rounded,
                    label: 'Главная',
                    selected: selected == null,
                    onTap: () => setState(() => selected = null)))),
      if (list.isEmpty)
        SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
                child: Text(
                    switch (filter) {
                      _Filter.favorites =>
                        'В избранном пусто. Добавь игру через правый клик или долгое нажатие.',
                      _Filter.installed => 'Нет установленных игр',
                      _Filter.hidden => 'Скрытых игр нет',
                      _ => 'Игры не найдены',
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, height: 1.6)))),
      for (final (title, group) in [
        if (favorites.isNotEmpty) ('Избранное', favorites),
        if (rest.isNotEmpty)
          (
            switch (filter) {
              _Filter.installed => 'Установленные',
              _Filter.favorites => 'Избранное',
              _Filter.hidden => 'Скрытые',
              _ => 'Все игры'
            },
            rest
          ),
      ]) ...[
        SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
            sliver: SliverToBoxAdapter(
                child: Text('${title.toUpperCase()} · ${group.length}',
                    style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w700)))),
        SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList.list(children: [
              for (final g in group)
                _GameTile(
                    game: g,
                    selected: wide && g.id == selected,
                    downloads: downloads,
                    actions: () => actionsFor(g),
                    onTap: () => tapTile(g, wide: wide)),
            ])),
      ],
      SliverToBoxAdapter(child: SizedBox(height: bottom)),
    ]);
  }
}

/// One line of state under a game's name.
String _status(DownloadsController d, Game g) {
  final job = d.jobs[g.id];
  if (job?.active == true) return job!.label;
  if (d.moving.containsKey(g.id)) {
    return 'Перенос ${(d.moving[g.id]! * 100).round()}%';
  }
  if (d.isRunning(g)) return 'Запущено';
  if (d.isCurrent(g)) {
    final time = d.prefs.playTime(g.id);
    return time == Duration.zero
        ? 'Установлено'
        : 'Установлено · ${playTimeLabel(time)}';
  }
  if (d.hasInstall(g)) return 'Доступно обновление';
  return 'Не установлено';
}

class _SortButton extends StatelessWidget {
  final _Sort sort;
  final ValueChanged<_Sort> onChanged;
  const _SortButton({required this.sort, required this.onChanged});
  @override
  Widget build(BuildContext context) => PopupMenuButton<_Sort>(
      tooltip: 'Сортировка: ${sort.label.toLowerCase()}',
      initialValue: sort,
      color: Kp.raised,
      shape: const RoundedRectangleBorder(
          borderRadius: Kp.r14, side: BorderSide(color: Kp.line)),
      onSelected: onChanged,
      icon: const Icon(Icons.sort_rounded, size: 20),
      itemBuilder: (_) => [
            for (final s in _Sort.values)
              PopupMenuItem(
                  value: s,
                  height: 38,
                  child: Row(children: [
                    Icon(Icons.check_rounded,
                        size: 18,
                        color: s == sort ? Kp.lilac : Colors.transparent),
                    const SizedBox(width: 10),
                    Text(s.label, style: const TextStyle(fontSize: 13)),
                  ])),
          ]);
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Hovered(
      onTap: onTap,
      builder: (context, hover) => AnimatedContainer(
          duration: Kp.motion,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              borderRadius: Kp.r14,
              color: selected
                  ? Kp.violet.withValues(alpha: .2)
                  : hover
                      ? Kp.raised
                      : null),
          child: Row(children: [
            Icon(icon, size: 20, color: selected ? Kp.lilac : Kp.muted),
            const SizedBox(width: 12),
            Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ])));
}

class _GameTile extends StatelessWidget {
  final Game game;
  final bool selected;
  final DownloadsController downloads;
  final GameActions Function() actions;
  final VoidCallback onTap;
  const _GameTile(
      {required this.game,
      required this.selected,
      required this.downloads,
      required this.actions,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final job = downloads.jobs[game.id];
    final running = downloads.isRunning(game);
    return GameMenuArea(
        actions: actions,
        child: Hovered(
            onTap: onTap,
            builder: (context, hover) => AnimatedContainer(
                duration: Kp.motion,
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    borderRadius: Kp.r14,
                    color: selected
                        ? Kp.violet.withValues(alpha: .2)
                        : hover
                            ? Kp.raised
                            : null),
                child: Row(children: [
                  SizedBox.square(
                      dimension: 42,
                      child: ClipRRect(
                          borderRadius: Kp.r10,
                          child: Opacity(
                              opacity: downloads.hasInstall(game) ? 1 : .55,
                              child: Artwork(game.cover, label: game.title)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(game.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: downloads.hasInstall(game)
                                    ? Kp.text
                                    : Kp.muted)),
                        const SizedBox(height: 3),
                        Text(_status(downloads, game),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: running ? Kp.online : muted)),
                        if (job?.active == true) ...[
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                              value: job!.progress, minHeight: 3),
                        ],
                      ])),
                  if (downloads.prefs.isFavorite(game.id))
                    const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.star_rounded,
                            size: 16, color: Kp.lilac)),
                  if (running)
                    Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Kp.online, shape: BoxShape.circle)),
                ]))));
  }
}

class _RecentCard extends StatelessWidget {
  final Game game;
  final LibraryPrefs prefs;
  final GameActions Function() actions;
  final VoidCallback onTap;
  const _RecentCard(
      {required this.game,
      required this.prefs,
      required this.actions,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GameMenuArea(
      actions: actions,
      child: Hovered(
          onTap: onTap,
          builder: (context, hover) => AnimatedContainer(
              duration: Kp.motion,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  borderRadius: Kp.r20,
                  border: Border.all(color: hover ? Kp.violet : Kp.line)),
              child: Stack(fit: StackFit.expand, children: [
                AnimatedScale(
                    duration: const Duration(milliseconds: 260),
                    scale: hover ? 1.04 : 1,
                    child: Artwork(game.banner, label: game.title)),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xE60A0B12)],
                            stops: [.35, 1]))),
                Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(game.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                              '${lastPlayedLabel(prefs.lastPlayed(game.id))} · ${playTimeLabel(prefs.playTime(game.id))}',
                              style: const TextStyle(
                                  fontSize: 11, color: Kp.muted)),
                        ])),
              ]))));
}

/// The library start page: recent games, friends in games and every game as
/// a cover, the way Steam and the Epic launcher show a collection.
class _LibraryHome extends StatelessWidget {
  final List<Game> games, all;
  final LibraryPrefs prefs;
  final DownloadsController downloads;
  final List<PixelFriend> friends;
  final GameActions Function(Game) actions;
  final ValueChanged<Game> onOpen;
  const _LibraryHome(
      {required this.games,
      required this.all,
      required this.prefs,
      required this.downloads,
      required this.friends,
      required this.actions,
      required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final recent = all
        .where((g) => prefs.lastPlayed(g.id) != null && !prefs.isHidden(g.id))
        .toList()
      ..sort(
          (a, b) => prefs.lastPlayed(b.id)!.compareTo(prefs.lastPlayed(a.id)!));
    final shelf = recent.isNotEmpty
        ? recent.take(6).toList()
        : all
            .where((g) => downloads.hasInstall(g) && !prefs.isHidden(g.id))
            .take(6)
            .toList();
    final playing = friends
        .where((f) => f.status == 'in_game' && f.gameId != null)
        .toList();
    final installedBytes = downloads.installed.length;
    return ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 130),
        children: [
          Row(children: [
            _Counter(value: '${all.length}', label: 'игр в библиотеке'),
            const SizedBox(width: 12),
            _Counter(value: '$installedBytes', label: 'установлено'),
            const SizedBox(width: 12),
            _Counter(
                value: playTimeLabel(all.fold(
                    Duration.zero, (sum, g) => sum + prefs.playTime(g.id))),
                label: 'в играх на этом устройстве'),
          ]),
          if (shelf.isNotEmpty) ...[
            const SizedBox(height: 28),
            KpHeading(recent.isNotEmpty ? 'Недавние игры' : 'Готово к игре'),
            const SizedBox(height: 14),
            SizedBox(
                height: 190,
                child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: shelf.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => SizedBox(
                        width: i == 0 ? 400 : 300,
                        child: _RecentCard(
                            game: shelf[i],
                            prefs: prefs,
                            actions: () => actions(shelf[i]),
                            onTap: () => onOpen(shelf[i]))))),
          ],
          if (playing.isNotEmpty) ...[
            const SizedBox(height: 28),
            const KpHeading('Друзья в игре'),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final f in playing) _FriendChip(friend: f),
            ]),
          ],
          const SizedBox(height: 28),
          KpHeading('Все игры', trailing: '${games.length}'),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, box) {
            final columns = (box.maxWidth / 190).floor().clamp(2, 8);
            final width = (box.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(spacing: 16, runSpacing: 20, children: [
              for (final g in games)
                SizedBox(
                    width: width,
                    child: _CoverCard(
                        game: g,
                        downloads: downloads,
                        actions: () => actions(g),
                        onTap: () => onOpen(g))),
            ]);
          }),
        ]);
  }
}

class _Counter extends StatelessWidget {
  final String value, label;
  const _Counter({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
      child: KpPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 12)),
          ])));
}

class _FriendChip extends StatelessWidget {
  final PixelFriend friend;
  const _FriendChip({required this.friend});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
          color: Kp.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Kp.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          SizedBox.square(
              dimension: 34,
              child:
                  ClipOval(child: Artwork(friend.avatar, label: friend.name))),
          Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                      color: Kp.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: Kp.surface, width: 2)))),
        ]),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(friend.name,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text(friend.statusLabel,
              style: const TextStyle(fontSize: 11, color: Kp.online)),
        ]),
      ]));
}

class _CoverCard extends StatelessWidget {
  final Game game;
  final DownloadsController downloads;
  final GameActions Function() actions;
  final VoidCallback onTap;
  const _CoverCard(
      {required this.game,
      required this.downloads,
      required this.actions,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final job = downloads.jobs[game.id];
    final ready = downloads.isCurrent(game) && !downloads.isRunning(game);
    return GameMenuArea(
        actions: actions,
        child: Hovered(
            onTap: onTap,
            builder: (context, hover) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AspectRatio(
                      aspectRatio: 3 / 4,
                      child: AnimatedContainer(
                          duration: Kp.motion,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                              borderRadius: Kp.r14,
                              border: Border.all(
                                  color: hover ? Kp.violet : Kp.line),
                              boxShadow: hover
                                  ? [
                                      BoxShadow(
                                          color:
                                              Kp.violet.withValues(alpha: .3),
                                          blurRadius: 22)
                                    ]
                                  : null),
                          child: Stack(fit: StackFit.expand, children: [
                            Opacity(
                                opacity: downloads.hasInstall(game) ? 1 : .6,
                                child: Artwork(game.cover, label: game.title)),
                            if (downloads.prefs.isFavorite(game.id))
                              const Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Icon(Icons.star_rounded,
                                      color: Kp.lilac, size: 20)),
                            if (hover)
                              Center(
                                  child: Material(
                                      color: Colors.transparent,
                                      child: IconButton.filled(
                                          tooltip: actions().primary.label,
                                          style: IconButton.styleFrom(
                                              backgroundColor: Kp.violet,
                                              fixedSize: const Size.square(54)),
                                          onPressed:
                                              actions().primary.onTap ?? onTap,
                                          icon: Icon(
                                              ready
                                                  ? Icons.play_arrow_rounded
                                                  : actions().primary.icon,
                                              size: 30)))),
                            if (job?.active == true)
                              Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: LinearProgressIndicator(
                                      value: job!.progress, minHeight: 4)),
                          ]))),
                  const SizedBox(height: 8),
                  Text(game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(_status(downloads, game),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              downloads.isRunning(game) ? Kp.online : muted)),
                ])));
  }
}

/// A game in the library, laid out like Steam's game page: a hero banner, a
/// bar with the play button and stats, then news, details and friends.
class LibraryGamePage extends StatefulWidget {
  final Game initial;
  final GameActions Function(Game) actions;
  final List<PixelFriend> friends;
  final bool embedded;
  const LibraryGamePage(
      {super.key,
      required this.initial,
      required this.actions,
      required this.friends,
      this.embedded = false});
  @override
  State<LibraryGamePage> createState() => _LibraryGamePageState();
}

class _LibraryGamePageState extends State<LibraryGamePage> {
  late Game game = widget.initial;
  Future<int>? size;
  String? sizeFor;

  @override
  void initState() {
    super.initState();
    final a = widget.actions(game);
    a.api.game(game.id).then((g) {
      if (mounted) setState(() => game = g);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actions(game);
    final d = a.downloads;
    return ListenableBuilder(
        listenable: Listenable.merge([d, d.prefs]),
        builder: (context, _) {
          // The size is counted again whenever the game moves or updates.
          final key = '${d.installed[game.id]}${d.locations[game.id]}';
          if (sizeFor != key) {
            sizeFor = key;
            size = d.hasInstall(game) && d.supported
                ? d.factory().gameSize(game.id).catchError((_) => 0)
                : null;
          }
          return LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 760;
            final gutter = wide ? 28.0 : 16.0;
            return ListView(
                padding: EdgeInsets.only(bottom: wide ? 130 : 40),
                children: [
                  _Hero(game: game, actions: a, wide: wide),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            _ActionBar(actions: a, size: size, wide: wide),
                            if (d.hasInstall(game) &&
                                !d.isCurrent(game) &&
                                d.jobs[game.id]?.active != true &&
                                a.canInstall) ...[
                              const SizedBox(height: 12),
                              _UpdateBanner(game: game, actions: a),
                            ],
                            const SizedBox(height: 28),
                            if (box.maxWidth >= 1000)
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _main()),
                                    const SizedBox(width: 28),
                                    SizedBox(width: 320, child: _side()),
                                  ])
                            else ...[
                              _main(),
                              const SizedBox(height: 28),
                              _side(),
                            ],
                          ])),
                ]);
          });
        });
  }

  Widget _main() {
    final updates = game.details['updates'] is List
        ? (game.details['updates'] as List).whereType<Map>().toList()
        : <Map>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const KpHeading('Об игре'),
      const SizedBox(height: 12),
      SelectableText(
          game.description.isEmpty
              ? 'Автор пока не добавил описание.'
              : game.description,
          style: const TextStyle(color: muted, height: 1.8)),
      const SizedBox(height: 28),
      const KpHeading('Обновления и новости'),
      const SizedBox(height: 12),
      if (updates.isEmpty)
        const Text('Разработчик пока не публиковал обновлений.',
            style: TextStyle(color: muted))
      else
        for (final u in updates.take(5))
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KpPanel(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: const BoxDecoration(
                                gradient: Kp.gradient, borderRadius: Kp.r10),
                            child: Text('${u['version'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('${u['title'] ?? 'Обновление'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              if ('${u['description'] ?? ''}'.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('${u['description']}',
                                    style: const TextStyle(
                                        color: muted, height: 1.6)),
                              ],
                            ])),
                      ]))),
    ]);
  }

  Widget _side() {
    final playing = widget.friends
        .where((f) => f.status == 'in_game' && f.gameId == game.id)
        .toList();
    final requirements = game.details['minimum_requirements'] is Map
        ? (game.details['minimum_requirements'] as Map)
        : const {};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KpPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Друзья в этой игре',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (playing.isEmpty)
          const Text('Сейчас никто из друзей не играет.',
              style: TextStyle(color: muted, fontSize: 13))
        else
          for (final f in playing)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FriendChip(friend: f)),
      ])),
      const SizedBox(height: 14),
      KpPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Сведения', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (game.company.isNotEmpty) _Info('Разработчик', game.company),
        if (game.genre.isNotEmpty) _Info('Жанр', game.genre),
        if (game.platforms.isNotEmpty)
          _Info('Платформы', game.platforms.join(', ')),
        if (game.version.isNotEmpty) _Info('Версия', game.version),
        _Info('Цена', game.priceLabel),
      ])),
      if (requirements.isNotEmpty) ...[
        const SizedBox(height: 14),
        KpPanel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Системные требования',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final e in requirements.entries)
            if (e.value != null && '${e.value}'.isNotEmpty)
              _Info(
                  const {
                        'os': 'Система',
                        'processor': 'Процессор',
                        'memory': 'Память',
                        'graphics': 'Видеокарта',
                        'storage': 'На диске'
                      }[e.key] ??
                      '${e.key}',
                  '${e.value}'),
        ])),
      ],
    ]);
  }
}

class _Hero extends StatelessWidget {
  final Game game;
  final GameActions actions;
  final bool wide;
  const _Hero({required this.game, required this.actions, required this.wide});
  @override
  Widget build(BuildContext context) {
    final prefs = actions.downloads.prefs;
    final favorite = prefs.isFavorite(game.id);
    return SizedBox(
        height: wide ? 320 : 220,
        child: Stack(fit: StackFit.expand, children: [
          Artwork(game.banner, label: game.title),
          const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x330A0B12), Kp.bg],
                      stops: [.3, 1]))),
          Positioned(
              top: 12,
              right: 12,
              child: Row(children: [
                IconButton.filledTonal(
                    tooltip: favorite ? 'Убрать из избранного' : 'В избранное',
                    onPressed: () => prefs.toggleFavorite(game.id),
                    icon: Icon(
                        favorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: favorite ? Kp.lilac : null)),
                if (!wide && Navigator.of(context).canPop()) ...[
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ],
              ])),
          Positioned(
              left: wide ? 28 : 16,
              right: wide ? 28 : 16,
              bottom: 8,
              child: Text(game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: wide ? 38 : 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 16)
                      ]))),
        ]));
  }
}

class _ActionBar extends StatelessWidget {
  final GameActions actions;
  final Future<int>? size;
  final bool wide;
  const _ActionBar(
      {required this.actions, required this.size, required this.wide});
  @override
  Widget build(BuildContext context) {
    final a = actions, d = a.downloads, g = a.game;
    final job = d.jobs[g.id];
    final main = a.primary;
    final button = _BigButton(
        label: main.label,
        icon: main.icon,
        onTap: main.onTap,
        cancel: job?.active == true);
    final stats = [
      _Stat('Последний запуск', lastPlayedLabel(d.prefs.lastPlayed(g.id))),
      _Stat('Время в игре', playTimeLabel(d.prefs.playTime(g.id))),
      if (size != null)
        FutureBuilder<int>(
            future: size,
            builder: (context, s) =>
                _Stat('На диске', s.data == null ? '…' : formatBytes(s.data!)))
      else
        _Stat('Статус', d.hasInstall(g) ? 'Установлено' : 'Не установлено'),
      _Stat(
          'Версия', d.installed[g.id] ?? (g.version.isEmpty ? '—' : g.version)),
    ];
    final tools = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          tooltip: 'Страница в магазине',
          onPressed: a.store,
          icon: const Icon(Icons.storefront_rounded)),
      if (d.locations.containsKey(g.id))
        IconButton(
            tooltip: 'Открыть папку игры',
            onPressed: a.openFolder,
            icon: const Icon(Icons.folder_open_rounded)),
      IconButton(
          tooltip: 'Свойства',
          onPressed: a.properties,
          icon: const Icon(Icons.settings_rounded)),
      Builder(
          builder: (context) => IconButton(
              tooltip: 'Ещё',
              onPressed: () {
                final box = context.findRenderObject() as RenderBox;
                a.showMenuAt(
                    box.localToGlobal(box.size.bottomLeft(Offset.zero)));
              },
              icon: const Icon(Icons.more_horiz_rounded))),
    ]);
    return KpPanel(
        padding: const EdgeInsets.all(14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (wide)
            Row(children: [
              button,
              const SizedBox(width: 18),
              Expanded(
                  child: Wrap(spacing: 26, runSpacing: 10, children: stats)),
              tools,
            ])
          else ...[
            button,
            const SizedBox(height: 14),
            GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3.6,
                children: stats),
            Align(alignment: Alignment.centerRight, child: tools),
          ],
          if (job != null && (job.active || job.error != null)) ...[
            const SizedBox(height: 12),
            Text(job.error ?? job.label,
                style: TextStyle(
                    color: job.error != null ? Kp.error : muted, fontSize: 12)),
            if (job.active)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(value: job.progress)),
          ],
          if (d.moving[g.id] != null) ...[
            const SizedBox(height: 12),
            Text('Перенос ${(d.moving[g.id]! * 100).round()}%',
                style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: d.moving[g.id]),
          ],
          if (!a.canInstall && !d.isCurrent(g)) ...[
            const SizedBox(height: 10),
            Text(
                !d.supported
                    ? 'Игры устанавливаются в клиенте Keep Pixel для Windows.'
                    : !g.released
                        ? 'Игра в разработке. Установка появится после первого релиза.'
                        : 'Разработчик ещё не опубликовал сборку для Windows.',
                style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ]));
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool cancel;
  const _BigButton(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.cancel = false});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      enabled: onTap != null,
      child: Hovered(
          onTap: onTap,
          builder: (context, hover) => AnimatedOpacity(
              duration: Kp.motion,
              opacity: onTap == null ? .5 : 1,
              child: AnimatedContainer(
                  duration: Kp.motion,
                  height: 54,
                  constraints: const BoxConstraints(minWidth: 190),
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  decoration: BoxDecoration(
                      borderRadius: Kp.r14,
                      gradient: cancel ? null : Kp.gradient,
                      color: cancel ? Kp.raised : null,
                      border: cancel ? Border.all(color: Kp.line) : null,
                      boxShadow: cancel
                          ? null
                          : [
                              BoxShadow(
                                  color: Kp.violet
                                      .withValues(alpha: hover ? .6 : .3),
                                  blurRadius: hover ? 28 : 18)
                            ]),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: Colors.white, size: 26),
                        const SizedBox(width: 10),
                        Text(label.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                letterSpacing: .8,
                                fontWeight: FontWeight.w800)),
                      ])))));
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]);
}

class _UpdateBanner extends StatelessWidget {
  final Game game;
  final GameActions actions;
  const _UpdateBanner({required this.game, required this.actions});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
          color: Kp.violet.withValues(alpha: .14),
          borderRadius: Kp.r14,
          border: Border.all(color: Kp.violet.withValues(alpha: .5))),
      child: Row(children: [
        const Icon(Icons.system_update_alt_rounded, color: Kp.lilac),
        const SizedBox(width: 12),
        Expanded(
            child: Text(
                'Доступно обновление ${actions.downloads.installed[game.id]} → ${game.version}',
                style: const TextStyle(fontWeight: FontWeight.w600))),
        TextButton(onPressed: actions.install, child: const Text('Обновить')),
      ]));
}

class _Info extends StatelessWidget {
  final String label, value;
  const _Info(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 104,
            child: Text(label,
                style: const TextStyle(color: muted, fontSize: 12))),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600))),
      ]));
}
