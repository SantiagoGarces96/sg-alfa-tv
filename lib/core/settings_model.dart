/*
 * SG Alfa Home — preferencias del inicio.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Wallpaper {
  final String id;
  final String name;
  final String asset;

  const Wallpaper(this.id, this.name, this.asset);
}

class SettingsModel extends ChangeNotifier {
  static const wallpapers = [
    Wallpaper('noche-roja', 'Noche roja', 'assets/wallpapers/noche-roja.jpg'),
    Wallpaper('atardecer', 'Atardecer retro', 'assets/wallpapers/atardecer.jpg'),
    Wallpaper('arcade', 'Arcade', 'assets/wallpapers/arcade.jpg'),
    Wallpaper('cielo', 'Cielo de cómic', 'assets/wallpapers/cielo.jpg'),
  ];

  String _wallpaper = wallpapers.first.id;
  bool _showToday = true;
  bool _showNames = false;

  Wallpaper get wallpaper => wallpapers.firstWhere((w) => w.id == _wallpaper, orElse: () => wallpapers.first);
  bool get showToday => _showToday;
  bool get showNames => _showNames;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _wallpaper = p.getString('wallpaper') ?? _wallpaper;
    _showToday = p.getBool('show_today') ?? true;
    _showNames = p.getBool('show_names') ?? false;
    notifyListeners();
  }

  Future<void> setWallpaper(String id) async {
    _wallpaper = id;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('wallpaper', id);
  }

  Future<void> setShowToday(bool v) async {
    _showToday = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('show_today', v);
  }

  Future<void> setShowNames(bool v) async {
    _showNames = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('show_names', v);
  }
}
