import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';
import 'settings.dart';
import 'shared.dart';

/// Banner, avatar and name, the same for your own and someone else's profile.
class ProfileHeader extends StatelessWidget {
  final String banner, avatar, name, handle;
  final Widget? action;
  const ProfileHeader(
      {super.key,
      required this.banner,
      required this.avatar,
      required this.name,
      required this.handle,
      this.action});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 560;
        final size = compact ? 84.0 : 112.0;
        final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: TextStyle(
                      fontSize: compact ? 22 : 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6)),
              if (handle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(handle, style: const TextStyle(color: muted)),
              ]
            ]);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(clipBehavior: Clip.none, children: [
                ClipRRect(
                    borderRadius: Kp.r24,
                    child: SizedBox(
                        height: compact ? 150 : 220,
                        width: double.infinity,
                        child: Artwork(banner, label: name))),
                Positioned(
                    left: compact ? 16 : 28,
                    bottom: -size / 2,
                    child: Container(
                        width: size,
                        height: size,
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Kp.bg, shape: BoxShape.circle),
                        child: ClipOval(child: Artwork(avatar, label: name)))),
              ]),
              SizedBox(height: size / 2 + 12),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 12),
                  child: compact || action == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              details,
                              if (action != null) ...[
                                const SizedBox(height: 14),
                                action!
                              ]
                            ])
                      : Row(children: [Expanded(child: details), action!])),
            ]);
      });
}

class ProfilePage extends StatefulWidget {
  final PixelApi api;

  /// Opens the settings on a category. Without it (over a game) the page only
  /// shows the profile.
  final void Function(SettingsSection? section)? onSettings;
  const ProfilePage({super.key, required this.api, this.onSettings});
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
        final settings = widget.onSettings;
        return KpPage(maxWidth: 920, children: [
          ProfileHeader(
              banner: p.fields['banner']!,
              avatar: p.fields['avatar']!,
              name: p.name,
              handle: p.username.isEmpty ? '' : '@${p.username}',
              action: settings == null
                  ? null
                  : Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                          onPressed: () => settings(SettingsSection.profile),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Настроить профиль')),
                      IconButton.outlined(
                          tooltip: 'Настройки',
                          onPressed: () => settings(null),
                          icon: const Icon(Icons.settings_rounded)),
                    ])),
          const SizedBox(height: 20),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SelectableText(
                  p.fields['bio']!.isEmpty
                      ? 'Расскажи о себе — в общем профиле или только здесь.'
                      : p.fields['bio']!,
                  style: const TextStyle(color: muted, height: 1.7))),
        ]);
      });
}

/// Someone else's profile as Keep Pixel shows it: their overrides on top of
/// the shared Kompot profile.
Future<void> showPublicProfile(
        BuildContext context, PixelApi api, String id, String name) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 720),
        builder: (_) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: FutureBuilder<PixelProfile>(
                future: api.publicProfile(id),
                builder: (context, state) {
                  if (state.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.hasError) {
                    return StatePanel(
                        icon: Icons.cloud_off_rounded,
                        title: 'Профиль $name недоступен',
                        description: '${state.error}');
                  }
                  final p = state.data!;
                  return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        ProfileHeader(
                            banner: p.fields['banner']!,
                            avatar: p.fields['avatar']!,
                            name: p.name,
                            handle: p.username.isEmpty ? '' : '@${p.username}'),
                        if (p.fields['bio']!.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
                              child: SelectableText(p.fields['bio']!,
                                  style: const TextStyle(
                                      color: muted, height: 1.7))),
                      ]);
                })));

/// What others see in Keep Pixel. The base comes from Kompot; any part can be
/// replaced for Keep Pixel only.
class ProfileEditor extends StatefulWidget {
  final PixelApi api;
  final PixelProfile profile;
  final VoidCallback onSaved;
  const ProfileEditor(
      {super.key,
      required this.api,
      required this.profile,
      required this.onSaved});
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  late final Map<String, bool> custom;
  bool busy = false;
  String? error, uploading;
  static const fields = {
    'avatar': ('Фото', Icons.account_circle_rounded),
    'banner': ('Шапка', Icons.panorama_rounded),
    'display_name': ('Имя', Icons.person_rounded),
    'bio': ('О себе', Icons.notes_rounded),
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

  Future<void> upload(String key) async {
    final picked = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.single;
    if (file?.bytes == null) return;
    if (file!.size > 8 * 1024 * 1024) {
      setState(() => error = 'Картинка больше 8 МБ');
      return;
    }
    setState(() {
      uploading = key;
      error = null;
    });
    try {
      final url = await widget.api.uploadImage(file.bytes!, file.name);
      if (mounted) setState(() => controllers[key]!.text = url);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => uploading = null);
    }
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
      if (patch.isNotEmpty) await widget.api.updateProfile(patch);
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? validate(String k, String? v) {
    if (k == 'display_name' && (v == null || v.trim().isEmpty)) {
      return 'Введите имя';
    }
    if ((k == 'avatar' || k == 'banner') && v != null && v.trim().isNotEmpty) {
      final uri = Uri.tryParse(v.trim());
      if (uri == null ||
          !(['https'].contains(uri.scheme) ||
              (uri.scheme == 'http' &&
                  uri.host == Uri.parse(widget.api.apiUrl).host)) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        return 'Нужна HTTPS-ссылка на изображение';
      }
    }
    return null;
  }

  // What the profile will look like with the current choices.
  String _shown(String k) =>
      custom[k]! ? controllers[k]!.text.trim() : widget.profile.account[k]!;

  Widget _field(String k) {
    final (label, icon) = fields[k]!;
    final image = k == 'avatar' || k == 'banner';
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 20, color: muted),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(custom[k]! ? 'Только для Keep Pixel' : 'Из Kompot',
                      style: const TextStyle(fontSize: 12, color: muted)),
                ])),
            Switch.adaptive(
                value: custom[k]!,
                onChanged: busy ? null : (v) => setState(() => custom[k] = v)),
          ]),
          if (custom[k]!) ...[
            const SizedBox(height: 10),
            if (image) ...[
              Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                      onPressed:
                          busy || uploading != null ? null : () => upload(k),
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: Text(uploading == k
                          ? 'Загрузка…'
                          : 'Загрузить картинку'))),
              const SizedBox(height: 10),
            ],
            TextFormField(
                controller: controllers[k],
                enabled: !busy,
                maxLines: k == 'bio' ? 4 : 1,
                maxLength: k == 'bio'
                    ? 2000
                    : k == 'display_name'
                        ? 80
                        : 2048,
                decoration: InputDecoration(
                    hintText: image ? 'Или ссылка на картинку' : label),
                validator: (v) => validate(k, v)),
          ],
        ]));
  }

  @override
  Widget build(BuildContext context) => Form(
      key: form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListenableBuilder(
            listenable: Listenable.merge(controllers.values.toList()),
            builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileHeader(
                          banner: _shown('banner'),
                          avatar: _shown('avatar'),
                          name: _shown('display_name').isEmpty
                              ? 'Игрок'
                              : _shown('display_name'),
                          handle: widget.profile.username.isEmpty
                              ? ''
                              : '@${widget.profile.username}'),
                      if (_shown('bio').isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: Text(_shown('bio'),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: muted, height: 1.6))),
                    ])),
        const SizedBox(height: 24),
        KpPanel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              for (final k in fields.keys) ...[
                _field(k),
                if (k != fields.keys.last) const Divider(height: 18),
              ],
            ])),
        const SizedBox(height: 16),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error!, style: const TextStyle(color: Kp.error))),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                  onPressed: busy || uploading != null ? null : save,
                  child: Text(busy ? 'Сохранение…' : 'Сохранить')),
              TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            for (final k in custom.keys) {
                              custom[k] = false;
                            }
                          }),
                  child: const Text('Всё из основного профиля')),
            ]),
      ]));
}
