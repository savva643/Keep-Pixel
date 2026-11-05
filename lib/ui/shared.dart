import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const muted = Color(0xFF9DAFA6);
const accent = Color(0xFFB7EDC6);

void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
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
    Widget placeholder() => Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF334E45), Color(0xFF1F2935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.extension_rounded,
                size: 48, color: Color(0xFFABC8B6)),
            const SizedBox(height: 12),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFCADBCF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600)))
          ])),
        );
    final uri = Uri.tryParse(url);
    if (uri?.scheme != 'https') return placeholder();
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
  final String? action;
  final VoidCallback? onAction;
  const StatePanel(
      {super.key,
      this.icon = Icons.info_outline_rounded,
      required this.title,
      required this.description,
      this.action,
      this.onAction});
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
                ]
              ]))));
}

class Tag extends StatelessWidget {
  final String label;
  const Tag(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: accent.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: const TextStyle(
              color: accent, fontSize: 11, fontWeight: FontWeight.w600)));
}
