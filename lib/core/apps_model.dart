/*
 * SG Alfa Home — apps de la tele, favoritas y orden.
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native.dart';

class TvApp {
  final String package;
  final String label;
  final bool tv;
  final bool hasBanner;

  const TvApp({required this.package, required this.label, required this.tv, this.hasBanner = false});
}

class AppsModel extends ChangeNotifier {
  static const _kFavorites = 'favorites';
  static const _kHidden = 'hidden';
  static const _kSeeded = 'favorites_seeded';

  /// Las de vídeo más usadas: si están instaladas, van al dock la primera vez.
  static const _starterFavorites = [
    'com.google.android.youtube.tv',
    'io.gh.reisxd.tizentube.cobalt',
    'com.netflix.ninja',
    'com.amazon.amazonvideo.livingroom',
    'com.disney.disneyplus',
    'com.wbd.stream',
    'com.hbo.hbonow',
    'com.spotify.tv.android',
    'com.xuper.netxxus',
    'com.xuper.wiwyxuper',
    'com.nathnetwork.xciptv',
    'com.magmaplayer',
    'com.plexapp.android',
    'org.xbmc.kodi',
    'com.mercadolibre.android.mplay_tv',
    'com.android.vending',
  ];

  List<TvApp> _all = [];
  List<String> _favorites = [];
  Set<String> _hidden = {};
  final Map<String, Uint8List?> _images = {};
  final Map<String, Future<Uint8List?>> _loading = {};
  bool loaded = false;
  StreamSubscription? _sub;

  /// Nombre de la app enfocada (se muestra en grande en el inicio).
  String? focusedLabel;

  List<TvApp> get favorites => [
        for (final p in _favorites)
          ..._all.where((a) => a.package == p && !_hidden.contains(a.package)),
      ];

  List<TvApp> get others {
    final list = _all.where((a) => !_favorites.contains(a.package) && !_hidden.contains(a.package)).toList();
    list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  List<TvApp> get hiddenApps => _all.where((a) => _hidden.contains(a.package)).toList();

  bool isFavorite(String pkg) => _favorites.contains(pkg);

  TvApp? byPackage(String pkg) {
    for (final a in _all) {
      if (a.package == pkg) return a;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites = prefs.getStringList(_kFavorites) ?? [];
    _hidden = (prefs.getStringList(_kHidden) ?? []).toSet();
    await refresh();
    if (!(prefs.getBool(_kSeeded) ?? false)) {
      final installed = _all.map((a) => a.package).toSet();
      _favorites = _starterFavorites.where(installed.contains).take(7).toList();
      await prefs.setBool(_kSeeded, true);
      await _save();
    }
    loaded = true;
    notifyListeners();
    _sub ??= Native.appChanges.receiveBroadcastStream().listen((_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final raw = await Native.listApps();
      _all = raw
          .map((m) => TvApp(
                package: '${m['package']}',
                label: '${m['label']}',
                tv: m['tv'] == true,
                hasBanner: m['hasBanner'] == true,
              ))
          .toList();
      _images.removeWhere((k, _) => !_all.any((a) => a.package == k));
      notifyListeners();
    } catch (_) {}
  }

  Future<Uint8List?> image(String pkg) {
    if (_images.containsKey(pkg)) return Future.value(_images[pkg]);
    return _loading[pkg] ??= Native.appImage(pkg).then((b) {
      _images[pkg] = b;
      _loading.remove(pkg);
      return b;
    }).catchError((_) {
      _loading.remove(pkg);
      return null;
    });
  }

  void setFocused(String? label) {
    if (focusedLabel == label) return;
    focusedLabel = label;
    notifyListeners();
  }

  Future<void> launch(TvApp app) => Native.launch(app.package);

  Future<void> toggleFavorite(String pkg) async {
    if (_favorites.contains(pkg)) {
      _favorites.remove(pkg);
    } else {
      _favorites.add(pkg);
    }
    await _save();
  }

  /// Mueve una favorita a la izquierda (-1) o a la derecha (+1).
  Future<void> moveFavorite(String pkg, int delta) async {
    final i = _favorites.indexOf(pkg);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= _favorites.length) return;
    _favorites.removeAt(i);
    _favorites.insert(j, pkg);
    await _save();
  }

  Future<void> setHidden(String pkg, bool hidden) async {
    if (hidden) {
      _hidden.add(pkg);
      _favorites.remove(pkg);
    } else {
      _hidden.remove(pkg);
    }
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavorites, _favorites);
    await prefs.setStringList(_kHidden, _hidden.toList());
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
