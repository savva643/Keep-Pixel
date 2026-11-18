import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api.dart';
import '../shared.dart';
import 'common.dart';

const sdkVersion = '0.2.0';
const sdkDocs = 'https://github.com/savva643/Keep-Pixel/blob/main/sdk/README.md';

class _Kit {
  final String id, name, file, intro;
  final IconData icon;
  final List<String> steps;
  final String code;
  const _Kit(this.id, this.name, this.icon, this.file, this.intro, this.steps,
      this.code);
}

const _kits = [
  _Kit(
      'ue5',
      'Unreal Engine 5',
      Icons.view_in_ar_rounded,
      'KeepPixel-UE5-$sdkVersion.zip',
      'Плагин с Blueprint-нодами и C++ API. Исходники собираются вместе с проектом.',
      [
        'Распакуйте архив в <Проект>/Plugins/KeepPixelPlugin.',
        'Перегенерируйте файлы проекта и соберите Development Editor.',
        'Включите плагин в Edit → Plugins и перезапустите редактор.',
        'В GameInstance → Init вызовите Initialize From Launcher и проверьте Success.',
        'Дальше: Get User Profile, Get Friends List, Check License, Set Presence, Set Overlay Visible.',
        'Соберите Shipping, заархивируйте папку Windows и укажите в Keep Pixel exe из Binaries/Win64.',
      ],
      '// C++: UMyGameInstance::Init()\n'
      'FString Error;\n'
      'if (UKeepPixelAPI::InitializeFromLauncher(Error)) {\n'
      '  FKeepPixelResult Done;\n'
      '  UKeepPixelAPI::SetPresence(EKeepPixelPresence::InGame, Done);\n'
      '} else {\n'
      '  UE_LOG(LogTemp, Log, TEXT("Keep Pixel: %s"), *Error);\n'
      '}'),
  _Kit(
      'unity',
      'Unity',
      Icons.layers_rounded,
      'KeepPixel-Unity-$sdkVersion.zip',
      'Один C#-файл для Unity 2021.3+, корутины UnityWebRequest.',
      [
        'Распакуйте архив в корень проекта: появится Assets/KeepPixel/KeepPixelClient.cs.',
        'Создайте KeepPixelClient и вызывайте методы из MonoBehaviour через StartCoroutine.',
        'Соберите игру для Windows x86_64 и заархивируйте папку сборки целиком.',
      ],
      'var pixel = new Necsoura.KeepPixel.KeepPixelClient();\n'
      'StartCoroutine(pixel.GetFriends(\n'
      '    friends => Debug.Log(\$"Друзей: {friends.Length}"),\n'
      '    error => Debug.LogWarning(error.message)));'),
  _Kit(
      'godot',
      'Godot 4',
      Icons.smart_toy_rounded,
      'KeepPixel-Godot-$sdkVersion.zip',
      'GDScript-узел для Godot 4.x, проверен на 4.6.',
      [
        'Распакуйте архив в проект: addons/keep_pixel/keep_pixel_client.gd.',
        'Добавьте узел KeepPixelClient в автозагрузку или сцену.',
        'Экспортируйте для Windows и заархивируйте exe вместе с .pck.',
      ],
      'var pixel = KeepPixelClient.new()\n'
      'add_child(pixel)\n'
      'if not pixel.initialize():\n'
      '    return  # запущено не из Keep Pixel\n'
      'var response = await pixel.get_friends()\n'
      'if response.ok:\n'
      '    for friend in response.data:\n'
      '        print(friend.name, ": ", friend.presence)'),
  _Kit(
      'any',
      'Любой движок',
      Icons.terminal_rounded,
      'KeepPixel-Python-$sdkVersion.zip',
      'Обычный HTTP/JSON на 127.0.0.1: подойдёт любой язык. В архиве готовый клиент на Python и пример.',
      [
        'Лаунчер передаёт игре KEEPPIXEL_SDK_URL, KEEPPIXEL_SDK_TOKEN и KEEPPIXEL_GAME_ID в переменных окружения.',
        'Каждый запрос: заголовок Authorization: Bearer <KEEPPIXEL_SDK_TOKEN>.',
        'GET /session, /profile, /friends, /license; POST /presence и /overlay.',
        'Ответ: {"ok": true, "data": …} или {"ok": false, "error": {code, message}}.',
      ],
      'GET  \$KEEPPIXEL_SDK_URL/profile\n'
      'Authorization: Bearer \$KEEPPIXEL_SDK_TOKEN\n\n'
      'POST \$KEEPPIXEL_SDK_URL/presence\n'
      '{"status": "in_game"}'),
];

/// SDK kits for each engine, with short guides and the publishing checklist.
class SdkKitsPage extends StatefulWidget {
  final PixelApi api;
  const SdkKitsPage({super.key, required this.api});
  @override
  State<SdkKitsPage> createState() => _SdkKitsPageState();
}

class _SdkKitsPageState extends State<SdkKitsPage> {
  int selected = 0;
  String get origin => Uri.parse(widget.api.apiUrl).origin;

  @override
  Widget build(BuildContext context) {
    final kit = _kits[selected];
    return Scaffold(
        appBar: AppBar(title: const Text('SDK и документация')),
        body: KpPage(maxWidth: 960, children: [
          const DevSection(
              title: 'Что даёт Keep Pixel SDK',
              subtitle:
                  'SDK необязателен: игра без него устанавливается, обновляется и запускается, а друзья и оверлей Shift+Tab работают в лаунчере. SDK нужен, чтобы игра сама знала об игроке.',
              children: [
                _Feature(Icons.person_rounded, 'Профиль игрока',
                    'ID Necsoura, имя, аватар. Без пароля и токена аккаунта.'),
                _Feature(Icons.people_alt_rounded, 'Друзья',
                    'Список друзей, кто в сети и в какую игру играет.'),
                _Feature(Icons.verified_rounded, 'Лицензия',
                    'Проверка, что игра есть в библиотеке игрока.'),
                _Feature(Icons.sports_esports_rounded, 'Статус «в игре»',
                    'Друзья видят, что вы играете.'),
                _Feature(Icons.layers_rounded, 'Оверлей',
                    'Открыть панель Keep Pixel из меню игры.'),
              ]),
          const SizedBox(height: 14),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final (i, k) in _kits.indexed)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: KpChip(
                          label: k.name,
                          selected: i == selected,
                          onTap: () => setState(() => selected = i))),
              ])),
          const SizedBox(height: 14),
          AnimatedSwitcher(
              duration: Kp.motion,
              child: KeyedSubtree(
                  key: ValueKey(kit.id),
                  child: DevSection(
                      title: kit.name,
                      subtitle: kit.intro,
                      children: [
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          FilledButton.icon(
                              onPressed: () => openLink(
                                  context, '$origin/static/sdk/${kit.file}'),
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: Text('Скачать ${kit.file}')),
                          OutlinedButton.icon(
                              onPressed: () => openLink(context, sdkDocs),
                              icon: const Icon(Icons.menu_book_rounded, size: 18),
                              label: const Text('Полная документация')),
                        ]),
                        const SizedBox(height: 16),
                        for (final (i, s) in kit.steps.indexed)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                        radius: 12,
                                        backgroundColor:
                                            Kp.violet.withValues(alpha: .3),
                                        child: Text('${i + 1}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800))),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(s,
                                                style: const TextStyle(
                                                    height: 1.5)))),
                                  ])),
                        const SizedBox(height: 8),
                        _Code(kit.code),
                      ]))),
          const SizedBox(height: 14),
          DevSection(
              title: 'Весь SDK одним архивом',
              subtitle:
                  'Все адаптеры, примеры и README с полным описанием протокола.',
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                        onPressed: () => openLink(
                            context, '$origin/static/sdk/KeepPixelSDK-$sdkVersion.zip'),
                        icon: const Icon(Icons.archive_rounded, size: 18),
                        label: const Text('KeepPixelSDK-$sdkVersion.zip'))),
              ]),
          const SizedBox(height: 14),
          const DevSection(
              title: 'Оверлей и друзья без SDK',
              subtitle:
                  'Лаунчер сам следит за запущенной игрой: Shift+Tab открывает панель с друзьями и профилем поверх игры, статус «в игре» отправляется автоматически.',
              children: [
                Callout(
                    icon: Icons.info_outline_rounded,
                    color: Kp.lilac,
                    title: 'Панель видна в оконном режиме и в окне без рамки',
                    text:
                        'В эксклюзивном полноэкранном режиме Windows не даёт показать окно поверх игры. Делайте полноэкранный режим «без рамки» (в UE — Windowed Fullscreen), тогда оверлей работает всегда.'),
              ]),
          const SizedBox(height: 14),
          const DevSection(title: 'Сборка для публикации', children: [
            _Check('ZIP с папкой игры для Windows x64. Без установщика: лаунчер распаковывает архив сам.'),
            _Check('Укажите настоящий exe игры. Для UE: <Проект>/Binaries/Win64/<Проект>-Win64-Shipping.exe или <Проект>.exe из Binaries.'),
            _Check('Внутри архива не должно быть путей с «..», ссылок и файла .keep-pixel.json.'),
            _Check('Проверьте игру на чистом компьютере: нужные DLL и редистрибутивы лежат рядом с exe.'),
            _Check('Запустите игру из Keep Pixel и проверьте, что SDK получил профиль (если подключён).'),
            _Check('Обновление: новая версия — новый ZIP целиком; после одобрения игроки получат её автоматически.'),
          ]),
          const SizedBox(height: 14),
          const DevSection(title: 'Проверка SDK у себя', children: [
            Text(
                'SDK работает только в игре, запущенной из Keep Pixel. Добавьте игру в библиотеку (до публикации модератор может выдать её тестерам) и запустите из лаунчера. '
                'При автопроверке сервер сам находит SDK в сборке и показывает это модератору.',
                style: TextStyle(color: Kp.muted, height: 1.6)),
          ]),
        ]));
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _Feature(this.icon, this.title, this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Kp.lilac, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$title. ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: text, style: const TextStyle(color: Kp.muted)),
        ]))),
      ]));
}

class _Check extends StatelessWidget {
  final String text;
  const _Check(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: Kp.online, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
      ]));
}

class _Code extends StatelessWidget {
  final String code;
  const _Code(this.code);
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: Kp.bg, borderRadius: Kp.r14, border: Border.all(color: Kp.line)),
      child: Stack(children: [
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 14, 48, 14),
            child: SelectableText(code,
                style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontFamilyFallback: ['monospace', 'Courier New'],
                    fontSize: 13,
                    height: 1.5))),
        Positioned(
            right: 4,
            top: 4,
            child: IconButton(
                tooltip: 'Скопировать',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  notice(context, 'Скопировано');
                },
                icon: const Icon(Icons.copy_rounded, size: 18))),
      ]));
}
