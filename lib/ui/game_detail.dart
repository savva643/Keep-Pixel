import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/downloads.dart';
import '../core/models.dart';
import 'auth_dialog.dart';
import 'game_actions.dart';
import 'shared.dart';

/// Opens a game's store page over the app, on a computer and on a phone.
Future<void> showGame(
        BuildContext context, PixelApi api, Game game, VoidCallback onChanged,
        {required DownloadsController downloads}) =>
    Navigator.of(context).push(PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => GameDetail(
            api: api,
            initial: game,
            onChanged: onChanged,
            downloads: downloads),
        transitionsBuilder: (_, animation, __, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                  position: Tween(begin: const Offset(0, .04), end: Offset.zero)
                      .animate(curved),
                  child: child));
        }));

/// A picture or a video in the gallery.
typedef _Media = ({String image, String? video});

List<_Media> _mediaOf(Game g) {
  final m = g.metadata, d = g.details;
  String? text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
  final out = <_Media>[];
  final trailer =
      text(m['trailer']) ?? text(m['trailer_url']) ?? text(d['trailer']);
  if (trailer != null) {
    out.add((
      image: text(m['trailer_preview']) ?? text(g.banner) ?? '',
      video: trailer
    ));
  }
  final shots = m['screenshots'] ?? m['media'] ?? d['screenshots'];
  if (shots is List) {
    for (final s in shots) {
      if (s is String && s.isNotEmpty) {
        out.add((image: s, video: null));
      } else if (s is Map) {
        final image = text(s['url']) ?? text(s['image']) ?? text(s['preview']);
        if (image != null) out.add((image: image, video: text(s['video'])));
      }
    }
  }
  if (out.isEmpty && g.banner.isNotEmpty) {
    out.add((image: g.banner, video: null));
  }
  if (g.cover.isNotEmpty && out.every((x) => x.image != g.cover)) {
    out.add((image: g.cover, video: null));
  }
  return out;
}

/// Achievements the developer described: title, description and icon.
List<({String title, String description, String icon})> _achievementsOf(
    Game g) {
  final raw = g.metadata['achievements'] ?? g.details['achievements'];
  if (raw is! List) return const [];
  return [
    for (final a in raw)
      if (a is Map)
        (
          title: '${a['title'] ?? a['name'] ?? ''}',
          description: '${a['description'] ?? ''}',
          icon: '${a['icon'] ?? a['image'] ?? ''}'
        )
  ].where((a) => a.title.isNotEmpty).toList();
}

class GameDetail extends StatefulWidget {
  final PixelApi api;
  final Game initial;
  final VoidCallback onChanged;
  final DownloadsController downloads;
  const GameDetail(
      {super.key,
      required this.api,
      required this.initial,
      required this.onChanged,
      required this.downloads});
  @override
  State<GameDetail> createState() => _GameDetailState();
}

class _GameDetailState extends State<GameDetail> {
  late Game game;
  bool owned = false, loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    game = widget.initial;
    owned = game.owned;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final detail = await widget.api.game(game.id);
      final library = widget.initial.owned
          ? [widget.initial]
          : widget.api.signedIn
              ? await widget.api.library()
              : <Game>[];
      if (mounted) {
        setState(() {
          game = detail;
          owned = library.any((g) => g.id == game.id);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> claim() async {
    if (busy) return;
    if (!widget.api.signedIn && !await showLogin(context, widget.api)) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await widget.api.claim(game.id);
      if (mounted) {
        setState(() => owned = true);
        notice(context, 'Игра добавлена в библиотеку');
      }
      widget.onChanged();
    } catch (e) {
      if (mounted) notice(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> launch() async {
    setState(() => busy = true);
    try {
      await widget.downloads.launch(game);
    } catch (e) {
      if (mounted) notice(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> uninstall() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Удалить установленные файлы?'),
                content: Text(
                    '${game.title} останется в библиотеке. Файлы игры в папке установки будут удалены.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Удалить'))
                ]));
    if (ok != true) return;
    try {
      await widget.downloads.uninstall(game);
    } catch (e) {
      if (mounted) notice(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Kp.bg,
      body: ListenableBuilder(
          listenable: widget.downloads,
          builder: (context, _) => LayoutBuilder(builder: (context, box) {
                final wide = box.maxWidth >= 980;
                final gutter = box.maxWidth > 700 ? 32.0 : 16.0;
                final media = _mediaOf(game);
                final mainColumn = [
                  if (media.isNotEmpty) ...[
                    _Gallery(media: media, title: game.title),
                    const SizedBox(height: 32),
                  ],
                  ..._about(),
                  ..._achievements(),
                  ..._updates(),
                  ..._reviews(),
                ];
                final sideColumn = [
                  _actionCard(),
                  const SizedBox(height: 16),
                  _infoCard(),
                  ..._online(),
                  ..._requirements(),
                  ..._links(),
                ];
                return CustomScrollView(slivers: [
                  SliverToBoxAdapter(
                      child: _Hero(game: game, owned: owned, wide: wide)),
                  SliverPadding(
                      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 48),
                      sliver: SliverToBoxAdapter(
                          child: Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 1240),
                                  child: wide
                                      ? Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: mainColumn)),
                                              const SizedBox(width: 28),
                                              SizedBox(
                                                  width: 360,
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: sideColumn)),
                                            ])
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                              _actionCard(),
                                              const SizedBox(height: 24),
                                              ...mainColumn,
                                              const SizedBox(height: 8),
                                              _infoCard(),
                                              ..._online(),
                                              ..._requirements(),
                                              ..._links(),
                                            ]))))),
                ]);
              })));

  Widget _actionCard() {
    final manager = widget.downloads, job = manager.jobs[game.id];
    final installed = manager.isCurrent(game);
    final children = <Widget>[];
    if (loading) {
      children.add(const LinearProgressIndicator());
    } else if (error != null) {
      children.addAll([
        Text(error!, style: const TextStyle(color: Kp.error)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить')),
      ]);
    } else if (!game.released) {
      children.add(const Text(
          'Игра в разработке. Установка появится после публикации первого релиза.',
          style: TextStyle(color: muted, height: 1.6)));
    } else if (owned &&
        manager.supported &&
        game.metadata['has_windows_build'] == true) {
      final running = manager.isRunning(game);
      children.addAll([
        if (job?.active == true)
          _BigButton(
              label: 'Отменить загрузку',
              icon: Icons.close_rounded,
              outlined: true,
              onTap: () => manager.cancel(game.id))
        else
          _BigButton(
              label: running
                  ? 'Запущено'
                  : installed
                      ? 'Играть'
                      : manager.hasInstall(game)
                          ? 'Обновить'
                          : 'Установить',
              icon:
                  installed ? Icons.play_arrow_rounded : Icons.download_rounded,
              onTap: busy || running
                  ? null
                  : installed
                      ? launch
                      : () => GameActions(context,
                              api: widget.api,
                              downloads: manager,
                              game: game,
                              onChanged: widget.onChanged)
                          .install()),
        if (job != null) ...[
          const SizedBox(height: 12),
          Text(job.label, style: const TextStyle(color: muted)),
          if (job.active)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: job.progress, minHeight: 6))),
          if (job.error != null)
            Text(job.error!, style: const TextStyle(color: Kp.error)),
        ],
        if (manager.hasInstall(game) && job?.active != true && !running)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                  onPressed: uninstall,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Удалить с устройства'))),
      ]);
    } else if (owned) {
      children.add(Text(
          game.metadata['has_windows_build'] == true
              ? 'Игра в библиотеке. Установка доступна в клиенте Keep Pixel для Windows.'
              : 'Игра в библиотеке. Разработчик ещё не опубликовал установочный файл.',
          style: const TextStyle(color: muted, height: 1.6)));
    } else if (game.price == 0) {
      children.add(_BigButton(
          label: busy ? 'Добавление…' : 'Добавить в библиотеку',
          icon: Icons.add_rounded,
          onTap: busy ? null : claim));
    } else {
      children.add(const Text(
          'Продажи пока не открыты. Покупка появится после подключения оплаты.',
          style: TextStyle(color: muted, height: 1.6)));
    }
    return _Panel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text(owned ? 'В библиотеке' : game.priceLabel,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800))),
        if (owned)
          const Icon(Icons.check_circle_rounded, color: Kp.online, size: 22),
      ]),
      const SizedBox(height: 14),
      ...children,
    ]));
  }

  List<Widget> _about() {
    final features = (game.details['features'] as List?) ?? const [];
    return [
      const KpHeading('Об игре'),
      const SizedBox(height: 14),
      SelectableText(
          game.description.isEmpty
              ? 'Автор пока не добавил описание.'
              : game.description,
          style: const TextStyle(color: muted, height: 1.85, fontSize: 15)),
      if (features.isNotEmpty) ...[
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in features) Tag('$f'),
        ]),
      ],
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _achievements() {
    final list = _achievementsOf(game);
    return [
      KpHeading('Достижения', trailing: list.isEmpty ? null : '${list.length}'),
      const SizedBox(height: 14),
      if (list.isEmpty)
        const _Panel(
            child: Row(children: [
          Icon(Icons.emoji_events_outlined, color: muted),
          SizedBox(width: 12),
          Expanded(
              child: Text('Разработчик пока не добавил достижения.',
                  style: TextStyle(color: muted))),
        ]))
      else
        LayoutBuilder(builder: (context, box) {
          final columns = (box.maxWidth / 300).floor().clamp(1, 3);
          final width = (box.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final a in list)
              SizedBox(
                  width: width,
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Kp.surface,
                          borderRadius: Kp.r14,
                          border: Border.all(color: Kp.line)),
                      child: Row(children: [
                        ClipRRect(
                            borderRadius: Kp.r10,
                            child: SizedBox.square(
                                dimension: 48,
                                child: a.icon.isEmpty
                                    ? const DecoratedBox(
                                        decoration: BoxDecoration(
                                            gradient: Kp.gradient),
                                        child: Icon(Icons.emoji_events_rounded,
                                            color: Colors.white))
                                    : Artwork(a.icon, label: a.title))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(a.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              if (a.description.isNotEmpty)
                                Text(a.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: muted, fontSize: 12)),
                            ])),
                      ]))),
          ]);
        }),
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _updates() {
    final updates = game.details['updates'];
    if (updates is! List || updates.isEmpty) return const [];
    return [
      const KpHeading('Обновления и новости'),
      const SizedBox(height: 14),
      for (final (i, u) in updates.take(5).indexed)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Panel(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          gradient: i == 0 ? Kp.gradient : null,
                          color: i == 0 ? null : Kp.raised,
                          borderRadius: Kp.r10),
                      child: Text('${u['version'] ?? ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12))),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${u['title'] ?? ''}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${u['description'] ?? ''}',
                            style: const TextStyle(color: muted, height: 1.6)),
                      ])),
                ]))),
      const SizedBox(height: 22),
    ];
  }

  List<Widget> _reviews() {
    final reviews = game.details['reviews'];
    if (reviews is! List || reviews.isEmpty) return const [];
    final ratings = [
      for (final r in reviews)
        if (r is Map && r['rating'] is num) (r['rating'] as num).toDouble()
    ];
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((a, b) => a + b) / ratings.length;
    return [
      KpHeading('Отзывы', trailing: '${reviews.length}'),
      const SizedBox(height: 14),
      if (average != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Text(average.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              for (var i = 1; i <= 5; i++)
                Icon(
                    average >= i - .25
                        ? Icons.star_rounded
                        : average >= i - .75
                            ? Icons.star_half_rounded
                            : Icons.star_outline_rounded,
                    color: const Color(0xFFF5B83D)),
            ])),
      for (final r in reviews.take(3))
        if (r is Map && '${r['review'] ?? ''}'.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Panel(
                  child: Text('${r['review']}',
                      style: const TextStyle(color: muted, height: 1.6)))),
      const SizedBox(height: 22),
    ];
  }

  Widget _infoCard() {
    String date(Object? v) {
      final d = DateTime.tryParse('${v ?? ''}');
      return d == null
          ? ''
          : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }

    final rows = [
      ('Разработчик', game.company),
      ('Издатель', '${game.details['publisher'] ?? ''}'),
      ('Дата выхода', date(game.details['release_date'])),
      ('Жанр', game.genre),
      ('Версия', game.version),
      ('Платформы', game.platforms.join(', ')),
    ].where((r) => r.$2.isNotEmpty && r.$2 != 'null').toList();
    return _Panel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Сведения',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      for (final (label, value) in rows)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 112,
                  child: Text(label,
                      style: const TextStyle(color: muted, fontSize: 13))),
              Expanded(
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600))),
            ])),
    ]));
  }

  List<Widget> _online() {
    final stats = game.details['online_stats'];
    if (stats is! List || stats.isEmpty || stats.first is! Map) return const [];
    final now = (stats.first as Map)['current_players'];
    final peak = (stats.first as Map)['peak_today'];
    if (now == null) return const [];
    return [
      const SizedBox(height: 16),
      _Panel(
          child: Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                const BoxDecoration(color: Kp.online, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Сейчас играют: $now',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (peak != null)
            Text('Пик за сегодня: $peak',
                style: const TextStyle(color: muted, fontSize: 12)),
        ])),
      ])),
    ];
  }

  List<Widget> _requirements() {
    final min = game.details['minimum_requirements'];
    final rec = game.details['recommended_requirements'];
    if (min is! Map && rec is! Map) return const [];
    return [
      const SizedBox(height: 16),
      _Panel(
          child: _Requirements(minimum: min as Map?, recommended: rec as Map?)),
    ];
  }

  List<Widget> _links() {
    final links = game.details['social_links'];
    if (links is! Map) return const [];
    final items = [
      ('web', 'Сайт', Icons.language_rounded),
      ('discord', 'Discord', Icons.forum_rounded),
      ('youtube', 'YouTube', Icons.smart_display_rounded),
      ('twitter', 'X / Twitter', Icons.alternate_email_rounded),
    ].where((l) => '${links[l.$1] ?? ''}'.startsWith('http')).toList();
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      _Panel(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (key, label, icon) in items)
          OutlinedButton.icon(
              onPressed: () => openLink(context, '${links[key]}'),
              icon: Icon(icon, size: 18),
              label: Text(label)),
      ])),
    ];
  }
}

class _Hero extends StatelessWidget {
  final Game game;
  final bool owned, wide;
  const _Hero({required this.game, required this.owned, required this.wide});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: wide ? 420 : 300,
      child: Stack(fit: StackFit.expand, children: [
        Artwork(game.banner, label: game.title),
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .45, 1],
                    colors: [Color(0x660A0B12), Color(0x000A0B12), Kp.bg]))),
        Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
                child: Material(
                    color: Colors.black.withValues(alpha: .45),
                    shape: const CircleBorder(),
                    child: IconButton(
                        tooltip: 'Назад',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white))))),
        Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: wide ? 32 : 16),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (wide && game.cover.isNotEmpty) ...[
                                ClipRRect(
                                    borderRadius: Kp.r20,
                                    child: SizedBox.square(
                                        dimension: 112,
                                        child: Artwork(game.cover,
                                            label: game.title))),
                                const SizedBox(width: 20),
                              ],
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(game.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: wide ? 40 : 28,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1,
                                            height: 1.1)),
                                    const SizedBox(height: 12),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      if (game.genre.isNotEmpty)
                                        Tag(game.genre),
                                      for (final p in game.platforms.take(4))
                                        Tag(p),
                                      if (!game.released)
                                        const Tag('В разработке'),
                                    ]),
                                  ])),
                            ]))))),
      ]));
}

/// Steam-style gallery: the big picture or trailer, arrows, and thumbnails.
class _Gallery extends StatefulWidget {
  final List<_Media> media;
  final String title;
  const _Gallery({required this.media, required this.title});
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final pages = PageController();
  final strip = ScrollController();
  int index = 0;
  bool hover = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    timer?.cancel();
    pages.dispose();
    strip.dispose();
    super.dispose();
  }

  // Pictures change by themselves until the player takes over.
  void _schedule() {
    timer?.cancel();
    if (widget.media.length < 2) return;
    timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!hover && mounted) _go(index + 1, auto: true);
    });
  }

  void _go(int i, {bool auto = false}) {
    final n = widget.media.length;
    final target = (i % n + n) % n;
    pages.animateToPage(target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic);
    if (!auto) _schedule();
  }

  void _open(int i) {
    final m = widget.media[i];
    if (m.video != null) {
      openLink(context, m.video!);
      return;
    }
    showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .9),
        builder: (_) => _Viewer(
            media: widget.media.where((x) => x.video == null).toList(),
            start: widget.media
                .where((x) => x.video == null)
                .toList()
                .indexOf(m)));
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final many = media.length > 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MouseRegion(
          onEnter: (_) => setState(() => hover = true),
          onExit: (_) => setState(() => hover = false),
          child: ClipRRect(
              borderRadius: Kp.r20,
              child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    PageView.builder(
                        controller: pages,
                        itemCount: media.length,
                        onPageChanged: (i) {
                          setState(() => index = i);
                          if (strip.hasClients) {
                            strip.animateTo(
                                (i * 124.0 - 124)
                                    .clamp(0, strip.position.maxScrollExtent),
                                duration: Kp.motion,
                                curve: Curves.easeOut);
                          }
                        },
                        itemBuilder: (context, i) => GestureDetector(
                            onTap: () => _open(i),
                            child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Stack(fit: StackFit.expand, children: [
                                  Artwork(media[i].image, label: widget.title),
                                  if (media[i].video != null)
                                    Center(
                                        child: Container(
                                            width: 76,
                                            height: 76,
                                            decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: .55),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2)),
                                            child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 46))),
                                ])))),
                    if (many) ...[
                      _Arrow(
                          left: true,
                          visible: hover,
                          onTap: () => _go(index - 1)),
                      _Arrow(
                          left: false,
                          visible: hover,
                          onTap: () => _go(index + 1)),
                      Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .55),
                                  borderRadius: Kp.r10),
                              child: Text('${index + 1} / ${media.length}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)))),
                    ],
                  ])))),
      if (many) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 66,
          child: ListView.separated(
              controller: strip,
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _go(i),
                  child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                          duration: Kp.motion,
                          width: 116,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                              borderRadius: Kp.r14,
                              border: Border.all(
                                  color: i == index
                                      ? Kp.violet
                                      : Colors.transparent,
                                  width: 2)),
                          child: AnimatedOpacity(
                              duration: Kp.motion,
                              opacity: i == index ? 1 : .55,
                              child: ClipRRect(
                                  borderRadius: Kp.r10,
                                  child: Stack(fit: StackFit.expand, children: [
                                    Artwork(media[i].image,
                                        label: widget.title),
                                    if (media[i].video != null)
                                      const Center(
                                          child: Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: Colors.white)),
                                  ]))))))),
        ),
      ],
    ]);
  }
}

class _Arrow extends StatelessWidget {
  final bool left, visible;
  final VoidCallback onTap;
  const _Arrow(
      {required this.left, required this.visible, required this.onTap});
  @override
  Widget build(BuildContext context) => Positioned(
      left: left ? 12 : null,
      right: left ? null : 12,
      top: 0,
      bottom: 0,
      child: Center(
          child: AnimatedOpacity(
              duration: Kp.motion,
              opacity: visible ? 1 : .0,
              child: Material(
                  color: Colors.black.withValues(alpha: .55),
                  shape: const CircleBorder(),
                  child: IconButton(
                      tooltip: left ? 'Назад' : 'Дальше',
                      onPressed: onTap,
                      icon: Icon(
                          left
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                          color: Colors.white))))));
}

/// Pictures on the whole screen, with zoom.
class _Viewer extends StatefulWidget {
  final List<_Media> media;
  final int start;
  const _Viewer({required this.media, required this.start});
  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final pages = PageController(initialPage: widget.start);
  late int index = widget.start;
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        PageView.builder(
            controller: pages,
            itemCount: widget.media.length,
            onPageChanged: (i) => setState(() => index = i),
            itemBuilder: (context, i) => InteractiveViewer(
                maxScale: 4,
                child: Center(
                    child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Artwork(widget.media[i].image))))),
        Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
                child: IconButton.filledTonal(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)))),
        if (widget.media.length > 1)
          Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                  child: Text('${index + 1} / ${widget.media.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700)))),
      ]);
}

class _Requirements extends StatefulWidget {
  final Map? minimum, recommended;
  const _Requirements({this.minimum, this.recommended});
  @override
  State<_Requirements> createState() => _RequirementsState();
}

class _RequirementsState extends State<_Requirements> {
  late bool recommended = widget.minimum == null;
  static const _labels = {
    'os': 'Система',
    'processor': 'Процессор',
    'memory': 'Память',
    'graphics': 'Видеокарта',
    'storage': 'На диске'
  };
  @override
  Widget build(BuildContext context) {
    final shown = (recommended ? widget.recommended : widget.minimum) ?? {};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Системные требования',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      if (widget.minimum != null && widget.recommended != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(spacing: 6, children: [
              KpChip(
                  label: 'Минимальные',
                  selected: !recommended,
                  onTap: () => setState(() => recommended = false)),
              KpChip(
                  label: 'Рекомендуемые',
                  selected: recommended,
                  onTap: () => setState(() => recommended = true)),
            ])),
      for (final e in shown.entries)
        if (e.value != null && '${e.value}'.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 112,
                    child: Text(_labels[e.key] ?? '${e.key}',
                        style: const TextStyle(color: muted, fontSize: 13))),
                Expanded(
                    child: Text('${e.value}',
                        style: const TextStyle(fontSize: 13))),
              ])),
    ]);
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Kp.surface,
          borderRadius: Kp.r20,
          border: Border.all(color: Kp.line)),
      child: child);
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool outlined;
  const _BigButton(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.outlined = false});
  @override
  Widget build(BuildContext context) {
    const style = ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, 54)),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Kp.r14)),
        textStyle: WidgetStatePropertyAll(TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w800)));
    return outlined
        ? OutlinedButton.icon(
            style: style,
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label))
        : FilledButton.icon(
            style: style,
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label));
  }
}
