import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';
import 'shared.dart';

class ProfilePage extends StatefulWidget {
  final PixelApi api;
  const ProfilePage({super.key, required this.api});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<PixelProfile> profile;
  @override
  void initState() {
    super.initState();
    profile = widget.api.profile();
  }

  void reload() => setState(() {
        profile = widget.api.profile();
      });
  Future<void> edit(PixelProfile p) async {
    final result = await showDialog<PixelProfile>(
        context: context,
        builder: (_) => _ProfileEditor(api: widget.api, profile: p));
    if (result != null && mounted) {
      setState(() {
        profile = Future.value(result);
      });
      notice(context, 'Профиль Keep Pixel сохранён');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PixelProfile>(
      future: profile,
      builder: (context, state) {
        if (state.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.hasError) {
          return StatePanel(
              icon: Icons.cloud_off_rounded,
              title: 'Профиль недоступен',
              description: '${state.error}',
              action: 'Повторить',
              onAction: reload);
        }
        final p = state.data!;
        return ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(
                      height: 190,
                      child: Artwork(p.fields['banner']!,
                          label: 'Твоё пространство'))),
              const SizedBox(height: 24),
              Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: SizedBox(
                            width: 92,
                            height: 92,
                            child: Artwork(p.fields['avatar']!,
                                label: p.name.characters.first))),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(
                              p.username.isEmpty
                                  ? 'Публичный username пока не задан'
                                  : '@${p.username}',
                              style: const TextStyle(color: muted))
                        ]),
                    OutlinedButton.icon(
                        onPressed: () => edit(p),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Настроить профиль')),
                  ]),
              const SizedBox(height: 24),
              Tag(p.customized
                  ? 'Своё оформление в Keep Pixel'
                  : 'Оформление из Necsoura'),
              const SizedBox(height: 24),
              SelectableText(
                  p.fields['bio']!.isEmpty
                      ? 'Расскажи о себе — в общем профиле или только здесь.'
                      : p.fields['bio']!,
                  style: const TextStyle(color: muted, height: 1.8)),
              const SizedBox(height: 32),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Связанный аккаунт Necsoura',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            const Text(
                                'ID, логин и username общие для сервисов. Настройки выше меняют только оформление Keep Pixel.',
                                style: TextStyle(color: muted, height: 1.7)),
                            const SizedBox(height: 20),
                            SelectableText(
                                'ID: ${p.id}\nЛогин: ${p.login}\nUsername: ${p.username.isEmpty ? 'не задан' : p.username}',
                                style:
                                    const TextStyle(height: 1.9, fontSize: 12)),
                            const SizedBox(height: 20),
                            Wrap(spacing: 16, runSpacing: 12, children: [
                              OutlinedButton.icon(
                                  onPressed: () => openLink(context,
                                      '${widget.api.accountSite}/profile'),
                                  icon: const Icon(Icons.open_in_new_rounded,
                                      size: 16),
                                  label: const Text('Основной профиль')),
                              TextButton(
                                  onPressed: () async {
                                    try {
                                      await widget.api.logout();
                                    } catch (e) {
                                      if (context.mounted) {
                                        notice(context, '$e');
                                      }
                                    }
                                  },
                                  child: const Text('Выйти из Keep Pixel'))
                            ])
                          ]))),
            ]);
      });
}

class _ProfileEditor extends StatefulWidget {
  final PixelApi api;
  final PixelProfile profile;
  const _ProfileEditor({required this.api, required this.profile});
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  late final Map<String, bool> custom;
  bool busy = false;
  String? error;
  static const labels = {
    'display_name': 'Отображаемое имя',
    'avatar': 'Фото — ссылка на изображение',
    'banner': 'Шапка — ссылка на изображение',
    'bio': 'О себе'
  };
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final k in PixelProfile.presentationFields)
        k: TextEditingController(text: widget.profile.fields[k])
    };
    custom = {
      for (final k in PixelProfile.presentationFields)
        k: widget.profile.overrides.containsKey(k)
    };
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final patch = <String, dynamic>{};
      for (final k in PixelProfile.presentationFields) {
        final next = custom[k]! ? controllers[k]!.text.trim() : null;
        if (next != widget.profile.overrides[k]) patch[k] = next;
      }
      final result = patch.isEmpty
          ? widget.profile
          : await widget.api.updateProfile(patch);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Оформление Keep Pixel'),
          content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Включи своё значение для нужных полей. Остальные продолжат обновляться из Necsoura.',
                                style: TextStyle(color: muted, height: 1.6)),
                            const SizedBox(height: 20),
                            for (final k
                                in PixelProfile.presentationFields) ...[
                              SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(labels[k]!,
                                      style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(
                                      custom[k]!
                                          ? 'Только для Keep Pixel'
                                          : 'Из основного профиля',
                                      style: const TextStyle(
                                          fontSize: 11, color: muted)),
                                  value: custom[k]!,
                                  onChanged: busy
                                      ? null
                                      : (v) => setState(() => custom[k] = v)),
                              if (custom[k]!)
                                TextFormField(
                                    controller: controllers[k],
                                    enabled: !busy,
                                    maxLines: k == 'bio' ? 4 : 1,
                                    maxLength: k == 'bio'
                                        ? 2000
                                        : k == 'display_name'
                                            ? 80
                                            : 2048,
                                    decoration:
                                        InputDecoration(hintText: labels[k]),
                                    validator: (v) {
                                      if (k == 'display_name' &&
                                          (v == null || v.trim().isEmpty)) {
                                        return 'Введите имя';
                                      }
                                      if ((k == 'avatar' || k == 'banner') &&
                                          v != null &&
                                          v.trim().isNotEmpty) {
                                        final uri = Uri.tryParse(v.trim());
                                        if (uri == null ||
                                            !(['https'].contains(uri.scheme) ||
                                                (uri.scheme == 'http' &&
                                                    uri.host ==
                                                        Uri.parse(widget
                                                                .api.apiUrl)
                                                            .host)) ||
                                            uri.host.isEmpty ||
                                            uri.userInfo.isNotEmpty) {
                                          return 'Нужна HTTPS-ссылка на изображение';
                                        }
                                      }
                                      return null;
                                    })
                              else
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                        (widget.profile.account[k] ?? '')
                                                .isEmpty
                                            ? 'Не задано в Necsoura'
                                            : widget.profile.account[k]!,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: muted, fontSize: 12))),
                            ],
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                          for (final k in custom.keys) {
                                            custom[k] = false;
                                          }
                                        }),
                                child: const Text('Всё из основного профиля')),
                            if (error != null)
                              Text(error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                          ])))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Сохранение…' : 'Сохранить'))
          ]);
}
