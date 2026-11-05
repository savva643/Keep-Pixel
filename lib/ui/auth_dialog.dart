import 'package:flutter/material.dart';
import '../core/api.dart';
import 'shared.dart';

Future<bool> showLogin(BuildContext context, PixelApi api) async =>
    await showDialog<bool>(
        context: context, builder: (_) => LoginDialog(api: api)) ??
    false;

class LoginDialog extends StatefulWidget {
  final PixelApi api;
  const LoginDialog({super.key, required this.api});
  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final form = GlobalKey<FormState>();
  final login = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  bool busy = false, second = false, backup = false, visible = false;
  String? error;
  @override
  void dispose() {
    login.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (second) {
        await widget.api.confirm2fa(code.text, backup: backup);
      } else if (!await widget.api.login(login.text, password.text)) {
        if (mounted) setState(() => second = true);
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(second ? 'Подтвердите вход' : 'Один аккаунт. Больше игр.'),
        content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
                child: Form(
                    key: form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Вход через Necsoura',
                              style: TextStyle(color: muted)),
                          const SizedBox(height: 24),
                          if (!second) ...[
                            TextFormField(
                                controller: login,
                                enabled: !busy,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                    labelText: 'Логин или email'),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Введите логин'
                                    : null),
                            const SizedBox(height: 14),
                            TextFormField(
                                controller: password,
                                enabled: !busy,
                                obscureText: !visible,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                    labelText: 'Пароль',
                                    suffixIcon: IconButton(
                                        tooltip: 'Показать пароль',
                                        onPressed: () =>
                                            setState(() => visible = !visible),
                                        icon: Icon(visible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined))),
                                onFieldSubmitted: (_) => submit(),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Введите пароль'
                                    : null),
                          ] else ...[
                            TextFormField(
                                controller: code,
                                enabled: !busy,
                                autofocus: true,
                                decoration: InputDecoration(
                                    labelText: backup
                                        ? 'Резервный код'
                                        : 'Код из приложения'),
                                onFieldSubmitted: (_) => submit(),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Введите код'
                                    : null),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                          backup = !backup;
                                          error = null;
                                        }),
                                child: Text(backup
                                    ? 'Код из приложения'
                                    : 'Использовать резервный код')),
                          ],
                          if (error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          if (!second)
                            TextButton(
                                onPressed: () => openLink(context,
                                    '${widget.api.accountSite}/auth/login'),
                                child: const Text(
                                    'Забыли пароль? Восстановить в Necsoura')),
                          if (!second)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: TextButton(
                                    onPressed: () => openLink(context,
                                        '${widget.api.accountSite}/auth/register'),
                                    child: const Text(
                                        'Создать аккаунт Necsoura'))),
                        ])))),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: busy ? null : submit,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(second ? 'Подтвердить' : 'Войти'))
        ],
      );
}
