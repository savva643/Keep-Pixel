import 'package:flutter/material.dart';
import '../style.dart';

/// Status words and colours shared by the developer screens.
const gameStatus = {
  'draft': ('Черновик', Kp.muted),
  'review': ('На модерации', Color(0xFFFBBF24)),
  'changes': ('Нужны правки', Color(0xFFFBBF24)),
  'approved': ('Одобрена', Color(0xFF60A5FA)),
  'published': ('Опубликована', Kp.online),
  'hidden': ('Скрыта', Kp.muted),
  'rejected': ('Отклонена', Kp.error),
};
const storeStatus = {
  'none': ('Витрина не отправлена', Kp.muted),
  'pending': ('Витрина на проверке', Color(0xFFFBBF24)),
  'changes': ('Витрину нужно исправить', Color(0xFFFBBF24)),
  'approved': ('Витрина одобрена', Kp.online),
};
const buildStatus = {
  'uploading': ('Загружается', Kp.muted),
  'scanning': ('Автопроверка', Color(0xFF60A5FA)),
  'scan_failed': ('Не прошла проверку', Kp.error),
  'review': ('Ждёт модератора', Color(0xFFFBBF24)),
  'approved': ('Одобрена', Color(0xFF60A5FA)),
  'rejected': ('Отклонена', Kp.error),
  'live': ('У игроков', Kp.online),
  'superseded': ('Прошлая версия', Kp.muted),
};
const historyText = {
  'created': 'Черновик создан',
  'submitted': 'Отправлено на модерацию',
  'build_uploaded': 'Сборка загружена',
  'scan_passed': 'Автопроверка пройдена',
  'scan_failed': 'Автопроверка не пройдена',
  'build_approve': 'Модератор одобрил сборку',
  'build_reject': 'Модератор отклонил сборку',
  'store_approve': 'Модератор одобрил витрину',
  'store_changes': 'Модератор просит исправить витрину',
  'store_reject': 'Игра отклонена',
  'store_edited': 'Витрина изменена, ждёт проверки',
  'approved': 'Игра одобрена',
  'published': 'Опубликована',
  'hidden': 'Скрыта из магазина',
  'shown': 'Снова в магазине',
  'rescan': 'Сборка перепроверяется',
};
const engines = {
  '': 'Не указан',
  'unreal': 'Unreal Engine',
  'unity': 'Unity',
  'godot': 'Godot',
  'other': 'Другой движок'
};

class StatusPill extends StatelessWidget {
  final (String, Color) status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: status.$2.withValues(alpha: .14),
          borderRadius: Kp.r20,
          border: Border.all(color: status.$2.withValues(alpha: .5))),
      child: Text(status.$1,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: status.$2, fontSize: 12, fontWeight: FontWeight.w700)));
}

String formatBytes(num n) {
  const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

String formatDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// A titled block of a developer screen.
class DevSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  const DevSection(
      {super.key,
      required this.title,
      this.subtitle,
      required this.children,
      this.trailing});
  @override
  Widget build(BuildContext context) => KpPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: KpHeading(title)),
          if (trailing != null) trailing!,
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: const TextStyle(color: Kp.muted, height: 1.5)),
        ],
        const SizedBox(height: 14),
        ...children,
      ]));
}

/// A coloured message: what the moderator asked, or what is missing.
class Callout extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? text;
  final Widget? child;
  const Callout(
      {super.key,
      required this.icon,
      required this.color,
      required this.title,
      this.text,
      this.child});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: Kp.r14,
          border: Border.all(color: color.withValues(alpha: .45))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (text != null && text!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(text!, style: const TextStyle(color: Kp.muted, height: 1.5)),
              ],
              if (child != null) ...[const SizedBox(height: 8), child!],
            ])),
      ]));
}
