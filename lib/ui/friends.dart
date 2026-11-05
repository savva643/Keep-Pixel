import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';
import 'shared.dart';

class FriendsPage extends StatefulWidget {
  final PixelApi api;
  final bool active;
  const FriendsPage({super.key, required this.api, this.active = true});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final query = TextEditingController();
  Timer? debounce, poll;
  List<PixelFriend> rows = [];
  int section = 0, generation = 0;
  bool loading = true;
  String? error, busyId;
  @override
  void initState() {
    super.initState();
    load();
    poll = Timer.periodic(const Duration(seconds: 45), (_) {
      if (widget.active && section != 2 && busyId == null) load(silent: true);
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    poll?.cancel();
    query.dispose();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    final request = ++generation;
    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final data = section == 2
          ? await widget.api.searchPeople(query.text.trim())
          : await widget.api.friends(
              section: section == 1
                  ? 'requests'
                  : section == 3
                      ? 'blocked'
                      : '');
      if (mounted && request == generation) {
        setState(() {
          rows = data;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && request == generation) setState(() => error = '$e');
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> action(PixelFriend friend, String action) async {
    if (busyId != null) return;
    if (['remove', 'block'].contains(action)) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(action == 'block'
                      ? 'Заблокировать ${friend.name}?'
                      : 'Удалить ${friend.name} из друзей?'),
                  content: Text(action == 'block'
                      ? 'Пользователь не сможет отправлять тебе заявки.'
                      : 'Можно будет отправить новую заявку позже.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Отмена')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Подтвердить'))
                  ]));
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => busyId = friend.id);
    try {
      if (action == 'request') {
        await widget.api.requestFriend(friend.id);
      } else {
        await widget.api.friendAction(friend, action);
      }
      await load(silent: true);
      if (mounted) notice(context, 'Готово');
    } catch (e) {
      if (mounted) notice(context, '$e');
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        Row(children: [
          const Expanded(
              child: Text('Друзья',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700))),
          IconButton(
              tooltip: 'Обновить друзей',
              onPressed: () => load(),
              icon: const Icon(Icons.refresh_rounded))
        ]),
        const SizedBox(height: 8),
        const Text(
            'Общие друзья Necsoura. Заявки и изменения синхронизируются между сервисами.',
            style: TextStyle(color: muted, height: 1.7)),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, name) in [
            (0, 'Все друзья'),
            (1, 'Заявки'),
            (2, 'Найти'),
            (3, 'Заблокированные')
          ])
            ChoiceChip(
                label: Text(name),
                selected: section == i,
                onSelected: (_) {
                  setState(() => section = i);
                  load();
                })
        ]),
        const SizedBox(height: 20),
        if (section == 2) ...[
          TextField(
              controller: query,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Имя, @username или id'),
              onChanged: (_) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 350), load);
              }),
          const SizedBox(height: 20)
        ],
        if (loading)
          const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()))
        else if (error != null)
          StatePanel(
              icon: Icons.cloud_off_rounded,
              title: 'Друзья недоступны',
              description: error!,
              action: 'Повторить',
              onAction: () => load())
        else if (rows.isEmpty)
          StatePanel(
              icon: Icons.people_outline_rounded,
              title: section == 2
                  ? 'Найди своих друзей'
                  : section == 1
                      ? 'Новых заявок нет'
                      : section == 3
                          ? 'Список блокировок пуст'
                          : 'Здесь будут твои друзья',
              description: section == 2
                  ? 'Введи минимум два символа публичного имени или username.'
                  : 'Поиск и заявки доступны во вкладках выше.')
        else
          ...rows.map((friend) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                          builder: (context, box) => Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Artwork(friend.avatar,
                                                label: friend
                                                    .name.characters.first))),
                                    SizedBox(
                                        width: box.maxWidth > 600
                                            ? 260
                                            : box.maxWidth - 100,
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(friend.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              if (friend.username.isNotEmpty)
                                                Text('@${friend.username}',
                                                    style: const TextStyle(
                                                        color: muted,
                                                        fontSize: 12)),
                                              Text(
                                                  friend.direction == 'incoming'
                                                      ? 'Входящая заявка'
                                                      : friend.direction ==
                                                              'outgoing'
                                                          ? 'Заявка отправлена'
                                                          : friend.statusLabel,
                                                  style: TextStyle(
                                                      color: friend.status ==
                                                                  'online' ||
                                                              friend.status ==
                                                                  'in_game'
                                                          ? accent
                                                          : muted,
                                                      fontSize: 11,
                                                      height: 1.8))
                                            ])),
                                    if (busyId == friend.id)
                                      const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                    else
                                      ..._actions(friend),
                                  ]))))))
      ]);
  List<Widget> _actions(PixelFriend f) => switch (f.relationship) {
        'pending' => f.direction == 'incoming'
            ? [
                FilledButton(
                    onPressed: () => action(f, 'accept'),
                    child: const Text('Принять')),
                TextButton(
                    onPressed: () => action(f, 'reject'),
                    child: const Text('Отклонить'))
              ]
            : [
                OutlinedButton(
                    onPressed: () => action(f, 'remove'),
                    child: const Text('Отменить заявку'))
              ],
        'accepted' => [
            PopupMenuButton<String>(
                tooltip: 'Действия с другом',
                onSelected: (a) => action(f, a),
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'remove', child: Text('Удалить из друзей')),
                      PopupMenuItem(
                          value: 'block', child: Text('Заблокировать'))
                    ])
          ],
        'blocked' => [
            OutlinedButton(
                onPressed: () => action(f, 'unblock'),
                child: const Text('Разблокировать'))
          ],
        _ => [
            FilledButton.icon(
                onPressed: () => action(f, 'request'),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Добавить'))
          ],
      };
}
