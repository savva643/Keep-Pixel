import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the player keeps about their games on this device: favourites, hidden
/// games, play time and when each game was last started.
class LibraryPrefs extends ChangeNotifier {
  final favorites = <String>{}, hidden = <String>{};
  final _seconds = <String, int>{};
  final _lastPlayed = <String, DateTime>{};
  final _started = <String, DateTime>{};
  bool _disposed = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      favorites.addAll(prefs.getStringList('keep_pixel_favorites') ?? []);
      hidden.addAll(prefs.getStringList('keep_pixel_hidden') ?? []);
      final stats = jsonDecode(prefs.getString('keep_pixel_play_stats') ?? '{}')
          as Map<String, dynamic>;
      for (final entry in stats.entries) {
        final value = entry.value as Map;
        _seconds[entry.key] = (value['seconds'] as num? ?? 0).toInt();
        final last = DateTime.tryParse('${value['last'] ?? ''}');
        if (last != null) _lastPlayed[entry.key] = last;
      }
    } catch (_) {
      // Damaged or missing preferences only lose these extras.
    }
    _notify();
  }

  Duration playTime(String id) => Duration(seconds: _seconds[id] ?? 0);
  DateTime? lastPlayed(String id) => _lastPlayed[id];
  bool isFavorite(String id) => favorites.contains(id);
  bool isHidden(String id) => hidden.contains(id);

  void toggleFavorite(String id) {
    if (!favorites.remove(id)) favorites.add(id);
    _save();
  }

  void toggleHidden(String id) {
    if (!hidden.remove(id)) hidden.add(id);
    _save();
  }

  void started(String id) {
    final now = DateTime.now();
    _started[id] = now;
    _lastPlayed[id] = now;
    _save();
  }

  void stopped(String id) {
    final start = _started.remove(id);
    if (start == null) return;
    _seconds[id] =
        (_seconds[id] ?? 0) + DateTime.now().difference(start).inSeconds;
    _save();
  }

  void _save() {
    _notify();
    final stats = {
      for (final id in {..._seconds.keys, ..._lastPlayed.keys})
        id: {
          'seconds': _seconds[id] ?? 0,
          if (_lastPlayed[id] != null)
            'last': _lastPlayed[id]!.toIso8601String()
        }
    };
    unawaited(SharedPreferences.getInstance().then((p) async {
      await p.setStringList('keep_pixel_favorites', favorites.toList());
      await p.setStringList('keep_pixel_hidden', hidden.toList());
      await p.setString('keep_pixel_play_stats', jsonEncode(stats));
    }).catchError((_) {}));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String playTimeLabel(Duration d) {
  if (d.inMinutes < 1) return d.inSeconds == 0 ? '0 мин' : '< 1 мин';
  if (d.inHours < 1) return '${d.inMinutes} мин';
  final hours = d.inMinutes / 60;
  return '${hours.toStringAsFixed(hours < 10 ? 1 : 0)} ч';
}

String lastPlayedLabel(DateTime? at, {DateTime? now}) {
  if (at == null) return 'Никогда';
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'Сегодня';
  if (days == 1) return 'Вчера';
  if (days < 7) return '$days дн. назад';
  const months = [
    'янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня', //
    'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'
  ];
  return '${at.day} ${months[at.month - 1]}${at.year == now.year ? '' : ' ${at.year}'}';
}
