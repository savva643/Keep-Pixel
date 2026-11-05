import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';
import 'game_detail.dart';
import 'shared.dart';

class CatalogPage extends StatefulWidget {
  final PixelApi api;
  final bool library;
  final VoidCallback onLibraryChanged;
  const CatalogPage(
      {super.key,
      required this.api,
      this.library = false,
      required this.onLibraryChanged});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final search = TextEditingController();
  Timer? debounce;
  List<Game> games = [];
  String? error;
  bool loading = true, more = false, loadingMore = false;
  int filter = 0, generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
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
              query: search.text.trim(), offset: append ? games.length : 0);
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

  void details(Game game) => showGame(context, widget.api, game, () {
        widget.onLibraryChanged();
        if (widget.library) load();
      });
  @override
  Widget build(BuildContext context) {
    final visible = games
        .where((g) =>
            (!widget.library ||
                g.title.toLowerCase().contains(search.text.toLowerCase())) &&
            (filter == 0 ||
                (filter == 1 ? g.price == 0 && g.released : !g.released)))
        .toList();
    return RefreshIndicator(
        onRefresh: load,
        child: LayoutBuilder(
            builder: (context, box) => ListView(
                    padding: EdgeInsets.fromLTRB(box.maxWidth > 700 ? 40 : 20,
                        12, box.maxWidth > 700 ? 40 : 20, 40),
                    children: [
                      Text(
                          widget.library
                              ? 'Твоя библиотека'
                              : 'Найди свою следующую игру',
                          style: TextStyle(
                              fontSize: box.maxWidth > 700 ? 30 : 25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1)),
                      const SizedBox(height: 10),
                      Text(
                          widget.library
                              ? 'Всё, что ты добавил. Всегда под рукой.'
                              : 'Игры, новые миры и независимые авторы — в одном месте.',
                          style: const TextStyle(
                              color: muted, fontSize: 13, height: 1.6)),
                      const SizedBox(height: 26),
                      TextField(
                          controller: search,
                          decoration: InputDecoration(
                              hintText: widget.library
                                  ? 'Найти в библиотеке'
                                  : 'Поиск игр и приложений',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Очистить поиск',
                                      onPressed: () {
                                        search.clear();
                                        load();
                                      },
                                      icon: const Icon(Icons.close_rounded))),
                          onChanged: (_) {
                            setState(() {});
                            if (!widget.library) {
                              debounce?.cancel();
                              debounce = Timer(
                                  const Duration(milliseconds: 350), load);
                            }
                          }),
                      const SizedBox(height: 24),
                      if (!widget.library &&
                          search.text.isEmpty &&
                          !loading &&
                          games.isNotEmpty) ...[
                        _Hero(
                            game: games.first,
                            onTap: () => details(games.first)),
                        const SizedBox(height: 32)
                      ],
                      Wrap(spacing: 10, runSpacing: 8, children: [
                        for (final (i, name) in [
                          (0, 'Все'),
                          (1, 'Бесплатные'),
                          (2, 'В разработке')
                        ])
                          ChoiceChip(
                              label: Text(name),
                              selected: filter == i,
                              onSelected: (_) => setState(() => filter = i))
                      ]),
                      const SizedBox(height: 24),
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
                            icon: widget.library
                                ? Icons.grid_view_rounded
                                : Icons.search_rounded,
                            title: games.isEmpty && search.text.isEmpty
                                ? (widget.library
                                    ? 'Здесь будут твои игры'
                                    : 'Каталог скоро пополнится')
                                : 'Ничего не найдено',
                            description: widget.library && games.isEmpty
                                ? 'Добавь бесплатную игру из магазина, и она появится в библиотеке.'
                                : 'Попробуй другой запрос или фильтр.')
                      else
                        GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: box.maxWidth > 1300
                                        ? 4
                                        : box.maxWidth > 850
                                            ? 3
                                            : box.maxWidth > 560
                                                ? 2
                                                : 1,
                                    mainAxisExtent: 310,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20),
                            itemCount: visible.length,
                            itemBuilder: (_, i) => _GameCard(
                                game: visible[i],
                                library: widget.library,
                                onTap: () => details(visible[i]))),
                      if (more && error == null)
                        Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Center(
                                child: OutlinedButton(
                                    onPressed: loadingMore
                                        ? null
                                        : () => load(append: true),
                                    child: Text(loadingMore
                                        ? 'Загрузка…'
                                        : 'Показать ещё')))),
                    ])));
  }
}

class _Hero extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  const _Hero({required this.game, required this.onTap});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF294336), Color(0xFF1B2C27)])),
              child: Row(children: [
                Expanded(
                    flex: 6,
                    child: Padding(
                        padding: EdgeInsets.all(box.maxWidth < 600 ? 24 : 36),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Tag(game.released
                                  ? 'В ФОКУСЕ'
                                  : 'СКОРО В KEEP PIXEL'),
                              const SizedBox(height: 22),
                              Text(game.title,
                                  style: TextStyle(
                                      fontSize: box.maxWidth < 600 ? 25 : 36,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -1,
                                      height: 1.15)),
                              const SizedBox(height: 14),
                              Text(game.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFFB3C7BB),
                                      height: 1.6,
                                      fontSize: 13)),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                  onPressed: onTap,
                                  icon: const Icon(Icons.arrow_forward_rounded,
                                      size: 18),
                                  iconAlignment: IconAlignment.end,
                                  label: const Text('Об игре'))
                            ]))),
                if (box.maxWidth > 650)
                  Expanded(
                      flex: 4,
                      child: SizedBox(
                          height: 320,
                          child: Artwork(game.banner, label: game.title))),
              ]))));
}

class _GameCard extends StatelessWidget {
  final Game game;
  final bool library;
  final VoidCallback onTap;
  const _GameCard(
      {required this.game, required this.library, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                height: 164, child: Artwork(game.cover, label: game.title)),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              game.genre.isEmpty
                                  ? 'ИГРА'
                                  : game.genre.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          Text(game.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Row(children: [
                            Expanded(
                                child: Text(
                                    library ? 'В библиотеке' : game.priceLabel,
                                    style: const TextStyle(
                                        color: accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            const Icon(Icons.arrow_outward_rounded,
                                color: muted, size: 19)
                          ])
                        ])))
          ])));
}
