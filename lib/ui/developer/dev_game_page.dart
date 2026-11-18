import 'dart:async';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/developer.dart';
import '../shared.dart';
import 'common.dart';
import 'sdk_kits.dart';

/// One game in the developer cabinet.
class DevGamePage extends StatefulWidget {
  final PixelApi api;
  final String gameId;
  final DeveloperAccount account;
  const DevGamePage(
      {super.key,
      required this.api,
      required this.gameId,
      required this.account});
  @override
  State<DevGamePage> createState() => _DevGamePageState();
}

class _DevGamePageState extends State<DevGamePage> {
  DevGame? game;
  String? error;
  Timer? poll;
  late final uploader = BuildUploader(widget.api);

  @override
  void initState() {
    super.initState();
    load();
    uploader.addListener(_uploaded);
  }

  @override
  void dispose() {
    poll?.cancel();
    uploader.removeListener(_uploaded);
    uploader.cancel();
    uploader.dispose();
    super.dispose();
  }

  void _uploaded() {
    if (!uploader.running) load();
  }

  Future<void> load() async {
    try {
      final g = await widget.api.developerGame(widget.gameId);
      if (!mounted) return;
      setState(() {
        game = g;
        error = null;
      });
      // Builds being checked change on their own: look again shortly.
      poll?.cancel();
      if (g.builds.any((b) => b.status == 'scanning')) {
        poll = Timer(const Duration(seconds: 8), load);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void apply(DevGame g) => setState(() => game = g);

  Future<void> run(Future<DevGame> Function() action, [String? done]) async {
    try {
      apply(await action());
      if (done != null && mounted) notice(context, done);
    } catch (e) {
      if (mounted) notice(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = game;
    return DefaultTabController(
        length: 5,
        child: Scaffold(
            appBar: AppBar(
                title: Text(g?.title ?? 'Игра',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                bottom: g == null
                    ? null
                    : const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
                        Tab(text: 'Обзор'),
                        Tab(text: 'Витрина'),
                        Tab(text: 'Медиа'),
                        Tab(text: 'Сборки'),
                        Tab(text: 'Публикация'),
                      ])),
            body: g == null
                ? error != null
                    ? StatePanel(
                        icon: Icons.cloud_off_rounded,
                        title: 'Не удалось открыть игру',
                        description: error!,
                        action: 'Повторить',
                        onAction: load)
                    : const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _Overview(page: this, game: g),
                    _Storefront(page: this, game: g),
                    _Media(page: this, game: g),
                    _Builds(page: this, game: g),
                    _Publishing(page: this, game: g),
                  ])));
  }
}

/* ---------------- Overview ---------------- */

class _Overview extends StatelessWidget {
  final _DevGamePageState page;
  final DevGame game;
  const _Overview({required this.page, required this.game});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Черновик', true),
      ('Проверка', game.status != 'draft'),
      ('Одобрена', ['approved', 'published', 'hidden'].contains(game.status)),
      ('Вышла', game.live),
    ];
    return KpPage(maxWidth: 900, children: [
      KpPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          StatusPill(gameStatus[game.status] ?? (game.status, Kp.muted)),
          StatusPill(storeStatus[game.storeStatus] ?? (game.storeStatus, Kp.muted)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          for (final (i, s) in steps.indexed) ...[
            Expanded(
                child: Column(children: [
              AnimatedContainer(
                  duration: Kp.motion,
                  height: 6,
                  decoration: BoxDecoration(
                      borderRadius: Kp.r10,
                      gradient: s.$2 ? Kp.gradient : null,
                      color: s.$2 ? null : Kp.line)),
              const SizedBox(height: 6),
              Text(s.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: s.$2 ? Kp.text : Kp.muted,
                      fontWeight: FontWeight.w600)),
            ])),
            if (i < steps.length - 1) const SizedBox(width: 6),
          ]
        ]),
      ])),
      const SizedBox(height: 14),
      if (game.reviewNote.isNotEmpty &&
          (game.status == 'changes' || game.storeStatus == 'changes' || game.status == 'rejected'))
        Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Callout(
                icon: game.status == 'rejected'
                    ? Icons.block_rounded
                    : Icons.edit_note_rounded,
                color: game.status == 'rejected' ? Kp.error : const Color(0xFFFBBF24),
                title: game.status == 'rejected'
                    ? 'Игра отклонена модерацией'
                    : 'Модератор просит исправить',
                text: game.reviewNote)),
      if (game.canSubmit) ...[
        if (game.missing.isNotEmpty)
          Callout(
              icon: Icons.checklist_rounded,
              color: Kp.lilac,
              title: 'Чтобы отправить на модерацию, заполните:',
              text: game.missing.map((m) => '• $m').join('\n'))
        else
          const Callout(
              icon: Icons.check_circle_rounded,
              color: Kp.online,
              title: 'Всё готово к модерации',
              text:
                  'Модератор проверит сборку и витрину. Обычно это занимает 1–3 дня.'),
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerLeft,
            child: KpButton('Отправить на модерацию',
                onTap: game.missing.isEmpty
                    ? () => page.run(
                        () => page.widget.api
                            .developerAction(game.id, 'submit'),
                        'Отправлено на модерацию')
                    : null)),
      ] else if (game.status == 'review')
        const Callout(
            icon: Icons.hourglass_top_rounded,
            color: Color(0xFFFBBF24),
            title: 'Игра на модерации',
            text:
                'Пока идёт проверка, витрину можно править: модератор увидит последнюю версию.'),
      if (game.status == 'approved' && game.publishMode != 'auto')
        Callout(
            icon: Icons.celebration_rounded,
            color: Kp.online,
            title: 'Игра одобрена',
            text: game.publishMode == 'scheduled'
                ? 'Выйдет ${formatDate(game.publishAt)}.'
                : 'Опубликуйте её на вкладке «Публикация».'),
      const SizedBox(height: 14),
      DevSection(title: 'История', children: [
        if (game.history.isEmpty)
          const Text('Пока пусто', style: TextStyle(color: Kp.muted)),
        for (final h in game.history)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: h['role'] == 'admin' ? Kp.lilac : Kp.muted)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(historyText[h['action']] ?? '${h['action']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          '${formatDate(DateTime.tryParse('${h['created_at']}'))}'
                          '${'${h['note'] ?? ''}'.isEmpty ? '' : ' · ${h['note']}'}',
                          style: const TextStyle(color: Kp.muted, fontSize: 12)),
                    ])),
              ])),
      ]),
      if (game.catalogId == null) ...[
        const SizedBox(height: 14),
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Kp.error),
                onPressed: () async {
                  final yes = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                              title: const Text('Удалить черновик?'),
                              content: const Text(
                                  'Витрина, картинки и сборки будут удалены.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Отмена')),
                                FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Kp.error),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Удалить')),
                              ]));
                  if (yes != true) return;
                  try {
                    await page.widget.api.deleteDeveloperGame(game.id);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) notice(context, '$e');
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Удалить черновик'))),
      ],
    ]);
  }
}

/* ---------------- Storefront ---------------- */

class _Storefront extends StatefulWidget {
  final _DevGamePageState page;
  final DevGame game;
  const _Storefront({required this.page, required this.game});
  @override
  State<_Storefront> createState() => _StorefrontState();
}

class _StorefrontState extends State<_Storefront>
    with AutomaticKeepAliveClientMixin {
  static const genres = [
    'Экшен', 'Приключения', 'Гонки', 'Шутер', 'Стратегия', 'РПГ', 'Симулятор',
    'Головоломка', 'Платформер', 'Хоррор', 'Спорт', 'Файтинг', 'Казуальная', 'Инди'
  ];
  static const ages = ['', '0+', '6+', '12+', '16+', '18+'];
  late DevGame g = widget.game;
  late final c = <String, TextEditingController>{
    'title': TextEditingController(text: g.title),
    'short_description': TextEditingController(text: g.shortDescription),
    'description': TextEditingController(text: g.description),
    'tags': TextEditingController(text: g.tags.join(', ')),
    'features': TextEditingController(text: g.features.join(', ')),
    'languages': TextEditingController(text: g.languages.join(', ')),
    'trailer': TextEditingController(text: g.trailer),
    for (final k in ['web', 'discord', 'youtube', 'twitter'])
      'social.$k': TextEditingController(text: '${g.social[k] ?? ''}'),
    for (final t in ['minimum', 'recommended'])
      for (final k in ['os', 'processor', 'memory', 'graphics', 'storage'])
        '$t.$k': TextEditingController(
            text: '${(g.requirements[t] as Map?)?[k] ?? ''}'),
  };
  late String genre = g.genre, age = g.ageRating, engine = g.engine;
  late List<Map<String, dynamic>> achievements = g.achievements;
  bool busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  List<String> split(String key) => c[key]!
      .text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> save() async {
    setState(() => busy = true);
    await widget.page.run(
        () => widget.page.widget.api.updateDeveloperGame(g.id, {
              'title': c['title']!.text,
              'short_description': c['short_description']!.text,
              'description': c['description']!.text,
              'genre': genre,
              'age_rating': age,
              'engine': engine,
              'tags': split('tags'),
              'features': split('features'),
              'languages': split('languages'),
              'trailer': c['trailer']!.text.trim(),
              'social': {
                for (final k in ['web', 'discord', 'youtube', 'twitter'])
                  k: c['social.$k']!.text.trim()
              },
              'requirements': {
                for (final t in ['minimum', 'recommended'])
                  t: {
                    for (final k in ['os', 'processor', 'memory', 'graphics', 'storage'])
                      k: c['$t.$k']!.text.trim()
                  }
              },
              'achievements': achievements,
            }),
        'Витрина сохранена');
    if (mounted) setState(() => busy = false);
  }

  Widget text(String key, String label,
          {String? hint, int lines = 1, int? max, TextInputType? type}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
              controller: c[key],
              enabled: g.editable,
              minLines: lines,
              maxLines: lines == 1 ? 1 : 14,
              maxLength: max,
              keyboardType: type,
              decoration: InputDecoration(labelText: label, hintText: hint)));

  Widget pick(String label, String value, Map<String, String> options,
          ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
          initialValue: options.containsKey(value) ? value : options.keys.first,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final e in options.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value))
          ],
          onChanged: g.editable ? (v) => setState(() => onChanged(v ?? '')) : null);

  Future<void> editAchievement([int? index]) async {
    final a = index == null ? <String, dynamic>{} : achievements[index];
    final title = TextEditingController(text: '${a['title'] ?? ''}');
    final desc = TextEditingController(text: '${a['description'] ?? ''}');
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(index == null ? 'Новое достижение' : 'Достижение'),
                content: SizedBox(
                    width: 400,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: title,
                          maxLength: 80,
                          decoration:
                              const InputDecoration(labelText: 'Название')),
                      TextField(
                          controller: desc,
                          maxLength: 200,
                          decoration: const InputDecoration(
                              labelText: 'Как получить')),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Готово')),
                ]));
    if (ok == true && title.text.trim().isNotEmpty) {
      setState(() {
        final item = {'title': title.text.trim(), 'description': desc.text.trim()};
        if (index == null) {
          achievements = [...achievements, item];
        } else {
          achievements = [...achievements]..[index] = item;
        }
      });
    }
    Future.delayed(const Duration(seconds: 1), () {
      title.dispose();
      desc.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wide = MediaQuery.sizeOf(context).width > 760;
    Widget pair(Widget a, Widget b) => wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b)
          ])
        : Column(children: [a, const SizedBox(height: 12), b]);
    return KpPage(maxWidth: 900, children: [
      if (g.live)
        const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Callout(
                icon: Icons.info_outline_rounded,
                color: Kp.lilac,
                title: 'Игра уже в магазине',
                text:
                    'Изменения витрины увидят игроки после проверки модератором.')),
      DevSection(title: 'Основное', children: [
        text('title', 'Название', max: 120),
        text('short_description', 'Краткое описание',
            hint: 'Одно предложение для карточки в магазине', max: 300, lines: 2),
        text('description', 'Описание',
            hint: 'Об игре, режимы, особенности (от 100 символов)',
            lines: 6,
            max: 20000),
        pair(
            pick('Жанр', genre, {
              '': 'Не выбран',
              for (final x in {...genres, if (genre.isNotEmpty) genre}) x: x
            }, (v) => genre = v),
            pick('Возраст', age, {for (final x in ages) x: x.isEmpty ? 'Не указан' : x},
                (v) => age = v)),
        const SizedBox(height: 12),
        pick('Движок', engine, engines, (v) => engine = v),
        const SizedBox(height: 12),
        text('tags', 'Метки', hint: 'Через запятую: гонки, футуризм, аркада'),
        text('features', 'Особенности',
            hint: 'Через запятую: мультиплеер, поддержка геймпада'),
        text('languages', 'Языки', hint: 'Через запятую: Русский, English'),
        text('trailer', 'Трейлер',
            hint: 'Ссылка на YouTube или видео', type: TextInputType.url),
      ]),
      const SizedBox(height: 14),
      DevSection(title: 'Системные требования', children: [
        pair(
            Column(children: [
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Минимальные',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              for (final (k, l) in const [('os', 'ОС'), ('processor', 'Процессор'), ('memory', 'Память'), ('graphics', 'Видеокарта'), ('storage', 'Место на диске')])
                text('minimum.$k', l),
            ]),
            Column(children: [
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Рекомендуемые',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              for (final (k, l) in const [('os', 'ОС'), ('processor', 'Процессор'), ('memory', 'Память'), ('graphics', 'Видеокарта'), ('storage', 'Место на диске')])
                text('recommended.$k', l),
            ])),
      ]),
      const SizedBox(height: 14),
      DevSection(
          title: 'Достижения',
          subtitle:
              'Покажутся на странице игры. Выдавать их будет SDK, когда он научится (скоро).',
          trailing: IconButton(
              tooltip: 'Добавить',
              onPressed: g.editable ? () => editAchievement() : null,
              icon: const Icon(Icons.add_rounded)),
          children: [
            if (achievements.isEmpty)
              const Text('Нет достижений', style: TextStyle(color: Kp.muted)),
            for (final (i, a) in achievements.indexed)
              Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.emoji_events_rounded, color: Kp.lilac),
                  title: Text('${a['title']}'),
                  subtitle: Text('${a['description'] ?? ''}'),
                  onTap: g.editable ? () => editAchievement(i) : null,
                  trailing: IconButton(
                      onPressed: g.editable
                          ? () => setState(() => achievements = [...achievements]..removeAt(i))
                          : null,
                      icon: const Icon(Icons.close_rounded)))),
          ]),
      const SizedBox(height: 14),
      DevSection(title: 'Ссылки', children: [
        text('social.web', 'Сайт', type: TextInputType.url),
        text('social.discord', 'Discord', type: TextInputType.url),
        text('social.youtube', 'YouTube', type: TextInputType.url),
        text('social.twitter', 'X / Twitter', type: TextInputType.url),
      ]),
      const SizedBox(height: 18),
      Align(
          alignment: Alignment.centerLeft,
          child: KpButton(busy ? 'Сохраняем…' : 'Сохранить витрину',
              onTap: busy || !g.editable ? null : save)),
    ]);
  }
}

/* ---------------- Media ---------------- */

class _Media extends StatefulWidget {
  final _DevGamePageState page;
  final DevGame game;
  const _Media({required this.page, required this.game});
  @override
  State<_Media> createState() => _MediaState();
}

class _MediaState extends State<_Media> {
  String? uploading;

  Future<void> upload(String kind) async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif'],
        allowMultiple: kind == 'screenshot',
        withData: true);
    if (picked == null) return;
    for (final f in picked.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (bytes.length > 12 * 1024 * 1024) {
        if (mounted) notice(context, '${f.name}: больше 12 МБ');
        continue;
      }
      setState(() => uploading = kind);
      await widget.page.run(() =>
          widget.page.widget.api.uploadStoreImage(widget.game.id, kind, bytes));
    }
    if (mounted) setState(() => uploading = null);
  }

  Future<void> reorder(List<String> shots) => widget.page.run(() => widget
      .page.widget.api
      .updateDeveloperGame(widget.game.id, {'screenshots': shots}));

  Widget slot(String kind, String title, String hint, String url, double ratio) =>
      DevSection(title: title, subtitle: hint, children: [
        Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: ratio < 1 ? 220 : 640),
                child: AspectRatio(
                    aspectRatio: ratio,
                    child: ClipRRect(
                        borderRadius: Kp.r14,
                        child: url.isEmpty
                            ? Container(
                                color: Kp.raised,
                                child: const Icon(Icons.image_outlined,
                                    color: Kp.muted, size: 36))
                            : Artwork(url, label: widget.game.title))))),
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
                onPressed: uploading == null && widget.game.editable
                    ? () => upload(kind)
                    : null,
                icon: uploading == kind
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(url.isEmpty ? 'Загрузить' : 'Заменить'))),
      ]);

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final shots = g.screenshots;
    return KpPage(maxWidth: 900, children: [
      slot('cover', 'Обложка', 'Вертикальная 3:4, например 600×800. Показывается в библиотеке и магазине.', g.cover, 3 / 4),
      const SizedBox(height: 14),
      slot('banner', 'Баннер', 'Широкая картинка 1920×620 для шапки страницы игры.', g.banner, 1920 / 620),
      const SizedBox(height: 14),
      DevSection(
          title: 'Скриншоты',
          subtitle: 'От 2 до 12 картинок 16:9. Первая будет главной в карусели.',
          trailing: IconButton(
              tooltip: 'Добавить',
              onPressed: uploading == null && shots.length < 12 && g.editable
                  ? () => upload('screenshot')
                  : null,
              icon: uploading == 'screenshot'
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_rounded)),
          children: [
            if (shots.isEmpty)
              const Text('Скриншотов пока нет', style: TextStyle(color: Kp.muted)),
            LayoutBuilder(builder: (context, box) {
              final columns = box.maxWidth > 700 ? 3 : box.maxWidth > 420 ? 2 : 1;
              final width = (box.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                for (final (i, s) in shots.indexed)
                  SizedBox(
                      width: width,
                      child: Column(children: [
                        AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                                borderRadius: Kp.r10, child: Artwork(s, label: g.title))),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          IconButton(
                              tooltip: 'Левее',
                              onPressed: i == 0 || !g.editable
                                  ? null
                                  : () => reorder([...shots]
                                    ..removeAt(i)
                                    ..insert(i - 1, s)),
                              icon: const Icon(Icons.chevron_left_rounded)),
                          IconButton(
                              tooltip: 'Удалить',
                              onPressed: g.editable
                                  ? () => reorder([...shots]..removeAt(i))
                                  : null,
                              icon: const Icon(Icons.delete_outline_rounded)),
                          IconButton(
                              tooltip: 'Правее',
                              onPressed: i == shots.length - 1 || !g.editable
                                  ? null
                                  : () => reorder([...shots]
                                    ..removeAt(i)
                                    ..insert(i + 1, s)),
                              icon: const Icon(Icons.chevron_right_rounded)),
                        ]),
                      ])),
              ]);
            }),
          ]),
    ]);
  }
}

/* ---------------- Builds ---------------- */

/// The .exe files of a ZIP, read from its directory without unpacking.
Future<List<String>> _executables(String path) => compute(_listExe, path);
List<String> _listExe(String path) {
  final input = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final exes = archive.files
        .where((f) => f.isFile && f.name.toLowerCase().endsWith('.exe'))
        .map((f) => f.name.replaceAll('\\', '/'))
        .toList();
    // Shipping executables first, crash reporters and redistributables last.
    int rank(String n) {
      final l = n.toLowerCase();
      if (l.contains('crash') || l.contains('redist') || l.contains('prereq') || l.contains('unins')) return 3;
      if (l.contains('/binaries/win64/')) return 0;
      return '/'.allMatches(n).length;
    }
    exes.sort((a, b) => rank(a).compareTo(rank(b)));
    return exes;
  } finally {
    input.closeSync();
  }
}

class _Builds extends StatefulWidget {
  final _DevGamePageState page;
  final DevGame game;
  const _Builds({required this.page, required this.game});
  @override
  State<_Builds> createState() => _BuildsState();
}

class _BuildsState extends State<_Builds> with AutomaticKeepAliveClientMixin {
  final version = TextEditingController(), notes = TextEditingController();
  String? file, exe;
  int? size;
  List<String> exes = const [];
  bool reading = false;
  ({String buildId, String file})? pending;

  BuildUploader get up => widget.page.uploader;
  bool get canUpload =>
      !kIsWeb &&
      {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS}
          .contains(defaultTargetPlatform);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      BuildUploader.pending(widget.game.id).then((p) {
        if (mounted) setState(() => pending = p);
      });
    }
  }

  @override
  void dispose() {
    version.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: const ['zip'], withData: false);
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() {
      reading = true;
      file = path;
      size = picked!.files.single.size;
      exes = const [];
      exe = null;
    });
    try {
      final list = await _executables(path);
      if (mounted) {
        setState(() {
          exes = list;
          exe = list.firstOrNull;
        });
      }
      if (list.isEmpty && mounted) notice(context, 'В архиве нет .exe');
    } catch (e) {
      if (mounted) notice(context, 'Не удалось прочитать ZIP: $e');
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final g = widget.game;
    final limit = widget.page.widget.account.maxBuild;
    return KpPage(maxWidth: 900, children: [
      DevSection(
          title: 'Новая сборка',
          subtitle:
              'ZIP-архив с папкой игры для Windows. Лаунчер распакует его и будет запускать указанный .exe. '
              'Большие архивы загружаются частями: если связь оборвётся, загрузка продолжится с того же места. '
              'Предел ${formatBytes(limit)}.',
          children: [
            if (!canUpload)
              const Callout(
                  icon: Icons.computer_rounded,
                  color: Kp.lilac,
                  title: 'Сборки загружаются из Keep Pixel на компьютере',
                  text: 'Витрину и публикацию можно настроить и отсюда.')
            else ...[
              if (pending != null && !up.running)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Callout(
                        icon: Icons.pause_circle_rounded,
                        color: const Color(0xFFFBBF24),
                        title: 'Загрузка прервалась',
                        text: pending!.file,
                        child: Wrap(spacing: 8, children: [
                          FilledButton(
                              onPressed: () {
                                final p = pending!;
                                setState(() => pending = null);
                                up.resume(g.id, p.buildId, p.file);
                              },
                              child: const Text('Продолжить')),
                        ]))),
              ListenableBuilder(
                  listenable: up,
                  builder: (context, _) => up.running ||
                          (up.stage != null && up.gameId == g.id)
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(up.error ?? up.stage ?? '',
                                    style: TextStyle(
                                        color: up.error != null ? Kp.error : Kp.text,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                    value: up.running && up.progress == 0 ? null : up.progress,
                                    borderRadius: Kp.r10,
                                    minHeight: 8),
                                if (up.running)
                                  Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                          onPressed: up.cancel,
                                          child: const Text('Приостановить'))),
                              ]))
                      : const SizedBox.shrink()),
              OutlinedButton.icon(
                  onPressed: up.running || reading || !g.editable ? null : choose,
                  icon: reading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.folder_zip_rounded),
                  label: Text(file == null
                      ? 'Выбрать ZIP'
                      : '${file!.split(RegExp(r'[\\/]')).last} · ${formatBytes(size ?? 0)}')),
              if (file != null && exes.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    initialValue: exe,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Файл запуска',
                        helperText:
                            'Для Unreal Engine — exe из Binaries/Win64, а не загрузчик в корне'),
                    items: [
                      for (final e in exes)
                        DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis))
                    ],
                    onChanged: (v) => setState(() => exe = v)),
                const SizedBox(height: 12),
                TextField(
                    controller: version,
                    decoration: const InputDecoration(
                        labelText: 'Версия', hintText: '1.0.0')),
                const SizedBox(height: 12),
                TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                        labelText: 'Что нового',
                        hintText: 'Покажется игрокам в списке обновлений')),
                const SizedBox(height: 14),
                ListenableBuilder(
                    listenable: Listenable.merge([up, version]),
                    builder: (context, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: KpButton('Загрузить сборку',
                            onTap: up.running ||
                                    exe == null ||
                                    version.text.trim().isEmpty ||
                                    (size ?? 0) > limit
                                ? null
                                : () => up.start(
                                    gameId: g.id,
                                    file: file!,
                                    version: version.text.trim(),
                                    executable: exe!,
                                    notes: notes.text.trim())))),
              ],
            ],
          ]),
      const SizedBox(height: 14),
      if (g.builds.isEmpty)
        const KpPanel(
            child: Text('Сборок пока нет', style: TextStyle(color: Kp.muted)))
      else
        for (final b in g.builds)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BuildCard(item: b, page: widget.page)),
    ]);
  }
}

class _BuildCard extends StatelessWidget {
  final DevBuild item;
  final _DevGamePageState page;
  const _BuildCard({required this.item, required this.page});

  @override
  Widget build(BuildContext context) {
    final s = item.scan;
    final av = s['antivirus'] is Map ? s['antivirus'] as Map : const {};
    final exe = s['executable'] is Map ? s['executable'] as Map : null;
    final archive = s['archive'] is Map ? s['archive'] as Map : null;
    final status = buildStatus[item.status] ?? (item.status, Kp.muted);
    Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(k, style: const TextStyle(color: Kp.muted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ]));
    return KpPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('Версия ${item.version}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        StatusPill(status),
      ]),
      const SizedBox(height: 4),
      Text('${formatBytes(item.size)} · ${formatDate(item.created)}',
          style: const TextStyle(color: Kp.muted, fontSize: 12)),
      const SizedBox(height: 10),
      if (item.status == 'scanning')
        const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 4)),
      row('Файл запуска', item.executable),
      if (exe != null) row('Программа', '${exe['arch'] ?? ''}, ${exe['subsystem'] == 'gui' ? 'оконная' : exe['subsystem']}'),
      if (archive != null) row('Архив', '${archive['files']} файлов, ${formatBytes(archive['unpacked'] as num? ?? 0)} после распаковки'),
      if (s['engine'] != null) row('Движок', engines[s['engine']] ?? '${s['engine']}'),
      if (av.isNotEmpty)
        row('Антивирус', switch (av['status']) {
          'clean' => 'чисто',
          'infected' => 'угрозы: ${(av['found'] as List?)?.join(', ')}',
          'unavailable' => 'в очереди, проверка скоро',
          _ => 'ошибка проверки'
        }),
      row('Keep Pixel SDK', item.sdk ? 'найден' : 'не найден. Оверлей и друзья в лаунчере работают и без него'),
      if (item.notes.isNotEmpty) row('Что нового', item.notes),
      if (item.problems.isNotEmpty) ...[
        const SizedBox(height: 6),
        Callout(
            icon: Icons.error_outline_rounded,
            color: Kp.error,
            title: 'Что не так',
            text: item.problems.map((p) => '• $p').join('\n')),
      ],
      if (item.reviewNote.isNotEmpty) ...[
        const SizedBox(height: 6),
        Callout(
            icon: Icons.comment_rounded,
            color: Kp.lilac,
            title: 'Модератор',
            text: item.reviewNote),
      ],
      if (!['live', 'superseded', 'scanning'].contains(item.status))
        Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Kp.error),
                onPressed: () async {
                  try {
                    await page.widget.api.deleteBuild(item.id);
                    page.load();
                  } catch (e) {
                    if (context.mounted) notice(context, '$e');
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Удалить'))),
    ]));
  }
}

/* ---------------- Publishing ---------------- */

class _Publishing extends StatefulWidget {
  final _DevGamePageState page;
  final DevGame game;
  const _Publishing({required this.page, required this.game});
  @override
  State<_Publishing> createState() => _PublishingState();
}

class _PublishingState extends State<_Publishing> {
  late String mode = widget.game.publishMode;
  late DateTime? at = widget.game.publishAt?.toLocal();

  Future<void> pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 730)),
        initialDate: at ?? now.add(const Duration(days: 7)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(at ?? DateTime(0, 1, 1, 12)));
    if (time == null) return;
    setState(() => at = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  void save() => widget.page.run(
      () => widget.page.widget.api.developerAction(widget.game.id, 'publishing', body: {
            'mode': mode,
            if (mode == 'scheduled' && at != null) 'publish_at': at!.toUtc().toIso8601String(),
          }),
      'Сохранено');

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final api = widget.page.widget.api;
    return KpPage(maxWidth: 900, children: [
      DevSection(
          title: 'Когда выпускать',
          subtitle: 'Игра выйдет только после одобрения сборки и витрины модератором.',
          children: [
            RadioGroup<String>(
                groupValue: mode,
                onChanged: (v) => setState(() => mode = v ?? mode),
                child: const Material(
                    type: MaterialType.transparency,
                    child: Column(children: [
                  RadioListTile(
                      contentPadding: EdgeInsets.zero,
                      value: 'auto',
                      title: Text('Сразу после одобрения')),
                  RadioListTile(
                      contentPadding: EdgeInsets.zero,
                      value: 'scheduled',
                      title: Text('В выбранную дату'),
                      subtitle: Text('Если одобрят позже, игра выйдет сразу после одобрения')),
                  RadioListTile(
                      contentPadding: EdgeInsets.zero,
                      value: 'manual',
                      title: Text('Вручную'),
                      subtitle: Text('После одобрения появится кнопка «Опубликовать»')),
                ]))),
            if (mode == 'scheduled')
              Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: const Icon(Icons.event_rounded, size: 18),
                      label: Text(at == null ? 'Выбрать дату' : formatDate(at)))),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                    onPressed: mode == 'scheduled' && at == null ? null : save,
                    child: const Text('Сохранить'))),
          ]),
      const SizedBox(height: 14),
      DevSection(title: 'Статус', children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          StatusPill(gameStatus[g.status] ?? (g.status, Kp.muted)),
          StatusPill(storeStatus[g.storeStatus] ?? (g.storeStatus, Kp.muted)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (g.status == 'approved')
            KpButton('Опубликовать сейчас',
                onTap: () => widget.page.run(
                    () => api.developerAction(g.id, 'publish'), 'Игра в магазине!')),
          if (g.status == 'published')
            OutlinedButton.icon(
                onPressed: () => widget.page.run(
                    () => api.developerAction(g.id, 'hide'), 'Игра скрыта'),
                icon: const Icon(Icons.visibility_off_rounded, size: 18),
                label: const Text('Скрыть из магазина')),
          if (g.status == 'hidden')
            OutlinedButton.icon(
                onPressed: () => widget.page.run(
                    () => api.developerAction(g.id, 'publish'), 'Игра снова в магазине'),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('Вернуть в магазин')),
        ]),
        if (g.live)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                  'Обновления: загрузите новую сборку на вкладке «Сборки». После одобрения игроки получат её автоматически.',
                  style: TextStyle(color: Kp.muted, height: 1.5))),
      ]),
      const SizedBox(height: 14),
      DevSection(title: 'Интеграция', children: [
        const Text(
            'Игру из Keep Pixel можно сделать лучше с SDK: профиль игрока, друзья, проверка лицензии, статус «в игре» и открытие оверлея из игры.',
            style: TextStyle(color: Kp.muted, height: 1.5)),
        const SizedBox(height: 10),
        Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SdkKitsPage(api: api))),
                child: const Text('SDK и документация'))),
      ]),
    ]);
  }
}
