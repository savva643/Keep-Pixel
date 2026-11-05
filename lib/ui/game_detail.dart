import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/installer.dart';
import '../core/models.dart';
import 'auth_dialog.dart';
import 'shared.dart';

Future<void> showGame(BuildContext context, PixelApi api, Game game,
        VoidCallback onChanged) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 900),
        builder: (_) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .88,
            child: GameDetail(api: api, initial: game, onChanged: onChanged)));

class GameDetail extends StatefulWidget {
  final PixelApi api;
  final Game initial;
  final VoidCallback onChanged;
  const GameDetail(
      {super.key,
      required this.api,
      required this.initial,
      required this.onChanged});
  @override
  State<GameDetail> createState() => _GameDetailState();
}

class _GameDetailState extends State<GameDetail> {
  late Game game;
  bool owned = false, loading = true, busy = false;
  String? error;
  final installer = GameInstaller();
  bool installed = false;
  double? progress;
  @override
  void dispose() {
    installer.cancel();
    super.dispose();
  }

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
      final library =
          widget.api.signedIn ? await widget.api.library() : <Game>[];
      final local = await installer.installed(game.id, detail.version);
      if (mounted) {
        setState(() {
          installed = local;
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

  Future<void> installOrLaunch() async {
    if (busy) return;
    setState(() {
      busy = true;
      progress = installed ? null : 0;
    });
    try {
      // Server verifies current ownership before both download and launch.
      final manifest = await widget.api.buildManifest(game.id);
      if (installed) {
        await installer.launch(game.id, manifest);
      } else {
        await installer.install(game.id, manifest, (v) {
          if (mounted) setState(() => progress = v);
        });
        if (mounted) {
          setState(() => installed = true);
          notice(context, 'Игра установлена');
        }
      }
    } catch (e) {
      if (mounted) notice(context, '$e');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 36), children: [
        Align(
            alignment: Alignment.centerRight,
            child: IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded))),
        ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
                height: 230, child: Artwork(game.banner, label: game.title))),
        const SizedBox(height: 24),
        Text(game.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
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
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          TextButton(onPressed: load, child: const Text('Повторить'))
        ] else if (!game.released)
          const Text(
              'Игра в разработке. Установка появится после публикации первого релиза.',
              style: TextStyle(color: muted, height: 1.6))
        else if (owned &&
            game.metadata['has_windows_build'] == true &&
            installer.supported) ...[
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                  onPressed: busy ? null : installOrLaunch,
                  icon: Icon(installed
                      ? Icons.play_arrow_rounded
                      : Icons.download_rounded),
                  label: Text(busy
                      ? 'Подготовка…'
                      : installed
                          ? 'Играть'
                          : 'Установить для Windows'))),
          if (progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            TextButton(
                onPressed: installer.cancel,
                child: const Text('Отменить загрузку'))
          ],
        ] else if (owned)
          Text(
              game.metadata['has_windows_build'] == true
                  ? 'Установка этой игры доступна в клиенте Keep Pixel для Windows.'
                  : 'Игра в твоей библиотеке. Установочный файл ещё не опубликован.',
              style: const TextStyle(color: muted, height: 1.6))
        else if (game.price == 0)
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                  onPressed: busy ? null : claim,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(busy ? 'Добавление…' : 'Добавить в библиотеку')))
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
      ]);
}
