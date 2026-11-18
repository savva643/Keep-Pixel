import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/developer.dart';
import '../shared.dart';
import 'common.dart';
import 'dev_game_page.dart';
import 'sdk_kits.dart';

/// "For developers": become a developer, then manage your games.
class DeveloperHub extends StatefulWidget {
  final PixelApi api;
  final VoidCallback? onSignIn;
  const DeveloperHub({super.key, required this.api, this.onSignIn});
  @override
  State<DeveloperHub> createState() => _DeveloperHubState();
}

class _DeveloperHubState extends State<DeveloperHub> {
  DeveloperAccount? account;
  List<DevGame> games = const [];
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!widget.api.signedIn) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final a = await widget.api.developerAccount();
      final g = a.registered && !a.blocked
          ? await widget.api.developerGames()
          : const <DevGame>[];
      if (mounted) {
        setState(() {
          account = a;
          games = g;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openGame(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DevGamePage(api: widget.api, gameId: id, account: account!)));
    load();
  }

  Future<void> newGame() async {
    final title = TextEditingController();
    final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Новая игра'),
                content: SizedBox(
                    width: 380,
                    child: TextField(
                        controller: title,
                        autofocus: true,
                        maxLength: 120,
                        decoration:
                            const InputDecoration(hintText: 'Название игры'),
                        onSubmitted: (v) => Navigator.pop(context, v))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, title.text),
                      child: const Text('Создать')),
                ]));
    Future.delayed(const Duration(seconds: 1), title.dispose);
    if (name == null || name.trim().isEmpty) return;
    try {
      final g = await widget.api.createDeveloperGame(name.trim());
      await openGame(g.id);
    } catch (e) {
      if (mounted) notice(context, '$e');
    }
  }

  Future<void> editProfile() async {
    final saved = await Navigator.of(context).push<DeveloperAccount>(
        MaterialPageRoute(
            builder: (_) =>
                DeveloperProfileForm(api: widget.api, account: account)));
    if (saved != null) load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.api.signedIn) {
      return StatePanel(
          icon: Icons.rocket_launch_rounded,
          title: 'Выпусти свою игру в Keep Pixel',
          description:
              'Войди в Necsoura, заполни профиль разработчика и отправь игру на модерацию.',
          action: 'Войти в Necsoura',
          onAction: widget.onSignIn);
    }
    if (loading && account == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && account == null) {
      return StatePanel(
          icon: Icons.cloud_off_rounded,
          title: 'Кабинет недоступен',
          description: error!,
          action: 'Повторить',
          onAction: load);
    }
    final a = account!;
    if (!a.registered) return _Welcome(onStart: editProfile, api: widget.api);
    if (a.blocked) {
      return StatePanel(
          icon: Icons.block_rounded,
          title: 'Аккаунт разработчика заблокирован',
          description: '${a.profile?['block_reason'] ?? ''}'.isEmpty
              ? 'Напишите модерации Keep Pixel'
              : 'Причина: ${a.profile!['block_reason']}');
    }
    return RefreshIndicator(
        onRefresh: load,
        child: KpPage(title: 'Кабинет разработчика', children: [
          _Header(account: a, onEdit: editProfile, onNew: newGame),
          const SizedBox(height: 18),
          if (games.isEmpty)
            KpPanel(
                child: Column(children: [
              const Icon(Icons.videogame_asset_rounded,
                  size: 44, color: Kp.lilac),
              const SizedBox(height: 12),
              const Text('Игр пока нет',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'Создай черновик: заполни витрину, загрузи сборку и отправь на модерацию.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Kp.muted)),
              const SizedBox(height: 16),
              KpButton('Добавить игру', onTap: newGame),
            ]))
          else
            ...games.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GameRow(game: g, onTap: () => openGame(g.id)))),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, box) {
            final cards = [
              _InfoCard(
                  icon: Icons.extension_rounded,
                  title: 'SDK и документация',
                  text:
                      'Unreal, Unity, Godot или любой движок: профиль, друзья, лицензия, статус и оверлей.',
                  action: 'Открыть',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SdkKitsPage(api: widget.api)))),
              const _InfoCard(
                  icon: Icons.verified_user_rounded,
                  title: 'Как проходит модерация',
                  text:
                      '1. Автопроверка архива: антивирус, файлы, программа запуска, SDK.\n'
                      '2. Модератор запускает сборку.\n'
                      '3. Модератор проверяет витрину.\n'
                      '4. Публикация сразу, в выбранную дату или вручную.'),
            ];
            return box.maxWidth > 760
                ? IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 14),
                      Expanded(child: cards[1]),
                    ]))
                : Column(children: [cards[0], const SizedBox(height: 14), cards[1]]);
          }),
          if (a.isAdmin) ...[
            const SizedBox(height: 14),
            Callout(
                icon: Icons.admin_panel_settings_rounded,
                color: Kp.lilac,
                title: 'Вы модератор',
                text: 'Очередь проверки открывается в веб-админке.',
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                        onPressed: () => openLink(context,
                            '${Uri.parse(widget.api.apiUrl).origin}/admin/'),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Открыть модерацию')))),
          ],
        ]));
  }
}

class _Header extends StatelessWidget {
  final DeveloperAccount account;
  final VoidCallback onEdit, onNew;
  const _Header(
      {required this.account, required this.onEdit, required this.onNew});
  @override
  Widget build(BuildContext context) => KpPanel(
      child: Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                      gradient: Kp.gradient, borderRadius: Kp.r14),
                  child: const Icon(Icons.code_rounded, color: Colors.white)),
              const SizedBox(width: 14),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('${account.profile?['contact_email'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Kp.muted)),
                      ])),
            ]),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Профиль')),
              FilledButton.icon(
                  onPressed: onNew,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Новая игра')),
            ]),
          ]));
}

class _GameRow extends StatelessWidget {
  final DevGame game;
  final VoidCallback onTap;
  const _GameRow({required this.game, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final build = game.latestBuild;
    return Hovered(
        onTap: onTap,
        builder: (context, hover) => AnimatedContainer(
            duration: Kp.motion,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: hover ? Kp.raised : Kp.surface,
                borderRadius: Kp.r20,
                border: Border.all(color: hover ? Kp.violet : Kp.line)),
            child: Row(children: [
              ClipRRect(
                  borderRadius: Kp.r10,
                  child: SizedBox(
                      width: 54,
                      height: 72,
                      child: Artwork(game.cover, label: game.title))),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(game.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      StatusPill(gameStatus[game.status] ??
                          (game.status, Kp.muted)),
                      if (build != null)
                        StatusPill((
                          'v${build.version} · ${(buildStatus[build.status] ?? (build.status, Kp.muted)).$1}',
                          (buildStatus[build.status] ?? ('', Kp.muted)).$2
                        )),
                    ]),
                  ])),
              const Icon(Icons.chevron_right_rounded, color: Kp.muted),
            ])));
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final String? action;
  final VoidCallback? onTap;
  const _InfoCard(
      {required this.icon,
      required this.title,
      required this.text,
      this.action,
      this.onTap});
  @override
  Widget build(BuildContext context) => KpPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Kp.lilac),
        const SizedBox(height: 10),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(color: Kp.muted, height: 1.6)),
        if (action != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onTap, child: Text(action!)),
        ]
      ]));
}

class _Welcome extends StatelessWidget {
  final VoidCallback onStart;
  final PixelApi api;
  const _Welcome({required this.onStart, required this.api});
  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.badge_rounded, 'Профиль разработчика', 'Имя или студия и почта для связи с модерацией.'),
      (Icons.storefront_rounded, 'Витрина', 'Описание, обложка, баннер, скриншоты, трейлер, требования и достижения.'),
      (Icons.upload_file_rounded, 'Сборка', 'ZIP с игрой. Большие архивы загружаются частями и докачиваются после обрыва.'),
      (Icons.shield_rounded, 'Проверка', 'Антивирус и проверка архива автоматически, затем модератор.'),
      (Icons.rocket_launch_rounded, 'Публикация', 'Сразу после одобрения, в выбранную дату или по кнопке.'),
    ];
    return KpPage(children: [
      Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              borderRadius: Kp.r24,
              gradient: LinearGradient(colors: [
                Kp.blue.withValues(alpha: .55),
                Kp.violet.withValues(alpha: .35)
              ])),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Для разработчиков',
                style: TextStyle(
                    color: Kp.lilac,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5)),
            const SizedBox(height: 8),
            const Text('Выпусти свою игру в Keep Pixel',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6)),
            const SizedBox(height: 10),
            const Text(
                'Магазин, библиотека, установка и обновления, друзья и оверлей уже работают. Тебе нужна только игра.',
                style: TextStyle(color: Kp.text, height: 1.6)),
            const SizedBox(height: 20),
            Wrap(spacing: 10, runSpacing: 10, children: [
              KpButton('Стать разработчиком', onTap: onStart),
              OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SdkKitsPage(api: api))),
                  child: const Text('SDK и документация')),
            ]),
          ])),
      const SizedBox(height: 18),
      for (final (i, s) in steps.indexed)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: KpPanel(
                child: Row(children: [
              CircleAvatar(
                  backgroundColor: Kp.violet.withValues(alpha: .25),
                  child: Icon(s.$1, color: Kp.lilac, size: 20)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${i + 1}. ${s.$2}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(s.$3, style: const TextStyle(color: Kp.muted)),
                  ])),
            ]))),
    ]);
  }
}

/// Developer profile, and the publishing rules on the first fill.
class DeveloperProfileForm extends StatefulWidget {
  final PixelApi api;
  final DeveloperAccount? account;
  const DeveloperProfileForm({super.key, required this.api, this.account});
  @override
  State<DeveloperProfileForm> createState() => _DeveloperProfileFormState();
}

class _DeveloperProfileFormState extends State<DeveloperProfileForm> {
  late final fields = {
    for (final k in ['display_name', 'studio', 'contact_email', 'website', 'country', 'about'])
      k: TextEditingController(text: '${widget.account?.profile?[k] ?? ''}')
  };
  bool terms = false, busy = false;
  String? error;
  bool get first => widget.account?.registered != true;

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = await widget.api.saveDeveloper({
        for (final e in fields.entries) e.key: e.value.text.trim(),
        if (first) 'accept_terms': terms,
      });
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(String key, String label,
          {String? hint, int lines = 1, TextInputType? type}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
              controller: fields[key],
              minLines: lines,
              maxLines: lines == 1 ? 1 : 8,
              keyboardType: type,
              decoration: InputDecoration(labelText: label, hintText: hint)));

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(first ? 'Стать разработчиком' : 'Профиль разработчика')),
      body: KpPage(maxWidth: 640, children: [
        field('display_name', 'Имя или псевдоним *'),
        field('studio', 'Студия', hint: 'Если игру делает команда'),
        field('contact_email', 'Почта для модерации *', type: TextInputType.emailAddress),
        field('website', 'Сайт', hint: 'https://…', type: TextInputType.url),
        field('country', 'Страна'),
        field('about', 'О себе', lines: 3),
        if (first) ...[
          const SizedBox(height: 4),
          const KpPanel(
              child: Text(
                  'Правила публикации:\n'
                  '• В игре нет вирусов, майнеров, кражи данных и скрытой рекламы.\n'
                  '• У тебя есть права на игру, музыку, графику и шрифты.\n'
                  '• Описание и скриншоты соответствуют игре, возрастной рейтинг указан честно.\n'
                  '• Пока можно выпускать только бесплатные игры.\n'
                  '• Модерация может запросить правки, скрыть игру или заблокировать аккаунт за нарушения.',
                  style: TextStyle(color: Kp.muted, height: 1.7))),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: terms,
              onChanged: (v) => setState(() => terms = v == true),
              title: const Text('Принимаю правила публикации')),
        ],
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(error!, style: const TextStyle(color: Kp.error))),
        Align(
            alignment: Alignment.centerLeft,
            child: KpButton(busy ? 'Сохраняем…' : 'Сохранить',
                onTap: busy || (first && !terms) ? null : save)),
      ]));
}
