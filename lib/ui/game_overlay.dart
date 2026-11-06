import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/game_overlay.dart';
import 'friends.dart';
import 'profile.dart';

/// Shared Flutter UI, presented by the Windows runner above the current game.
class GamePanel extends StatefulWidget {
  final PixelApi api;
  final GameOverlayController overlay;
  const GamePanel({super.key, required this.api, required this.overlay});
  @override
  State<GamePanel> createState() => _GamePanelState();
}

class _GamePanelState extends State<GamePanel> {
  int tab = 0;
  String? error;
  Future<void> close() async {
    try {
      await widget.overlay.close();
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'Не удалось вернуться в игру. Нажмите Shift+Tab.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
        child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: const Color(0xFF101820),
              body: SafeArea(
                  child: Column(children: [
                Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
                    decoration: const BoxDecoration(
                        color: Color(0xFF192632),
                        border: Border(
                            bottom: BorderSide(color: Color(0xFF30465C)))),
                    child: Row(children: [
                      const Icon(Icons.videogame_asset_rounded,
                          color: Color(0xFF83B7FF), size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('keep pixel',
                                style: TextStyle(
                                    fontFamily: 'Unbounded',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(
                                widget.overlay.games[widget.overlay.gameId] ??
                                    'В игре',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(color: Color(0xFFA7BCCF))),
                          ])),
                      FilledButton.tonalIcon(
                          onPressed: close,
                          icon: const Icon(Icons.keyboard_return),
                          label: const Text('Вернуться · Shift+Tab')),
                      const SizedBox(width: 8),
                      IconButton(
                          onPressed: close,
                          tooltip: 'Закрыть игровую панель · Esc',
                          icon: const Icon(Icons.close)),
                    ])),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.all(8), child: Text(error!)),
                Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    child: Row(children: [
                      ChoiceChip(
                          label: const Text('Друзья'),
                          selected: tab == 0,
                          onSelected: (_) => setState(() => tab = 0)),
                      const SizedBox(width: 10),
                      ChoiceChip(
                          label: const Text('Мой профиль'),
                          selected: tab == 1,
                          onSelected: (_) => setState(() => tab = 1)),
                      const Spacer(),
                      const Text('Necsoura • общий аккаунт',
                          style: TextStyle(
                              color: Color(0xFFA7BCCF), fontSize: 12)),
                    ])),
                Expanded(
                    child: IndexedStack(index: tab, children: [
                  FriendsPage(api: widget.api, active: tab == 0),
                  if (tab == 1)
                    ProfilePage(api: widget.api)
                  else
                    const SizedBox(),
                ])),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.shield_outlined,
                          size: 16, color: Color(0xFF83B7FF)),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Shift+Tab — открыть или закрыть панель · Esc — вернуться в игру',
                              style: TextStyle(
                                  color: Color(0xFFA7BCCF), fontSize: 11)))
                    ])),
              ])),
            )),
      );
}
