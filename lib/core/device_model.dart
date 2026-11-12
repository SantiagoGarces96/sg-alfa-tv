/*
 * SG Alfa Home — ¿estamos en un televisor o en un deco?
 * Cada uno tiene accesos y consejos distintos.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/foundation.dart';

import 'native.dart';

class DeviceModel extends ChangeNotifier {
  bool isTv = false;
  String model = '';
  double? freeGb;
  double? totalGb;
  bool loaded = false;

  /// «tu tele» o «tu deco», para hablarle al usuario.
  String get your => isTv ? 'tu tele' : 'tu deco';
  String get name => isTv ? 'Televisor' : 'Deco';

  bool get lowStorage => freeGb != null && freeGb! < 1.0;

  Future<void> load() async {
    try {
      final m = await Native.launcher.invokeMethod<Map>('deviceInfo');
      if (m != null) {
        isTv = m['kind'] == 'tv';
        model = '${m['model'] ?? ''}';
        freeGb = (m['freeGb'] as num?)?.toDouble();
        totalGb = (m['totalGb'] as num?)?.toDouble();
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }
}
