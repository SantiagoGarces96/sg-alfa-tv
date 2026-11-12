/*
 * SG Alfa Home — lo que Alfi sabe: uso por app, hábitos, apps olvidadas y caché.
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'native.dart';

class AlfiApp {
  final String package;
  final String name;
  final num value; // minutos o MB

  const AlfiApp(this.package, this.name, this.value);

  static List<AlfiApp> list(dynamic raw, String key) => raw is List
      ? raw
          .whereType<Map>()
          .map((m) => AlfiApp('${m['package']}', '${m['name'] ?? m['package']}', (m[key] as num?) ?? 0))
          .toList()
      : const [];
}

/// Algo que Alfi apuntó en su libreta: un pop-up de anuncio o un dominio que se coló.
class AdSighting {
  final String kind; // popup | dominio
  final String when;
  final int times;
  final String app;
  final String appName;
  final String text;
  final String domain;
  final List<String> buttons;

  const AdSighting(this.kind, this.when, this.times, this.app, this.appName, this.text, this.domain, this.buttons);

  bool get isPopup => kind == 'popup';

  /// El botón con más pinta de «cerrar» de los que tenía el pop-up.
  String? get closeButton {
    final re = RegExp(r'^(x|×|✕|cerrar|close|omitir|saltar|skip|no,? gracias|ahora no|continuar|cancelar|seguir viendo)',
        caseSensitive: false);
    for (final b in buttons) {
      if (re.hasMatch(b.trim())) return b;
    }
    return null;
  }
}

class AlfiModel extends ChangeNotifier {
  int todayMinutes = 0;
  int yesterdayMinutes = 0;
  AlfiApp? last;
  int lastMinutesAgo = 0;
  List<AlfiApp> newApps = const [];
  List<AdSighting> sightings = const [];
  int weekMinutes = 0;
  List<AlfiApp> today = const [];
  List<AlfiApp> week = const [];
  Map<String, AlfiApp> slots = const {};
  List<AlfiApp> forgotten = const [];
  List<AlfiApp> cache = const [];
  double cacheTotalMb = 0;
  bool loaded = false;
  Timer? _timer;

  void start() {
    refresh();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final r = await Native.launcher.invokeMethod<Map>('alfiReport');
      if (r == null) return;
      todayMinutes = (r['todayMinutes'] as num?)?.toInt() ?? 0;
      yesterdayMinutes = (r['yesterdayMinutes'] as num?)?.toInt() ?? 0;
      final l = r['last'];
      last = l is Map ? AlfiApp('${l['package']}', '${l['name']}', 0) : null;
      lastMinutesAgo = l is Map ? ((l['minutesAgo'] as num?)?.toInt() ?? 9999) : 9999;
      newApps = AlfiApp.list(r['newApps'], 'none');
      weekMinutes = (r['weekMinutes'] as num?)?.toInt() ?? 0;
      today = AlfiApp.list(r['today'], 'minutes');
      week = AlfiApp.list(r['week'], 'minutes');
      final s = r['slots'];
      slots = s is Map
          ? {
              for (final e in s.entries)
                if (e.value is Map)
                  '${e.key}': AlfiApp('${e.value['package']}', '${e.value['name']}', (e.value['days'] as num?) ?? 0),
            }
          : const {};
      forgotten = AlfiApp.list(r['forgotten'], 'none');
      cache = AlfiApp.list(r['cache'], 'mb');
      cacheTotalMb = (r['cacheTotalMb'] as num?)?.toDouble() ?? 0;
      await refreshAds(notify: false);
      loaded = true;
      notifyListeners();
    } catch (_) {}
  }

  /// La libreta de anuncios (pop-ups y dominios que se colaron).
  Future<void> refreshAds({bool notify = true}) async {
    try {
      final raw = await Native.protection.invokeMethod<List>('adLog');
      _setAds(raw);
      if (notify) notifyListeners();
    } catch (_) {}
  }

  void _setAds(List? raw) {
    sightings = (raw ?? const [])
        .whereType<Map>()
        .map((m) => AdSighting(
              '${m['tipo']}',
              '${m['cuando']}',
              (m['veces'] as num?)?.toInt() ?? 1,
              '${m['app'] ?? ''}',
              '${m['nombre'] ?? ''}',
              '${m['texto'] ?? ''}',
              '${m['dominio'] ?? ''}',
              (m['botones'] is List) ? (m['botones'] as List).map((e) => '$e').toList() : const <String>[],
            ))
        .toList();
  }

  List<AdSighting> get popups => sightings.where((x) => x.isPopup).toList();
  List<AdSighting> get leakedDomains => sightings.where((x) => !x.isPopup).toList();

  /// Pop-ups de hoy agrupados por app (la app con más anuncios primero).
  List<MapEntry<String, int>> get adsByAppToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final m = <String, int>{};
    for (final x in popups) {
      if (!x.when.startsWith(today)) continue;
      final k = x.appName.isEmpty ? x.app : x.appName;
      m[k] = (m[k] ?? 0) + x.times;
    }
    final list = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  Future<void> blockDomain(String d) async {
    try {
      _setAds(await Native.protection.invokeMethod<List>('blockDomain', d));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> blockAllLeaked() async {
    for (final d in leakedDomains.map((x) => x.domain).toSet().toList()) {
      await blockDomain(d);
    }
  }

  Future<void> clearAds() async {
    try {
      await Native.protection.invokeMethod('clearAdLog');
      sightings = const [];
      notifyListeners();
    } catch (_) {}
  }

  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String size(double mb) => mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${mb.round()} MB';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
