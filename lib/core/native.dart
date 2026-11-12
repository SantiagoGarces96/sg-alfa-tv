/*
 * SG Alfa Home — puente con la parte nativa de Android.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/services.dart';

class Native {
  Native._();

  static const launcher = MethodChannel('tv.sgalfa.home/launcher');
  static const protection = MethodChannel('tv.sgalfa.home/protection');
  static const appChanges = EventChannel('tv.sgalfa.home/app-changes');

  static Future<List<Map<String, dynamic>>> listApps() async {
    final raw = await launcher.invokeMethod<List<dynamic>>('listApps') ?? const [];
    return raw.whereType<Map>().map((m) => m.map((k, v) => MapEntry('$k', v))).toList();
  }

  static Future<Uint8List?> appImage(String pkg) =>
      launcher.invokeMethod<Uint8List>('appImage', {'package': pkg});

  static Future<void> launch(String pkg) => launcher.invokeMethod('launch', pkg);

  static Future<void> appInfo(String pkg) => launcher.invokeMethod('appInfo', pkg);

  static Future<void> uninstall(String pkg) => launcher.invokeMethod('uninstall', pkg);

  static Future<void> openSystemSettings() => launcher.invokeMethod('openSystemSettings');

  static Future<void> openWifiSettings() => launcher.invokeMethod('openWifiSettings');

  static Future<String> networkType() async {
    final m = await launcher.invokeMethod<Map>('network');
    return '${m?['type'] ?? 'none'}';
  }

  /// Se pulsó Inicio estando ya en el inicio.
  static void onHomePressed(VoidCallback cb) {
    launcher.setMethodCallHandler((call) async {
      if (call.method == 'homePressed') cb();
    });
  }
}
