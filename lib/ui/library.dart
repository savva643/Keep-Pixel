import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/downloads.dart';
import 'game_detail.dart';
import 'shared.dart';

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
  int? selected;
  bool loading = true, onlyInstalled = false;
  String? error;
  String query = '';
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
          if (!games.any((g) => g.id == selected)) {
            selected = games.isEmpty ? null : games.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.downloads,
      builder: (context, _) {
        if (loading) return const Center(child: CircularProgressIndicator());
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
        final visible = games
            .where((g) =>
                g.title.toLowerCase().contains(query.toLowerCase()) &&
                (!onlyInstalled || widget.downloads.hasInstall(g)))
            .toList();
        final game = games.where((g) => g.id == selected).firstOrNull;
        Widget list() => Column(children: [
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: Text('Мои игры · ${games.length}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      IconButton(
                          tooltip: 'Обновить библиотеку',
                          onPressed: load,
                          icon: const Icon(Icons.refresh, size: 20))
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            hintText: 'Поиск в библиотеке',
                            prefixIcon: Icon(Icons.search, size: 20)),
                        onChanged: (s) => setState(() => query = s)),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Установленные',
                            style: TextStyle(fontSize: 12)),
                        value: onlyInstalled,
                        onChanged: (v) =>
                            setState(() => onlyInstalled = v ?? false))
                  ])),
              Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('Игры не найдены'))
                      : ListView(
                          children: visible
                              .map((g) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  child: ListTile(
                                      selected: g.id == selected,
                                      selectedTileColor:
                                          accent.withValues(alpha: .1),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      leading: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child:
                                                  Artwork(g.cover, label: ''))),
                                      title: Text(g.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                          widget.downloads.jobs[g.id]?.active ==
                                                  true
                                              ? widget
                                                  .downloads.jobs[g.id]!.label
                                              : widget.downloads.isCurrent(g)
                                                  ? 'Установлено'
                                                  : widget.downloads
                                                          .hasInstall(g)
                                                      ? 'Доступно обновление'
                                                      : 'В библиотеке',
                                          style: const TextStyle(
                                              fontSize: 11, color: muted)),
                                      onTap: () {
                                        setState(() => selected = g.id);
                                        if (MediaQuery.sizeOf(context).width <
                                            900) {
                                          showGame(context, widget.api, g, load,
                                              downloads: widget.downloads);
                                        }
                                      })))
                              .toList())),
            ]);
        return LayoutBuilder(
            builder: (context, box) => box.maxWidth < 900
                ? list()
                : Row(children: [
                    SizedBox(width: 290, child: list()),
                    const VerticalDivider(width: 1),
                    Expanded(
                        child: game == null
                            ? const SizedBox()
                            : GameDetail(
                                key: ValueKey(game.id),
                                api: widget.api,
                                initial: game,
                                onChanged: load,
                                downloads: widget.downloads,
                                embedded: true))
                  ]));
      });
}
