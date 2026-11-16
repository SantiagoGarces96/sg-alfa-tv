/*
 * SG Alfa Home — datos de los widgets del inicio: clima (Open-Meteo, gratis y sin cuenta),
 * lo que está sonando y las apps vistas hace poco. Solo se actualiza con el inicio a la vista.
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native.dart';

class Weather {
  final String city;
  final int temp;
  final int max;
  final int min;
  final String desc;
  final int code;

  const Weather(this.city, this.temp, this.max, this.min, this.desc, this.code);
}

/// Códigos del tiempo de Open-Meteo (WMO) en español.
String weatherText(int c) {
  if (c == 0) return 'Despejado';
  if (c <= 2) return 'Parcialmente nublado';
  if (c == 3) return 'Nublado';
  if (c == 45 || c == 48) return 'Niebla';
  if (c >= 51 && c <= 57) return 'Llovizna';
  if (c >= 61 && c <= 67) return 'Lluvia';
  if (c >= 71 && c <= 77) return 'Nieve';
  if (c >= 80 && c <= 82) return 'Chubascos';
  if (c >= 95) return 'Tormenta';
  return 'Variable';
}

class WidgetsModel extends ChangeNotifier with WidgetsBindingObserver {
  String city = 'Bogotá';
  Weather? weather;
  Map media = const {};
  List<Map> recent = const [];

  /// Lo que se estaba viendo dentro de cada app (imagen del momento, título y progreso).
  List<Map> watching = const [];

  Timer? _fast; // lo que suena
  Timer? _slow; // apps recientes y clima
  DateTime _weatherAt = DateTime(2000);

  static bool get _visible =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    final p = await SharedPreferences.getInstance();
    city = p.getString('weather_city') ?? city;
    _refreshAll();
    _fast = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_visible) refreshMedia();
    });
    _slow = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_visible) _refreshAll();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  void _refreshAll() {
    refreshMedia();
    refreshRecent();
    if (DateTime.now().difference(_weatherAt).inMinutes >= 30) refreshWeather();
  }

  Future<void> refreshRecent() async {
    try {
      final w = await Native.widgets.invokeMethod<List>('continueWatching');
      if (w != null) {
        final list = w.whereType<Map>().toList();
        if (list.toString() != watching.toString()) {
          watching = list;
          notifyListeners();
        }
      }
    } catch (_) {}
    try {
      final r = await Native.widgets.invokeMethod<List>('recentApps');
      if (r == null) return;
      final list = r.whereType<Map>().toList();
      if (list.toString() != recent.toString()) {
        recent = list;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshMedia() async {
    try {
      final m = await Native.widgets.invokeMethod<Map>('media');
      if (m == null) return;
      // La carátula no cambia en cada consulta: comparar sin ella para no redibujar de más.
      String sig(Map x) => '${x['access']}|${x['title']}|${x['artist']}|${x['playing']}|${(x['position'] ?? 0) ~/ 1000}';
      if (sig(m) != sig(media)) {
        media = m;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> command(String c) async {
    try {
      await Native.widgets.invokeMethod('mediaCmd', c);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 400));
    refreshMedia();
  }

  Future<void> openMediaAccess() async {
    try {
      await Native.widgets.invokeMethod('openMediaAccess');
    } catch (_) {}
  }

  Future<void> setCity(String c) async {
    city = c.trim();
    weather = null;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('weather_city', city);
    _weatherAt = DateTime(2000);
    refreshWeather();
  }

  Future<Object?> _getJson(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return jsonDecode(await res.transform(utf8.decoder).join());
    } finally {
      client.close();
    }
  }

  Future<void> refreshWeather() async {
    if (city.isEmpty) return;
    try {
      final geo = await _getJson('https://geocoding-api.open-meteo.com/v1/search'
          '?name=${Uri.encodeQueryComponent(city)}&count=1&language=es&format=json');
      final results = geo is Map ? geo['results'] : null;
      if (results is! List || results.isEmpty) return;
      final g = results.first as Map;
      final f = await _getJson('https://api.open-meteo.com/v1/forecast'
          '?latitude=${g['latitude']}&longitude=${g['longitude']}'
          '&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min'
          '&timezone=auto&forecast_days=1');
      if (f is! Map) return;
      final cur = f['current'] as Map;
      final daily = f['daily'] as Map;
      final code = (cur['weather_code'] as num).toInt();
      weather = Weather(
        '${g['name']}',
        (cur['temperature_2m'] as num).round(),
        ((daily['temperature_2m_max'] as List).first as num).round(),
        ((daily['temperature_2m_min'] as List).first as num).round(),
        weatherText(code),
        code,
      );
      _weatherAt = DateTime.now();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _fast?.cancel();
    _slow?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
