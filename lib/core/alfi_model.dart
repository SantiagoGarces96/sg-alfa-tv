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

class AlfiModel extends ChangeNotifier {
  int todayMinutes = 0;
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
      loaded = true;
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
