import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/installer.dart';
import 'settings.dart';
import 'style.dart';

const _subWindow = MethodChannel('keep_pixel/sub_window');
const _kind = 'settings';

Map<String, dynamic> _sessionOf(PixelApi api) => {
      'token': api.sessionToken,
      'api': api.apiUrl,
      'auth': api.authUrl,
      'device': api.deviceHeaders['device-fingerprint'] ?? '',
    };

/// Settings in their own window, like Steam. The session belongs to the main
/// window: this one borrows its token and asks it to renew or end the session.
class SettingsWindow {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<WindowController?> _existing() async {
    for (final window in await WindowController.getAll()) {
      if (window.arguments.startsWith(_kind)) return window;
    }
    return null;
  }

  /// Called from the main window. Reopening brings the existing window forward.
  static Future<void> open(
      {required NavStyle navStyle,
      required int startPage,
      SettingsSection? section}) async {
    final existing = await _existing();
    if (existing != null) {
      await existing.invokeMethod<void>('focus', section?.name);
      return;
    }
    final main = await WindowController.fromCurrentEngine();
    // The window shows itself once its frame is ready, so it never flashes.
    await WindowController.create(WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: '$_kind${jsonEncode({
              'main': main.windowId,
              'nav': navStyle.name,
              'start': startPage,
              'section': section?.name,
            })}'));
  }

  /// Tells an open window that the session or the server changed.
  static Future<void> pushSession(PixelApi api) async {
    try {
      await (await _existing())?.invokeMethod<void>('session', _sessionOf(api));
    } on PlatformException {
      // The window has just been closed.
    }
  }

  /// Handles what the settings window asks of the main one.
  static Future<void> listen(
      {required PixelApi api,
      required ValueChanged<NavStyle> onNavStyle,
      required ValueChanged<int> onStartPage,
      required Future<String> Function(String api, String auth) onEndpoints,
      required VoidCallback onSignIn}) async {
    final main = await WindowController.fromCurrentEngine();
    await main.setWindowMethodHandler((call) async {
      final args = call.arguments;
      switch (call.method) {
        case 'nav':
          onNavStyle(NavStyle.values.byName(args as String));
        case 'start':
          onStartPage(args as int);
        case 'signIn':
          onSignIn();
        case 'session':
          return _sessionOf(api);
        case 'renew':
          return await api.refreshSession() ? api.sessionToken : null;
        case 'apply':
          await api.applySession(Map<String, dynamic>.from(args as Map));
        case 'logout':
          await api.logout();
        case 'profile':
          api.profileChanged();
        case 'endpoints':
          try {
            final map = Map<String, dynamic>.from(args as Map);
            return await onEndpoints(
                map['api'] as String, map['auth'] as String);
          } catch (e) {
            throw PlatformException(code: 'endpoints', message: '$e');
          }
      }
      return null;
    });
  }

  /// Entry point of the window's own engine; null if this is the main window.
  static Widget? fromArguments(List<String> args) {
    if (args.length < 3 ||
        args[0] != 'multi_window' ||
        !args[2].startsWith(_kind)) {
      return null;
    }
    return _SettingsApp(Map<String, dynamic>.from(
        jsonDecode(args[2].substring(_kind.length)) as Map));
  }
}

class _SettingsApp extends StatefulWidget {
  final Map<String, dynamic> config;
  const _SettingsApp(this.config);
  @override
  State<_SettingsApp> createState() => _SettingsAppState();
}

class _SettingsAppState extends State<_SettingsApp> {
  late NavStyle nav = NavStyle.values.byName(widget.config['nav'] as String);
  late int start = widget.config['start'] as int;
  late final main =
      WindowController.fromWindowId(widget.config['main'] as String);
  late final PixelApi api = PixelApi(
      owner: SessionOwner(
          renew: () => main.invokeMethod<String>('renew'),
          apply: (session) => main.invokeMethod<void>('apply', session),
          logout: () => main.invokeMethod<void>('logout'),
          profileChanged: () => main.invokeMethod<void>('profile')));
  final view = GlobalKey<SettingsViewState>();

  void _adopt(Object? session) {
    final map = Map<String, dynamic>.from(session as Map);
    api.adoptSession(
        token: map['token'] as String?,
        apiUrl: map['api'] as String,
        authUrl: map['auth'] as String,
        device: map['device'] as String);
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await _subWindow.invokeMethod('frameless', {'width': 980, 'height': 680});
    final own = await WindowController.fromCurrentEngine();
    await own.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'focus':
          await _subWindow.invokeMethod('focus');
          if (call.arguments is String) {
            view.currentState
                ?.show(SettingsSection.values.byName(call.arguments as String));
          }
        case 'session':
          _adopt(call.arguments);
      }
      return null;
    });
    _adopt(await main.invokeMethod<Object?>('session'));
    await own.show();
    await _subWindow.invokeMethod('focus');
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.config['section'] as String?;
    final strings = EasyLocalization.of(context);
    return MaterialApp(
        title: 'Настройки Keep Pixel',
        debugShowCheckedModeBanner: false,
        theme: kpTheme(),
        localizationsDelegates: strings?.delegates,
        supportedLocales: strings?.supportedLocales ?? const [Locale('ru')],
        locale: strings?.locale ?? const Locale('ru'),
        home: Scaffold(
            body: Column(children: [
          GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => _subWindow.invokeMethod('drag'),
              child: Container(
                  height: 52,
                  padding: const EdgeInsets.fromLTRB(18, 0, 10, 0),
                  decoration: const BoxDecoration(
                      color: Kp.surface,
                      border: Border(bottom: BorderSide(color: Kp.line))),
                  child: Row(children: [
                    Image.asset('assets/images/logo.png',
                        width: 22, height: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text('Настройки',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700))),
                    WindowButtons(
                        onMinimize: () => _subWindow.invokeMethod('minimize'),
                        onClose: () => _subWindow.invokeMethod('close')),
                  ]))),
          Expanded(
              child: SettingsView(
                  key: view,
                  api: api,
                  installer: GameInstaller(),
                  section: section == null
                      ? null
                      : SettingsSection.values.byName(section),
                  navStyle: nav,
                  onNavStyle: (style) {
                    setState(() => nav = style);
                    main.invokeMethod<void>('nav', style.name);
                  },
                  startPage: start,
                  onStartPage: (page) {
                    setState(() => start = page);
                    main.invokeMethod<void>('start', page);
                  },
                  // Sign-in screens live in the main window, which this one
                  // would otherwise cover.
                  onSignIn: () async {
                    await main.invokeMethod<void>('signIn');
                    await _subWindow.invokeMethod('close');
                  },
                  onSaveEndpoints: (api, auth) async {
                    try {
                      return await main.invokeMethod<String>(
                              'endpoints', {'api': api, 'auth': auth}) ??
                          '';
                    } on PlatformException catch (e) {
                      throw e.message ?? 'Не удалось сохранить';
                    }
                  })),
        ])));
  }
}
