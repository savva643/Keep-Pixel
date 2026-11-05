import 'package:flutter/material.dart';
import '../core/api.dart';
import 'shared.dart';

class ConnectionSettings extends StatefulWidget {
  final PixelApi api;
  const ConnectionSettings({super.key, required this.api});
  @override
  State<ConnectionSettings> createState() => _ConnectionSettingsState();
}

class _ConnectionSettingsState extends State<ConnectionSettings> {
  late final shop = TextEditingController(text: widget.api.apiUrl),
      account = TextEditingController(text: widget.api.authUrl);
  bool busy = false;
  String? result;
  bool success = false;
  @override
  void dispose() {
    shop.dispose();
    account.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      result = null;
    });
    try {
      await widget.api.setEndpoints(shop.text, account.text);
      final message = await widget.api.checkConnection();
      if (mounted) {
        setState(() {
          success = true;
          result = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          success = false;
          result = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Подключение к серверу',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text(
            'Адреса можно менять без пересборки. После смены сервера нужно войти заново.',
            style: TextStyle(color: muted, height: 1.7)),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 8, children: [
          OutlinedButton(
              onPressed: busy
                  ? null
                  : () {
                      shop.text = 'http://85.112.56.145:4002';
                      account.text = 'http://85.112.56.145:3001/api/auth';
                    },
              child: const Text('Напрямую к Docker')),
          OutlinedButton(
              onPressed: busy
                  ? null
                  : () {
                      shop.text = 'http://85.112.56.145/api/keeppixel';
                      account.text = 'http://85.112.56.145/api/auth';
                    },
              child: const Text('Через Nginx · порт 80')),
        ]),
        const SizedBox(height: 24),
        TextField(
            controller: shop,
            enabled: !busy,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Адрес API магазина')),
        const SizedBox(height: 16),
        TextField(
            controller: account,
            enabled: !busy,
            keyboardType: TextInputType.url,
            decoration:
                const InputDecoration(labelText: 'Адрес API аккаунтов')),
        const SizedBox(height: 20),
        Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                onPressed: busy ? null : save,
                icon: const Icon(Icons.wifi_tethering_rounded),
                label: Text(busy ? 'Проверка…' : 'Сохранить и проверить'))),
        if (result != null)
          Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SelectableText(result!,
                  style: TextStyle(
                      color: success
                          ? accent
                          : Theme.of(context).colorScheme.error,
                      height: 1.7))),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text(
            widget.api.persistentSession
                ? 'Сеанс сохраняется в защищённом хранилище устройства.'
                : 'В HTTP-браузере сеанс хранится только в памяти вкладки. После перезагрузки потребуется вход.',
            style: const TextStyle(color: muted, height: 1.7)),
        const SizedBox(height: 16),
        const Text(
            'HTTP · сервер пока работает без шифрования. При подключении домена с HTTPS замени адреса здесь.',
            style: TextStyle(color: muted, height: 1.7)),
      ]);
}
