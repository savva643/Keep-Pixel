import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/downloads.dart';
import '../core/models.dart';
import 'auth_dialog.dart';
import 'shared.dart';

Future<void> showGame(
        BuildContext context, PixelApi api, Game game, VoidCallback onChanged,
        {required DownloadsController downloads}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 900),
        builder: (_) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .88,
            child: GameDetail(
                api: api,
                initial: game,
                onChanged: onChanged,
                downloads: downloads)));

class GameDetail extends StatefulWidget {
  final PixelApi api;
  final Game initial;
  final VoidCallback onChanged;
  final DownloadsController downloads;
  final bool embedded;
  const GameDetail(
      {super.key,
      required this.api,
      required this.initial,
      required this.onChanged,
      required this.downloads,
      this.embedded = false});
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
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.downloads,
      builder: (context, _) {
        final manager = widget.downloads, job = manager.jobs[game.id];
        final installed = manager.isCurrent(game);
        return ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
            children: [
              if (!widget.embedded)
                Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded))),
              ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                      height: 230,
                      child: Artwork(game.banner, label: game.title))),
              const SizedBox(height: 24),
              Text(game.title,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (game.genre.isNotEmpty) Tag(game.genre),
                if (game.version.isNotEmpty) Tag('Версия ${game.version}'),
                for (final p in game.platforms) Tag(p),
                Tag(owned ? 'В библиотеке' : game.priceLabel)
              ]),
              const SizedBox(height: 24),
              if (loading)
                const LinearProgressIndicator()
              else if (error != null) ...[
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                TextButton(onPressed: load, child: const Text('Повторить'))
              ] else if (!game.released)
                const Text(
                    'Игра в разработке. Установка появится после публикации первого релиза.',
                    style: TextStyle(color: muted, height: 1.6))
              else if (owned &&
                  manager.supported &&
                  game.metadata['has_windows_build'] == true) ...[
                Wrap(spacing: 12, runSpacing: 12, children: [
                  if (job?.active == true)
                    OutlinedButton.icon(
                        onPressed: () => manager.cancel(game.id),
                        icon: const Icon(Icons.close),
                        label: const Text('Отменить загрузку'))
                  else
                    FilledButton.icon(
                        onPressed: busy
                            ? null
                            : installed
                                ? launch
                                : () => manager.enqueue(game),
                        icon: Icon(installed
                            ? Icons.play_arrow_rounded
                            : Icons.download_rounded),
                        label: Text(installed
                            ? 'Играть'
                            : manager.hasInstall(game)
                                ? 'Обновить'
                                : 'Установить')),
                  if (manager.hasInstall(game) && job?.active != true)
                    TextButton(
                        onPressed: uninstall,
                        child: const Text('Удалить с устройства')),
                ]),
                if (job != null) ...[
                  const SizedBox(height: 12),
                  Text(job.label, style: const TextStyle(color: muted)),
                  if (job.active)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(value: job.progress)),
                  if (job.error != null)
                    Text(job.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))
                ],
              ] else if (owned)
                Text(
                    game.metadata['has_windows_build'] == true
                        ? 'Установка доступна в клиенте Keep Pixel для Windows.'
                        : 'Игра в библиотеке. Разработчик ещё не опубликовал установочный файл.',
                    style: const TextStyle(color: muted, height: 1.6))
              else if (game.price == 0)
                Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                        onPressed: busy ? null : claim,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                            busy ? 'Добавление…' : 'Добавить в библиотеку')))
              else
                const Text(
                    'Продажи пока не открыты. Покупка появится после подключения оплаты.',
                    style: TextStyle(color: muted, height: 1.6)),
              const SizedBox(height: 32),
              const Text('Об игре',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SelectableText(
                  game.description.isEmpty
                      ? 'Автор пока не добавил описание.'
                      : game.description,
                  style: const TextStyle(color: muted, height: 1.9)),
              if (game.company.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text('Разработчик: ${game.company}',
                        style: const TextStyle(color: muted))),
              if (game.details['minimum_requirements'] is Map) ...[
                const SizedBox(height: 24),
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Системные требования'),
                    children: [
                      for (final entry
                          in (game.details['minimum_requirements'] as Map)
                              .entries)
                        if (entry.value != null && '${entry.value}'.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                        width: 110,
                                        child: Text(
                                            {
                                                  'os': 'Система',
                                                  'processor': 'Процессор',
                                                  'memory': 'Память',
                                                  'graphics': 'Видеокарта',
                                                  'storage': 'На диске'
                                                }[entry.key] ??
                                                '${entry.key}',
                                            style: const TextStyle(
                                                color: muted, fontSize: 12))),
                                    Expanded(
                                        child: Text('${entry.value}',
                                            style:
                                                const TextStyle(fontSize: 12)))
                                  ])),
                    ]),
              ],
              if (game.details['updates'] is List &&
                  (game.details['updates'] as List).isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Обновления',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                for (final update in (game.details['updates'] as List).take(5))
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${update['version']} · ${update['title'] ?? ''}'),
                            const SizedBox(height: 4),
                            Text('${update['description'] ?? ''}',
                                style:
                                    const TextStyle(color: muted, height: 1.6))
                          ])),
              ],
            ]);
      });
}
