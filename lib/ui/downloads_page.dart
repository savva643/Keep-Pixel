import 'package:flutter/material.dart';
import '../core/downloads.dart';
import '../core/installer.dart';
import 'game_actions.dart';
import 'shared.dart';

/// Downloads as a page of the desktop client: what is loading now, what is
/// next, what has finished, and how much room the game folders have.
class DownloadsPage extends StatefulWidget {
  final DownloadsController downloads;
  final VoidCallback onLibrary;
  const DownloadsPage(
      {super.key, required this.downloads, required this.onLibrary});
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late Future<List<LibraryFolder>> folders =
      widget.downloads.factory().libraries();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.downloads,
      builder: (context, _) {
        final manager = widget.downloads;
        final jobs = manager.jobs.values.toList();
        final current = jobs
                .where((j) => j.state == DownloadState.downloading)
                .firstOrNull ??
            jobs.where((j) => j.active).firstOrNull;
        final queued = jobs.where((j) => j.active && j != current).toList();
        final finished = jobs.where((j) => !j.active).toList().reversed;
        final active = jobs.where((j) => j.active).length;
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 1000;
          final gutter = box.maxWidth > 700 ? 32.0 : 16.0;
          final main =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            current == null
                ? _Idle(onLibrary: widget.onLibrary)
                : _Current(job: current, manager: manager),
            const SizedBox(height: 28),
            _Section(
                title: 'Далее в очереди',
                count: queued.length,
                empty: 'Очередь пуста',
                children: [
                  for (final (i, j) in queued.indexed)
                    _JobRow(
                        job: j,
                        leading: '${i + 1}',
                        trailing: IconButton(
                            tooltip: 'Убрать из очереди',
                            onPressed: () => manager.cancel(j.game.id),
                            icon: const Icon(Icons.close_rounded))),
                ]),
            const SizedBox(height: 28),
            _Section(
                title: 'Завершённые',
                count: finished.length,
                empty: 'Здесь появятся установленные игры',
                action: finished.isEmpty
                    ? null
                    : TextButton.icon(
                        onPressed: manager.clearFinished,
                        icon: const Icon(Icons.clear_all_rounded, size: 18),
                        label: const Text('Очистить')),
                children: [
                  for (final j in finished)
                    _JobRow(job: j, trailing: _finishedAction(context, j)),
                ]),
          ]);
          final side = _Disks(folders: folders);
          return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 32),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              const Expanded(
                                  child: Text('Загрузки',
                                      style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -.6))),
                              if (active > 0) Tag('Активных: $active'),
                            ]),
                            const SizedBox(height: 6),
                            const Text(
                                'Загрузка продолжается, даже если окно свёрнуто в трей.',
                                style: TextStyle(color: muted)),
                            const SizedBox(height: 22),
                            if (wide)
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: main),
                                    const SizedBox(width: 24),
                                    SizedBox(width: 340, child: side),
                                  ])
                            else ...[
                              main,
                              const SizedBox(height: 28),
                              side,
                            ],
                          ]))));
        });
      });

  Widget? _finishedAction(BuildContext context, DownloadJob j) {
    final manager = widget.downloads;
    return switch (j.state) {
      DownloadState.complete => FilledButton.icon(
          onPressed: manager.isRunning(j.game)
              ? null
              : () async {
                  try {
                    await manager.launch(j.game);
                  } catch (e) {
                    if (context.mounted) notice(context, '$e');
                  }
                },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(manager.isRunning(j.game) ? 'Запущено' : 'Играть')),
      DownloadState.failed || DownloadState.cancelled => OutlinedButton.icon(
          onPressed: () => manager.enqueue(j.game, library: j.library),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Повторить')),
      _ => null,
    };
  }
}

class _Current extends StatelessWidget {
  final DownloadJob job;
  final DownloadsController manager;
  const _Current({required this.job, required this.manager});
  @override
  Widget build(BuildContext context) {
    final g = job.game;
    final queued = job.state == DownloadState.queued;
    final percent = (job.progress * 100).clamp(0, 100).round();
    return ClipRRect(
        borderRadius: Kp.r24,
        child: Stack(children: [
          Positioned.fill(child: Artwork(g.banner, label: g.title)),
          Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
            Kp.bg.withValues(alpha: .95),
            Kp.bg.withValues(alpha: .75),
            Kp.bg.withValues(alpha: .4)
          ])))),
          Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  borderRadius: Kp.r24, border: Border.all(color: Kp.line)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      ClipRRect(
                          borderRadius: Kp.r14,
                          child: SizedBox.square(
                              dimension: 72,
                              child: Artwork(g.cover, label: g.title))),
                      const SizedBox(width: 18),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('СЕЙЧАС ЗАГРУЖАЕТСЯ',
                                style: TextStyle(
                                    color: Kp.lilac,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 6),
                            Text(g.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                                [
                                  job.label,
                                  if (g.version.isNotEmpty)
                                    'версия ${g.version}'
                                ].join(' · '),
                                style: const TextStyle(color: muted)),
                          ])),
                      if (!queued) ...[
                        const SizedBox(width: 12),
                        Text('$percent%',
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800)),
                      ],
                    ]),
                    const SizedBox(height: 20),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                            value: queued ? null : job.progress,
                            minHeight: 10,
                            backgroundColor: Kp.line,
                            color: Kp.violet)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: Text(
                              job.progress >= .8
                                  ? 'Распаковка и проверка файлов'
                                  : 'После загрузки файлы проверяются',
                              style:
                                  const TextStyle(color: muted, fontSize: 12))),
                      OutlinedButton.icon(
                          onPressed: () => manager.cancel(g.id),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Отменить')),
                    ]),
                  ])),
        ]));
  }
}

class _Idle extends StatelessWidget {
  final VoidCallback onLibrary;
  const _Idle({required this.onLibrary});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Kp.surface,
          borderRadius: Kp.r24,
          border: Border.all(color: Kp.line)),
      child: Row(children: [
        Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                gradient: Kp.gradient, borderRadius: Kp.r20),
            child: const Icon(Icons.download_done_rounded,
                color: Colors.white, size: 28)),
        const SizedBox(width: 18),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Сейчас ничего не загружается',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Выбери игру в библиотеке и нажми «Установить».',
              style: TextStyle(color: muted)),
        ])),
        const SizedBox(width: 12),
        FilledButton(onPressed: onLibrary, child: const Text('Библиотека')),
      ]));
}

class _Section extends StatelessWidget {
  final String title, empty;
  final int count;
  final Widget? action;
  final List<Widget> children;
  const _Section(
      {required this.title,
      required this.count,
      required this.empty,
      required this.children,
      this.action});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: KpHeading(count == 0 ? title : '$title · $count')),
          if (action != null) action!,
        ]),
        const SizedBox(height: 12),
        if (children.isEmpty)
          Text(empty, style: const TextStyle(color: muted))
        else
          for (final c in children)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
      ]);
}

class _JobRow extends StatelessWidget {
  final DownloadJob job;
  final String? leading;
  final Widget? trailing;
  const _JobRow({required this.job, this.leading, this.trailing});
  @override
  Widget build(BuildContext context) {
    final failed = job.state == DownloadState.failed;
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Kp.surface,
            borderRadius: Kp.r20,
            border: Border.all(
                color: failed ? Kp.error.withValues(alpha: .5) : Kp.line)),
        child: Row(children: [
          if (leading != null) ...[
            SizedBox(
                width: 22,
                child: Text(leading!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: muted, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
          ],
          ClipRRect(
              borderRadius: Kp.r10,
              child: SizedBox(
                  width: 96,
                  height: 54,
                  child: Artwork(job.game.banner, label: job.game.title))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(job.game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(job.error ?? job.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: failed
                            ? Kp.error
                            : job.state == DownloadState.complete
                                ? Kp.online
                                : muted,
                        fontSize: 12)),
              ])),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]));
  }
}

class _Disks extends StatelessWidget {
  final Future<List<LibraryFolder>> folders;
  const _Disks({required this.folders});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<LibraryFolder>>(
      future: folders,
      builder: (context, state) {
        final list = state.data ?? const <LibraryFolder>[];
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const KpHeading('Место на дисках'),
              const SizedBox(height: 12),
              if (state.connectionState != ConnectionState.done)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()))
              else if (list.isEmpty)
                const Text('Папки с играми появятся после первой установки.',
                    style: TextStyle(color: muted))
              else
                for (final f in list)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LibraryTile(folder: f)),
              const SizedBox(height: 4),
              const Text(
                  'Папки и диск для новых игр выбираются в Настройках → Игры.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
            ]);
      });
}
