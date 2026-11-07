import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/downloads.dart';
import '../core/models.dart';
import 'game_detail.dart';
import 'shared.dart';

class CatalogPage extends StatefulWidget {
  final PixelApi api;
  final bool library, searchInTopBar;
  final DownloadsController downloads;
  final VoidCallback onLibraryChanged;
  final TextEditingController? search;
  final VoidCallback? onOpenFriends, onSignIn;
  const CatalogPage(
      {super.key,
      required this.api,
      required this.downloads,
      this.library = false,
      this.searchInTopBar = false,
      this.search,
      this.onOpenFriends,
      this.onSignIn,
      required this.onLibraryChanged});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late final search = widget.search ?? TextEditingController();
  Timer? debounce;
  List<Game> games = [], owned = [];
  List<PixelFriend> online = [];
  String? error;
  bool loading = true, more = false, loadingMore = false;
  int filter = 0, generation = 0;
  String sort = 'newest', lastQuery = '';
  @override
  void initState() {
    super.initState();
    search.addListener(_searchChanged);
    lastQuery = search.text;
    load();
    _loadHome();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.removeListener(_searchChanged);
    if (widget.search == null) search.dispose();
    super.dispose();
  }

  void _searchChanged() {
    if (search.text == lastQuery) return;
    lastQuery = search.text;
    setState(() {});
    if (!widget.library) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 350), load);
    }
  }

  // Home sections come only from real responses: a failure just hides them.
  Future<void> _loadHome() async {
    if (widget.library || !widget.api.signedIn) return;
    try {
      final rows = await widget.api.library();
      if (mounted) setState(() => owned = rows);
    } catch (_) {}
    try {
      final rows = await widget.api.friends();
      if (mounted) {
        setState(() => online = rows
            .where((f) => f.status == 'online' || f.status == 'in_game')
            .toList());
      }
    } catch (_) {}
  }

  Future<void> load({bool append = false}) async {
    final request = ++generation;
    setState(() {
      error = null;
      if (append) {
        loadingMore = true;
      } else {
        loading = true;
      }
    });
    try {
      final rows = widget.library
          ? await widget.api.library()
          : await widget.api.games(
              query: search.text.trim(),
              offset: append ? games.length : 0,
              filter: ['all', 'free', 'development'][filter],
              sort: sort);
      if (!mounted || request != generation) return;
      setState(() {
        games = append ? [...games, ...rows] : rows;
        more = !widget.library && rows.length == 40;
      });
    } catch (e) {
      if (mounted && request == generation) setState(() => error = '$e');
    } finally {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  void details(Game game) =>
      showGame(context, widget.api, game, widget.onLibraryChanged,
          downloads: widget.downloads);

  Widget _catalog(List<Game> visible, Game? hero, double width) {
    final rest = visible.where((g) => g != hero).toList();
    final browsing = filter != 0 || search.text.isNotEmpty;
    final controls = browsing || games.length > 3;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: KpHeading(browsing ? 'Результаты' : 'Все игры',
                trailing:
                    loading || error != null ? null : '${visible.length}')),
        IconButton(
            tooltip: 'Обновить каталог',
            onPressed: () {
              load();
              _loadHome();
            },
            icon: const Icon(Icons.refresh, size: 20)),
        if (controls)
          PopupMenuButton<String>(
              tooltip: 'Сортировка',
              initialValue: sort,
              onSelected: (v) {
                setState(() => sort = v);
                load();
              },
              itemBuilder: (_) => const [
                    PopupMenuItem(value: 'newest', child: Text('Новые')),
                    PopupMenuItem(value: 'title', child: Text('По названию')),
                    PopupMenuItem(value: 'price', child: Text('По цене'))
                  ],
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        const {
                          'newest': 'Новые',
                          'title': 'По названию',
                          'price': 'По цене'
                        }[sort]!,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const Icon(Icons.expand_more_rounded,
                        size: 18, color: Kp.muted)
                  ])))
      ]),
      if (controls) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, name) in [
            (0, 'Все'),
            (1, 'Бесплатные'),
            (2, 'В разработке')
          ])
            KpChip(
                label: name,
                selected: filter == i,
                onTap: () {
                  setState(() => filter = i);
                  load();
                })
        ]),
      ],
      const SizedBox(height: 16),
      if (loading)
        const Padding(
            padding: EdgeInsets.all(72),
            child: Center(child: CircularProgressIndicator()))
      else if (error != null)
        StatePanel(
            icon: Icons.cloud_off_rounded,
            title:
                'Не удалось загрузить ${widget.library ? 'библиотеку' : 'каталог'}',
            description: error!,
            action: 'Повторить',
            onAction: load)
      else if (visible.isEmpty)
        StatePanel(
            icon:
                widget.library ? Icons.grid_view_rounded : Icons.search_rounded,
            title: games.isEmpty && search.text.isEmpty
                ? (widget.library
                    ? 'Здесь будут твои игры'
                    : 'Каталог скоро пополнится')
                : 'Ничего не найдено',
            description: widget.library && games.isEmpty
                ? 'Добавь бесплатную игру из магазина, и она появится в библиотеке.'
                : 'Попробуй другой запрос или фильтр.')
      else if (rest.isEmpty)
        const _GrowingCatalog()
      else
        GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: width > 1000
                    ? 4
                    : width > 720
                        ? 3
                        : 2,
                mainAxisExtent: width > 720 ? 270 : 226,
                crossAxisSpacing: width > 720 ? 16 : 12,
                mainAxisSpacing: width > 720 ? 16 : 12),
            itemCount: rest.length,
            itemBuilder: (_, i) => _GameCard(
                game: rest[i],
                library: widget.library,
                compact: width <= 720,
                onTap: () => details(rest[i]))),
      if (more && error == null)
        Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
                child: OutlinedButton(
                    onPressed: loadingMore ? null : () => load(append: true),
                    child: Text(loadingMore ? 'Загрузка…' : 'Показать ещё')))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final visible = games
        .where((g) =>
            (!widget.library ||
                g.title.toLowerCase().contains(search.text.toLowerCase())) &&
            (filter == 0 ||
                (filter == 1 ? g.price == 0 && g.released : !g.released)))
        .toList();
    final home = !widget.library &&
        search.text.isEmpty &&
        filter == 0 &&
        !loading &&
        error == null;
    final hero = home && visible.isNotEmpty ? visible.first : null;
    final inset = MediaQuery.paddingOf(context).bottom;
    return RefreshIndicator(
        onRefresh: load,
        child: LayoutBuilder(builder: (context, box) {
          final gutter = box.maxWidth > 700 ? 32.0 : 16.0;
          final content = (box.maxWidth - gutter * 2).clamp(0.0, 1380.0);
          final twoColumns = content >= 1000;
          final mainWidth = twoColumns ? content - 340 : content;
          final playing = home
              ? owned.where(widget.downloads.hasInstall).toList()
              : const <Game>[];
          final sidebar = home
              ? [
                  _FriendsPanel(
                      signedIn: widget.api.signedIn,
                      online: online,
                      onOpenFriends: widget.onOpenFriends,
                      onSignIn: widget.onSignIn),
                  if (games.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _NewsPanel(games: games, onTap: details)
                  ]
                ]
              : const <Widget>[];
          final main =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (playing.isNotEmpty) ...[
              _ContinueRow(games: playing, onTap: details),
              const SizedBox(height: 28),
            ],
            _catalog(visible, hero, mainWidth),
          ]);
          return ListView(
              padding: EdgeInsets.fromLTRB(
                  gutter, gutter == 16 ? 12 : 20, gutter, inset + 28),
              children: [
                Center(
                    child: SizedBox(
                        width: content,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!widget.searchInTopBar) ...[
                                _PageSearch(controller: search),
                                const SizedBox(height: 14),
                              ],
                              if (hero != null) ...[
                                _Hero(
                                    game: hero,
                                    compact: content < 720,
                                    onTap: () => details(hero)),
                                SizedBox(height: gutter == 16 ? 22 : 28)
                              ],
                              if (twoColumns)
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: main),
                                      if (sidebar.isNotEmpty) ...[
                                        const SizedBox(width: 24),
                                        SizedBox(
                                            width: 316,
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: sidebar))
                                      ]
                                    ])
                              else ...[
                                main,
                                if (sidebar.isNotEmpty)
                                  const SizedBox(height: 22),
                                ...sidebar
                              ]
                            ]))),
              ]);
        }));
  }
}

class _PageSearch extends StatelessWidget {
  final TextEditingController controller;
  const _PageSearch({required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
          controller: controller,
          decoration: InputDecoration(
              hintText: 'Поиск игр и приложений',
              prefixIcon: const Icon(Icons.search_rounded, color: Kp.muted),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить поиск',
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close_rounded)))));
}

class _Hero extends StatelessWidget {
  final Game game;
  final bool compact;
  final VoidCallback onTap;
  const _Hero({required this.game, required this.compact, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ClipPath(
        clipper: const ShapeBorderClipper(
            shape: RoundedRectangleBorder(borderRadius: Kp.r24)),
        child: SizedBox(
            height: compact ? 420 : 440,
            child: Stack(fit: StackFit.expand, children: [
              Artwork(game.banner, label: game.title),
              DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: compact
                          ? const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              stops: [
                                  0,
                                  .55,
                                  1
                                ],
                              colors: [
                                  Color(0xF20A0B0F),
                                  Color(0xB30A0B0F),
                                  Color(0x000A0B0F)
                                ])
                          : const LinearGradient(stops: [
                              0,
                              .42,
                              .8
                            ], colors: [
                              Color(0xF20A0B0F),
                              Color(0xA60A0B0F),
                              Color(0x000A0B0F)
                            ]))),
              Padding(
                  padding: EdgeInsets.all(compact ? 22 : 44),
                  child: Align(
                      alignment:
                          compact ? Alignment.bottomLeft : Alignment.centerLeft,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tag(game.released
                                    ? 'В ФОКУСЕ'
                                    : 'СКОРО В KEEP PIXEL'),
                                const SizedBox(height: 16),
                                Text(game.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: compact ? 28 : 42,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: compact ? -.8 : -1.4,
                                        height: 1.08)),
                                const SizedBox(height: 12),
                                Text(game.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Color(0xFFD4D7DE),
                                        height: 1.55,
                                        fontSize: 14)),
                                const SizedBox(height: 20),
                                Wrap(
                                    spacing: 14,
                                    runSpacing: 10,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      KpButton('Об игре', onTap: onTap),
                                      Text(game.priceLabel,
                                          style: const TextStyle(
                                              color: Kp.lilac,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14))
                                    ])
                              ])))),
            ])));
  }
}

class _ContinueRow extends StatelessWidget {
  final List<Game> games;
  final void Function(Game) onTap;
  const _ContinueRow({required this.games, required this.onTap});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const KpHeading('Продолжить играть'),
        const SizedBox(height: 14),
        SizedBox(
            height: 132,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: games.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(
                    width: 244,
                    child: _ContinueCard(
                        game: games[i], onTap: () => onTap(games[i])))))
      ]);
}

class _ContinueCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  const _ContinueCard({required this.game, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: game.title,
      child: Hovered(
          onTap: onTap,
          builder: (context, hover) => AnimatedContainer(
              duration: Kp.motion,
              foregroundDecoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                      borderRadius: Kp.r20,
                      side: BorderSide(
                          color: hover ? Kp.violet : Kp.line,
                          width: hover ? 2 : 1))),
              child: ClipPath(
                  clipper: const ShapeBorderClipper(
                      shape: RoundedRectangleBorder(borderRadius: Kp.r20)),
                  child: Stack(fit: StackFit.expand, children: [
                    Artwork(game.cover, label: game.title),
                    const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                          Color(0xE60A0B0F),
                          Color(0x000A0B0F)
                        ]))),
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                  child: Text(game.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.2,
                                          fontWeight: FontWeight.w800))),
                              const SizedBox(width: 8),
                              AnimatedContainer(
                                  duration: Kp.motion,
                                  padding: const EdgeInsets.all(5),
                                  decoration: ShapeDecoration(
                                      color: hover ? Kp.violet : Kp.bg,
                                      shape: const RoundedRectangleBorder(
                                          borderRadius: Kp.r10)),
                                  child: Icon(Icons.play_arrow_rounded,
                                      size: 20,
                                      color: hover ? Colors.white : Kp.lilac))
                            ]))
                  ])))));
}

class _FriendsPanel extends StatelessWidget {
  final bool signedIn;
  final List<PixelFriend> online;
  final VoidCallback? onOpenFriends, onSignIn;
  const _FriendsPanel(
      {required this.signedIn,
      required this.online,
      this.onOpenFriends,
      this.onSignIn});
  @override
  Widget build(BuildContext context) => KpPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KpHeading('Друзья в сети',
            trailing:
                signedIn && online.isNotEmpty ? '${online.length}' : null),
        const SizedBox(height: 14),
        if (!signedIn) ...[
          const Text('Войди, чтобы видеть, кто сейчас играет.',
              style: TextStyle(color: Kp.muted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: onSignIn, child: const Text('Войти в Necsoura'))
        ] else if (online.isEmpty) ...[
          const Text('Сейчас никого нет в сети.',
              style: TextStyle(color: Kp.muted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: onOpenFriends, child: const Text('Найти друзей'))
        ] else
          for (final friend in online.take(5))
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Hovered(
                    onTap: onOpenFriends,
                    builder: (context, hover) => Row(children: [
                          SizedBox.square(
                              dimension: 36,
                              child: ClipPath(
                                  clipper: const ShapeBorderClipper(
                                      shape: RoundedRectangleBorder(
                                          borderRadius: Kp.r10)),
                                  child: Artwork(friend.avatar,
                                      label: friend.name))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(friend.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: hover ? Kp.lilac : Kp.text)),
                                Text(
                                    friend.status == 'in_game' &&
                                            friend.gameTitle.isNotEmpty
                                        ? 'Играет: ${friend.gameTitle}'
                                        : 'В сети',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: friend.status == 'in_game'
                                            ? Kp.online
                                            : Kp.muted))
                              ]))
                        ])))
      ]));
}

/// Catalog changes are the only real news source so far: the backend has no
/// news feed, so nothing here is written by hand or invented.
class _NewsPanel extends StatelessWidget {
  final List<Game> games;
  final void Function(Game) onTap;
  const _NewsPanel({required this.games, required this.onTap});
  static const _months = [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек'
  ];
  @override
  Widget build(BuildContext context) {
    final items = <(DateTime, String, Game)>[];
    for (final g in games) {
      final created = DateTime.tryParse('${g.details['created_at']}');
      final updated = DateTime.tryParse('${g.details['updated_at']}');
      if (updated != null &&
          created != null &&
          updated.difference(created).inHours >= 24) {
        items.add((
          updated,
          g.version.isEmpty ? 'Обновление' : 'Обновление ${g.version}',
          g
        ));
      } else if (created != null) {
        items.add(
            (created, g.released ? 'Новое в каталоге' : 'Анонс в каталоге', g));
      }
    }
    if (items.isEmpty) return const SizedBox();
    items.sort((a, b) => b.$1.compareTo(a.$1));
    return KpPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const KpHeading('Новости'),
      const SizedBox(height: 14),
      for (final (date, label, game) in items.take(4))
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Hovered(
                onTap: () => onTap(game),
                builder: (context, hover) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 44,
                              child: Text(
                                  '${date.day} ${_months[date.month - 1]}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.5,
                                      color: Kp.muted,
                                      fontWeight: FontWeight.w600))),
                          const SizedBox(width: 8),
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
                                        color: hover ? Kp.lilac : Kp.text)),
                                Text(label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: Kp.muted))
                              ]))
                        ])))
    ]));
  }
}

class _GrowingCatalog extends StatelessWidget {
  const _GrowingCatalog();
  @override
  Widget build(BuildContext context) => KpPanel(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: SizedBox(
          width: double.infinity,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Image.asset('assets/images/logo.png', width: 40, height: 40),
            const SizedBox(height: 16),
            const Text('Каталог только начинается',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
                'Это пока единственный проект в Keep Pixel. Новые игры и приложения появятся здесь сразу после публикации.',
                style: TextStyle(color: Kp.muted, fontSize: 13, height: 1.6)),
          ])));
}

class _GameCard extends StatelessWidget {
  final Game game;
  final bool library, compact;
  final VoidCallback onTap;
  const _GameCard(
      {required this.game,
      required this.library,
      required this.compact,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
        button: true,
        label: game.title,
        child: Hovered(
            onTap: onTap,
            builder: (context, hover) => AnimatedContainer(
                duration: Kp.motion,
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, hover ? -3 : 0, 0),
                decoration: ShapeDecoration(
                    color: hover ? Kp.raised : Kp.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: Kp.r20,
                        side: BorderSide(color: hover ? Kp.violet : Kp.line))),
                child: ClipPath(
                    clipper: const ShapeBorderClipper(
                        shape: RoundedRectangleBorder(borderRadius: Kp.r20)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              height: compact ? 104 : 148,
                              child: Artwork(game.cover, label: game.title)),
                          Expanded(
                              child: Padding(
                                  padding: EdgeInsets.all(compact ? 12 : 16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            game.genre.isEmpty
                                                ? 'ИГРА'
                                                : game.genre.toUpperCase(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Kp.muted,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1)),
                                        const SizedBox(height: 6),
                                        Text(game.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: compact ? 14 : 15,
                                                height: 1.2,
                                                fontWeight: FontWeight.w700)),
                                        const Spacer(),
                                        Text(
                                            library
                                                ? 'В библиотеке'
                                                : game.priceLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: game.released
                                                    ? Kp.lilac
                                                    : Kp.lilac,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700))
                                      ])))
                        ])))));
  }
}
