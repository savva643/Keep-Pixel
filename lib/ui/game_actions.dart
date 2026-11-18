import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/api.dart';
import '../core/downloads.dart';
import '../core/library_prefs.dart';
import '../core/models.dart';
import '../core/storage.dart';
import 'game_detail.dart';
import 'shared.dart';

/// What can be done with a game from the library: the same list for the
/// right-click menu, the long-press sheet on a phone and the game page.
class GameActions {
  final BuildContext context;
  final PixelApi api;
  final DownloadsController downloads;
  final Game game;
  final VoidCallback onChanged;
  const GameActions(this.context,
      {required this.api,
      required this.downloads,
      required this.game,
      required this.onChanged});

  bool get canInstall =>
      downloads.supported &&
      game.released &&
      game.metadata['has_windows_build'] == true;
  bool get installed => downloads.hasInstall(game);

  void _notice(Object e) {
    if (context.mounted) notice(context, '$e');
  }

  Future<void> play() async {
    try {
      await downloads.launch(game);
    } catch (e) {
      _notice(e);
    }
  }

  Future<void> install() async {
    // An update stays where the game already is.
    if (installed) return downloads.enqueue(game);
    List<LibraryFolder> folders;
    try {
      folders = await downloads.factory().libraries();
    } catch (_) {
      // Without the list the game still installs to the default folder.
      folders = const [];
    }
    if (!context.mounted) return;
    if (folders.length < 2) return downloads.enqueue(game);
    final chosen = await pickLibrary(context, folders,
        title: 'Куда установить ${game.title}?', action: 'Установить');
    if (chosen != null) downloads.enqueue(game, library: chosen);
  }

  Future<void> uninstall() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Удалить с устройства?'),
                content: Text(
                    '${game.title} останется в библиотеке. Файлы игры будут удалены.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена')),
                  FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Kp.error),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Удалить'))
                ]));
    if (ok != true) return;
    try {
      await downloads.uninstall(game);
    } catch (e) {
      _notice(e);
    }
  }

  Future<void> move() async {
    final folders = await downloads.factory().libraries();
    final current = downloads.locations[game.id];
    final others = [
      for (final f in folders)
        if (current == null || !p.isWithin(f.path, current)) f
    ];
    if (!context.mounted) return;
    if (others.isEmpty) {
      return _notice(
          'Другой папки для игр нет. Добавь её в настройках, раздел «Игры»');
    }
    final chosen = await pickLibrary(context, others,
        title: 'Куда перенести ${game.title}?', action: 'Перенести');
    if (chosen == null) return;
    try {
      await downloads.move(game, chosen);
      _notice('${game.title} перенесена');
    } catch (e) {
      _notice(e);
    }
  }

  Future<void> openFolder() async {
    try {
      await downloads.openFolder(game);
    } catch (e) {
      _notice(e);
    }
  }

  void store() => showGame(context, api, game, onChanged, downloads: downloads);

  Future<void> properties() => showDialog<void>(
      context: context, builder: (_) => GameProperties(actions: this));

  /// The main button: play, install, update or cancel.
  ({String label, IconData icon, VoidCallback? onTap}) get primary {
    final job = downloads.jobs[game.id];
    if (job?.active == true) {
      return (
        label: 'Отменить загрузку',
        icon: Icons.close_rounded,
        onTap: () => downloads.cancel(game.id)
      );
    }
    if (downloads.moving.containsKey(game.id)) {
      return (
        label: 'Перенос…',
        icon: Icons.drive_file_move_rounded,
        onTap: null
      );
    }
    if (downloads.isRunning(game)) {
      return (label: 'Запущено', icon: Icons.play_arrow_rounded, onTap: null);
    }
    if (downloads.isCurrent(game)) {
      return (label: 'Играть', icon: Icons.play_arrow_rounded, onTap: play);
    }
    if (!canInstall) {
      return (label: 'Нет установки', icon: Icons.block_rounded, onTap: null);
    }
    return installed
        ? (label: 'Обновить', icon: Icons.update_rounded, onTap: install)
        : (label: 'Установить', icon: Icons.download_rounded, onTap: install);
  }

  /// Null entries are separators.
  List<_Action?> get _items {
    final prefs = downloads.prefs;
    final busy = downloads.isBusy(game);
    final main = primary;
    return [
      if (main.onTap != null) _Action(main.icon, main.label, main.onTap!),
      if (main.onTap != null) null,
      _Action(
          prefs.isFavorite(game.id)
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          prefs.isFavorite(game.id)
              ? 'Убрать из избранного'
              : 'Добавить в избранное',
          () => prefs.toggleFavorite(game.id)),
      _Action(
          prefs.isHidden(game.id)
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          prefs.isHidden(game.id) ? 'Вернуть в библиотеку' : 'Скрыть игру',
          () => prefs.toggleHidden(game.id)),
      null,
      _Action(Icons.storefront_rounded, 'Страница в магазине', store),
      if (installed && downloads.locations.containsKey(game.id))
        _Action(Icons.folder_open_rounded, 'Открыть папку игры', openFolder),
      if (installed && !busy)
        _Action(
            Icons.drive_file_move_rounded, 'Перенести на другой диск…', move),
      if (installed && !busy)
        _Action(Icons.delete_outline_rounded, 'Удалить с устройства', uninstall,
            danger: true),
      null,
      _Action(Icons.tune_rounded, 'Свойства…', properties),
    ];
  }

  /// The right-click menu at the pointer, or a sheet on a touch screen.
  Future<void> showMenuAt(Offset? position) async {
    final list = _items;
    if (position == null) {
      final chosen = await showModalBottomSheet<_Action>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheet) => SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(children: [
                          SizedBox.square(
                              dimension: 40,
                              child: ClipRRect(
                                  borderRadius: Kp.r10,
                                  child:
                                      Artwork(game.cover, label: game.title))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(game.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800))),
                        ])),
                    for (final a in list)
                      if (a == null)
                        const Divider(height: 12)
                      else
                        ListTile(
                            leading: Icon(a.icon,
                                color: a.danger ? Kp.error : Kp.lilac),
                            title: Text(a.label,
                                style: TextStyle(
                                    color: a.danger ? Kp.error : Kp.text,
                                    fontWeight: FontWeight.w600)),
                            shape: const RoundedRectangleBorder(
                                borderRadius: Kp.r14),
                            onTap: () => Navigator.pop(sheet, a)),
                  ]))));
      chosen?.onTap();
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final chosen = await showMenu<_Action>(
        context: context,
        color: Kp.raised,
        constraints: const BoxConstraints(minWidth: 240),
        shape: const RoundedRectangleBorder(
            borderRadius: Kp.r14, side: BorderSide(color: Kp.line)),
        position: RelativeRect.fromRect(
            position & const Size(1, 1), Offset.zero & overlay.size),
        items: [
          for (final a in list)
            if (a == null)
              const PopupMenuDivider(height: 8)
            else
              PopupMenuItem<_Action>(
                  value: a,
                  height: 38,
                  child: Row(children: [
                    Icon(a.icon,
                        size: 18, color: a.danger ? Kp.error : Kp.muted),
                    const SizedBox(width: 12),
                    Text(a.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: a.danger ? Kp.error : Kp.text)),
                  ])),
        ]);
    chosen?.onTap();
  }
}

class _Action {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _Action(this.icon, this.label, this.onTap, {this.danger = false});
}

/// Right click on a computer, long press on a phone.
class GameMenuArea extends StatelessWidget {
  final GameActions Function() actions;
  final Widget child;
  const GameMenuArea({super.key, required this.actions, required this.child});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onSecondaryTapUp: (d) => actions().showMenuAt(d.globalPosition),
      onLongPress: () => actions().showMenuAt(null),
      child: child);
}

/// Asks which library folder to use, showing the free space on each drive.
Future<String?> pickLibrary(BuildContext context, List<LibraryFolder> folders,
    {required String title, required String action}) {
  var chosen =
      (folders.where((f) => f.isDefault).firstOrNull ?? folders.first).path;
  return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                  title: Text(title),
                  content: SizedBox(
                      width: 460,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final f in folders)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: LibraryTile(
                                  folder: f,
                                  selected: f.path == chosen,
                                  onTap: () =>
                                      setState(() => chosen = f.path))),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, chosen),
                        child: Text(action)),
                  ])));
}

/// A library folder with its drive and how full the drive is.
class LibraryTile extends StatelessWidget {
  final LibraryFolder folder;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  const LibraryTile(
      {super.key,
      required this.folder,
      this.selected = false,
      this.onTap,
      this.trailing});
  @override
  Widget build(BuildContext context) {
    final f = folder;
    final used = f.total == null || f.free == null ? null : f.total! - f.free!;
    return Hovered(
        onTap: onTap,
        builder: (context, hover) => AnimatedContainer(
            duration: Kp.motion,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: selected
                    ? Kp.violet.withValues(alpha: .14)
                    : hover && onTap != null
                        ? Kp.raised
                        : Kp.bg,
                borderRadius: Kp.r14,
                border: Border.all(
                    width: selected ? 1.5 : 1,
                    color: selected ? Kp.violet : Kp.line)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: Kp.raised,
                        borderRadius: Kp.r10,
                        border: Border.all(color: Kp.line)),
                    child: const Icon(Icons.storage_rounded,
                        size: 20, color: Kp.lilac)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Text('Диск ${f.drive}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                        if (f.isDefault) ...[
                          const SizedBox(width: 8),
                          const _Badge('По умолчанию'),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(f.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 12)),
                    ])),
                if (trailing != null) trailing!,
                if (onTap != null && trailing == null)
                  Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: selected ? Kp.lilac : Kp.muted),
              ]),
              const SizedBox(height: 12),
              if (used != null)
                ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                        height: 8,
                        child: LayoutBuilder(builder: (context, box) {
                          double part(int bytes) =>
                              box.maxWidth * (bytes / f.total!).clamp(0, 1);
                          return Stack(children: [
                            Container(color: Kp.line),
                            Container(width: part(used), color: Kp.indigo),
                            // Keep Pixel's own share, at least a sliver.
                            Container(
                                width: f.bytes == 0 ? 0 : part(f.bytes) + 2,
                                color: Kp.lilac),
                          ]);
                        }))),
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 4, children: [
                _Legend(Kp.lilac, 'Игры: ${f.games} · ${formatBytes(f.bytes)}'),
                if (used != null) ...[
                  const _Legend(Kp.indigo, 'Другое'),
                  _Legend(Kp.line, 'Свободно ${formatBytes(f.free!)}'),
                ],
              ]),
            ])));
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
      ]);
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: Kp.violet.withValues(alpha: .22), borderRadius: Kp.r10),
      child: Text(label,
          style: const TextStyle(
              color: Kp.lilac, fontSize: 10, fontWeight: FontWeight.w700)));
}

/// Properties of a game: tabs on the left, the chosen one at right.
class GameProperties extends StatefulWidget {
  final GameActions actions;
  const GameProperties({super.key, required this.actions});
  @override
  State<GameProperties> createState() => _GamePropertiesState();
}

class _GamePropertiesState extends State<GameProperties> {
  int tab = 0;
  late Game game = widget.actions.game;
  Future<int>? size;
  Future<List<LibraryFolder>>? folders;
  static const tabs = [
    ('Общие', Icons.info_outline_rounded),
    ('Установка', Icons.storage_rounded),
    ('Обновления', Icons.update_rounded),
  ];

  GameActions get a => widget.actions;

  @override
  void initState() {
    super.initState();
    _reload();
    a.api.game(game.id).then((g) {
      if (mounted) setState(() => game = g);
    }).catchError((_) {});
  }

  void _reload() {
    final installer = a.downloads.factory();
    size = installer.gameSize(game.id);
    folders = installer.libraries();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Dialog(
        insetPadding: EdgeInsets.all(wide ? 40 : 12),
        clipBehavior: Clip.antiAlias,
        child: ListenableBuilder(
            listenable: Listenable.merge([a.downloads, a.downloads.prefs]),
            builder: (context, _) => SizedBox(
                width: 780,
                height: 540,
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Container(
                                width: 210,
                                color: Kp.bg,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _header(),
                                      const SizedBox(height: 14),
                                      for (var i = 0; i < tabs.length; i++)
                                        _TabTile(
                                            label: tabs[i].$1,
                                            icon: tabs[i].$2,
                                            selected: tab == i,
                                            onTap: () =>
                                                setState(() => tab = i)),
                                    ])),
                            Expanded(child: _body()),
                          ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: _header()),
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(children: [
                                  for (var i = 0; i < tabs.length; i++)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: KpChip(
                                            label: tabs[i].$1,
                                            selected: tab == i,
                                            onTap: () =>
                                                setState(() => tab = i))),
                                ])),
                            Expanded(child: _body()),
                          ]))));
  }

  Widget _header() => Row(children: [
        SizedBox.square(
            dimension: 40,
            child: ClipRRect(
                borderRadius: Kp.r10,
                child: Artwork(game.cover, label: game.title))),
        const SizedBox(width: 10),
        Expanded(
            child: Text(game.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800))),
        IconButton(
            tooltip: 'Закрыть',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 20)),
      ]);

  Widget _body() => ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      children: switch (tab) {
        0 => _general(),
        1 => _install(),
        _ => _updates(),
      });

  List<Widget> _general() {
    final prefs = a.downloads.prefs;
    return [
      const KpHeading('Общие'),
      const SizedBox(height: 16),
      _Fact('Время в игре', playTimeLabel(prefs.playTime(game.id))),
      _Fact('Последний запуск', lastPlayedLabel(prefs.lastPlayed(game.id))),
      if (game.company.isNotEmpty) _Fact('Разработчик', game.company),
      if (game.genre.isNotEmpty) _Fact('Жанр', game.genre),
      if (game.version.isNotEmpty) _Fact('Версия в магазине', game.version),
      const Text('Время и запуски считаются на этом устройстве.',
          style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 16),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Избранное'),
          subtitle: const Text('Показывать в начале библиотеки'),
          value: prefs.isFavorite(game.id),
          onChanged: (_) => prefs.toggleFavorite(game.id)),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Скрыть игру'),
          subtitle:
              const Text('Убрать из списка. Найти можно в фильтре «Скрытые»'),
          value: prefs.isHidden(game.id),
          onChanged: (_) => prefs.toggleHidden(game.id)),
    ];
  }

  List<Widget> _install() {
    final d = a.downloads;
    final dir = d.locations[game.id];
    final moving = d.moving[game.id];
    if (!d.supported) {
      return const [
        KpHeading('Установка'),
        SizedBox(height: 16),
        Text('Игры устанавливаются в клиенте Keep Pixel для Windows.',
            style: TextStyle(color: muted, height: 1.6)),
      ];
    }
    if (!a.installed) {
      return [
        const KpHeading('Установка'),
        const SizedBox(height: 16),
        Text(
            a.canInstall
                ? 'Игра не установлена. Можно выбрать диск при установке.'
                : 'Разработчик ещё не опубликовал сборку для Windows.',
            style: const TextStyle(color: muted, height: 1.6)),
        const SizedBox(height: 16),
        if (a.canInstall)
          Align(
              alignment: Alignment.centerLeft,
              child: KpButton(a.primary.label, onTap: a.primary.onTap)),
      ];
    }
    return [
      const KpHeading('Установленные файлы'),
      const SizedBox(height: 16),
      FutureBuilder<int>(
          future: size,
          builder: (context, s) => _Fact('Размер на диске',
              s.data == null ? 'Считаем…' : formatBytes(s.data!))),
      if (dir != null) _Fact('Папка', dir),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: dir == null ? null : a.openFolder,
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: const Text('Открыть папку')),
        OutlinedButton.icon(
            onPressed: d.isBusy(game)
                ? null
                : () async {
                    await a.move();
                    if (mounted) setState(_reload);
                  },
            icon: const Icon(Icons.drive_file_move_rounded, size: 18),
            label: const Text('Перенести на другой диск')),
        TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Kp.error),
            onPressed: d.isBusy(game) ? null : a.uninstall,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Удалить с устройства')),
      ]),
      if (moving != null) ...[
        const SizedBox(height: 16),
        Text('Перенос ${(moving * 100).round()}%',
            style: const TextStyle(color: muted)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: moving),
      ],
      const SizedBox(height: 24),
      const Text('Папки с играми',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      FutureBuilder<List<LibraryFolder>>(
          future: folders,
          builder: (context, s) => s.data == null
              ? const LinearProgressIndicator()
              : Column(children: [
                  for (final f in s.data!)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LibraryTile(
                            folder: f,
                            selected: dir != null && p.isWithin(f.path, dir))),
                ])),
    ];
  }

  List<Widget> _updates() {
    final d = a.downloads;
    final have = d.installed[game.id];
    final updates = game.details['updates'] is List
        ? (game.details['updates'] as List).whereType<Map>().toList()
        : <Map>[];
    return [
      const KpHeading('Обновления'),
      const SizedBox(height: 16),
      _Fact('Установлена', have ?? 'Нет'),
      _Fact('В магазине', game.version.isEmpty ? '—' : game.version),
      const SizedBox(height: 8),
      if (have != null && have != game.version && a.canInstall)
        Align(
            alignment: Alignment.centerLeft,
            child: KpButton(a.primary.label, onTap: a.primary.onTap))
      else if (have != null)
        const Text('Установлена последняя версия.',
            style: TextStyle(color: Kp.online)),
      const SizedBox(height: 8),
      const Text(
          'Обновления скачиваются, когда ты их запускаешь. Игра обновляется в той же папке.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
      if (updates.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text('Что нового', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final u in updates.take(10))
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u['version'] ?? ''} · ${u['title'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${u['description'] ?? ''}',
                        style: const TextStyle(color: muted, height: 1.5)),
                  ])),
      ],
    ];
  }
}

class _TabTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TabTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Hovered(
      onTap: onTap,
      builder: (context, hover) => AnimatedContainer(
          duration: Kp.motion,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              borderRadius: Kp.r10,
              gradient: selected ? Kp.gradient : null,
              color: selected
                  ? null
                  : hover
                      ? Kp.raised
                      : null),
          child: Row(children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Kp.muted),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : Kp.text)),
          ])));
}

class _Fact extends StatelessWidget {
  final String label, value;
  const _Fact(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(color: muted, fontSize: 13))),
        Expanded(
            child: SelectableText(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600))),
      ]));
}
