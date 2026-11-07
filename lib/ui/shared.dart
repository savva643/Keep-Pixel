import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'style.dart';

export 'style.dart';

const muted = Kp.muted;
const accent = Kp.lilac;

void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) notice(context, 'Не удалось открыть ссылку');
  }
}

class Artwork extends StatelessWidget {
  final String url;
  final String label;
  const Artwork(this.url, {super.key, this.label = 'Keep Pixel'});
  @override
  Widget build(BuildContext context) {
    Widget placeholder() => LayoutBuilder(builder: (context, box) {
          final art = KpArt(label.isEmpty ? 'Keep Pixel' : label);
          if (box.maxWidth >= 100 || label.isEmpty) return art;
          return Stack(fit: StackFit.expand, children: [
            art,
            Center(
                child: Text(label.characters.first.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Kp.text)))
          ]);
        });
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return placeholder();
    }
    return Image.network(url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => placeholder(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder());
  }
}

class StatePanel extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final String? action, secondaryAction;
  final VoidCallback? onAction, onSecondaryAction;
  const StatePanel(
      {super.key,
      this.icon = Icons.info_outline_rounded,
      required this.title,
      required this.description,
      this.action,
      this.onAction,
      this.secondaryAction,
      this.onSecondaryAction});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 48, color: accent),
                const SizedBox(height: 20),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, height: 1.7)),
                if (action != null) ...[
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onAction, child: Text(action!))
                ],
                if (secondaryAction != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: onSecondaryAction,
                      child: Text(secondaryAction!))
                ]
              ]))));
}

class Tag extends StatelessWidget {
  final String label;
  const Tag(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
          color: Kp.violet.withValues(alpha: .2),
          borderRadius: Kp.r20,
          border: Border.all(color: Kp.violet.withValues(alpha: .55))),
      child: Text(label,
          style: const TextStyle(
              color: accent,
              fontSize: 11,
              letterSpacing: .4,
              fontWeight: FontWeight.w700)));
}
