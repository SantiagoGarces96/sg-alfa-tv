/*
 * SG Alfa Home — ¿hay versión nueva? Mira GitHub al arrancar y cada 6 horas.
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'native.dart';

class UpdateModel extends ChangeNotifier {
  String current = '';
  String latest = '';
  String notes = '';
  String? url;
  bool available = false;
  bool checking = false;
  String? checkError;

  // Descarga
  String state = 'idle'; // idle | downloading | ready | error
  int downloaded = 0;
  int size = 0;
  String error = '';
  Timer? _poll;
  Timer? _periodic;

  double get fraction => size > 0 ? (downloaded / size).clamp(0, 1).toDouble() : 0;

  void start() {
    check();
    _periodic = Timer.periodic(const Duration(hours: 6), (_) => check());
  }

  Future<void> check() async {
    checking = true;
    notifyListeners();
    try {
      final r = await Native.launcher.invokeMethod<Map>('checkUpdate');
      if (r != null) {
        current = '${r['current'] ?? ''}';
        latest = '${r['latest'] ?? ''}';
        notes = '${r['notes'] ?? ''}';
        url = r['url'] as String?;
        available = r['available'] == true;
        checkError = r['error'] as String?;
      }
    } catch (e) {
      checkError = '$e';
    }
    checking = false;
    notifyListeners();
  }

  Future<void> download() async {
    if (url == null) return;
    await Native.launcher.invokeMethod('downloadUpdate', url);
    state = 'downloading';
    notifyListeners();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final p = await Native.launcher.invokeMethod<Map>('updateProgress');
      if (p == null) return;
      state = '${p['state']}';
      downloaded = (p['downloaded'] as num?)?.toInt() ?? 0;
      size = (p['size'] as num?)?.toInt() ?? 0;
      error = '${p['error'] ?? ''}';
      notifyListeners();
      if (state == 'ready' || state == 'error') {
        _poll?.cancel();
        if (state == 'ready') install();
      }
    });
  }

  /// Abre el instalador de Android (la primera vez puede pedir permiso para instalar apps).
  Future<bool> install() async => (await Native.launcher.invokeMethod('installUpdate')) == true;

  @override
  void dispose() {
    _poll?.cancel();
    _periodic?.cancel();
    super.dispose();
  }
}
