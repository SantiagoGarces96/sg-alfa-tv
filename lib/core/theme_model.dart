/*
 * SG Alfa Home — temas: colores, forma, letra y cómo se ve el inicio.
 * Temas sugeridos + temas propios + tema automático según la hora.
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/retro.dart';

/// Tipografías de títulos disponibles.
class SgFonts {
  static const bungee = 'Bungee';
  static const pixel = 'PressStart2P';
  static const system = 'system';
  static const mono = 'monospace';
  static const all = [bungee, pixel, system, mono];

  static String label(String f) => switch (f) {
        pixel => 'Pixel 8-bit',
        system => 'Moderna',
        mono => 'Terminal',
        _ => 'Cómic gordita',
      };
}

class SgTheme {
  final String id;
  final String name;
  final bool custom;

  // Colores
  final Color ink; // contornos y sombras
  final Color night; // fondo de paneles
  final Color panel; // tarjetas sobre el fondo
  final Color cream; // texto principal y superficies claras
  final Color primary; // acento principal (rojo en Retro)
  final Color secondary; // acento de foco (mostaza en Retro)
  final Color tertiary; // acento extra (verde azulado en Retro)

  // Forma
  final double border; // 0..6
  final double shadow; // 0..10
  final double radius; // 0..24
  final String font;

  // Inicio
  final String wallpaper; // id de fondo o 'tema' (degradado con los colores del tema)
  final String tileSize; // s | m | l
  final String dock; // crema | oscuro | cristal | oculto
  final String clock; // grande | mediano | oculto
  final bool names;
  final bool today;
  final bool mascot; // Alfi, la mascota 8-bit

  const SgTheme({
    required this.id,
    required this.name,
    this.custom = false,
    required this.ink,
    required this.night,
    required this.panel,
    required this.cream,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    this.border = 3,
    this.shadow = 5,
    this.radius = 14,
    this.font = SgFonts.bungee,
    this.wallpaper = 'noche-roja',
    this.tileSize = 'm',
    this.dock = 'crema',
    this.clock = 'grande',
    this.names = false,
    this.today = true,
    this.mascot = true,
  });

  SgTheme copyWith({
    String? id,
    String? name,
    bool? custom,
    Color? ink,
    Color? night,
    Color? panel,
    Color? cream,
    Color? primary,
    Color? secondary,
    Color? tertiary,
    double? border,
    double? shadow,
    double? radius,
    String? font,
    String? wallpaper,
    String? tileSize,
    String? dock,
    String? clock,
    bool? names,
    bool? today,
    bool? mascot,
  }) =>
      SgTheme(
        id: id ?? this.id,
        name: name ?? this.name,
        custom: custom ?? this.custom,
        ink: ink ?? this.ink,
        night: night ?? this.night,
        panel: panel ?? this.panel,
        cream: cream ?? this.cream,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        tertiary: tertiary ?? this.tertiary,
        border: border ?? this.border,
        shadow: shadow ?? this.shadow,
        radius: radius ?? this.radius,
        font: font ?? this.font,
        wallpaper: wallpaper ?? this.wallpaper,
        tileSize: tileSize ?? this.tileSize,
        dock: dock ?? this.dock,
        clock: clock ?? this.clock,
        names: names ?? this.names,
        today: today ?? this.today,
        mascot: mascot ?? this.mascot,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ink': ink.toARGB32(),
        'night': night.toARGB32(),
        'panel': panel.toARGB32(),
        'cream': cream.toARGB32(),
        'primary': primary.toARGB32(),
        'secondary': secondary.toARGB32(),
        'tertiary': tertiary.toARGB32(),
        'border': border,
        'shadow': shadow,
        'radius': radius,
        'font': font,
        'wallpaper': wallpaper,
        'tileSize': tileSize,
        'dock': dock,
        'clock': clock,
        'names': names,
        'today': today,
        'mascot': mascot,
      };

  static SgTheme fromJson(Map<String, dynamic> j) {
    final base = SgThemes.retro;
    Color c(String k, Color d) => j[k] is int ? Color(j[k] as int) : d;
    double n(String k, double d) => j[k] is num ? (j[k] as num).toDouble() : d;
    return SgTheme(
      id: '${j['id']}',
      name: '${j['name']}',
      custom: true,
      ink: c('ink', base.ink),
      night: c('night', base.night),
      panel: c('panel', base.panel),
      cream: c('cream', base.cream),
      primary: c('primary', base.primary),
      secondary: c('secondary', base.secondary),
      tertiary: c('tertiary', base.tertiary),
      border: n('border', base.border),
      shadow: n('shadow', base.shadow),
      radius: n('radius', base.radius),
      font: SgFonts.all.contains(j['font']) ? j['font'] as String : base.font,
      wallpaper: '${j['wallpaper'] ?? base.wallpaper}',
      tileSize: '${j['tileSize'] ?? base.tileSize}',
      dock: '${j['dock'] ?? base.dock}',
      clock: '${j['clock'] ?? base.clock}',
      names: j['names'] == true,
      today: j['today'] != false,
      mascot: j['mascot'] != false,
    );
  }
}

class SgThemes {
  SgThemes._();

  static const retro = SgTheme(
    id: 'retro',
    name: 'Cómic',
    ink: Color(0xFF1D1A16),
    night: Color(0xFF26203A),
    panel: Color(0xFF3B3150),
    cream: Color(0xFFFFF1D0),
    primary: Color(0xFFE63946),
    secondary: Color(0xFFFFB703),
    tertiary: Color(0xFF2A9D8F),
  );

  static const hacker = SgTheme(
    id: 'hacker',
    name: 'Hacker',
    ink: Color(0xFF000000),
    night: Color(0xFF050A06),
    panel: Color(0xFF0C1A10),
    cream: Color(0xFFB6FFC4),
    primary: Color(0xFF00C853),
    secondary: Color(0xFF39FF14),
    tertiary: Color(0xFF00BFA5),
    border: 1.5,
    shadow: 0,
    radius: 2,
    font: SgFonts.mono,
    wallpaper: 'matrix',
    dock: 'oscuro',
    tileSize: 's',
  );

  static const gamer = SgTheme(
    id: 'gamer',
    name: 'Gamer',
    ink: Color(0xFF07030F),
    night: Color(0xFF120A24),
    panel: Color(0xFF221440),
    cream: Color(0xFFF3EDFF),
    primary: Color(0xFFFF2E97),
    secondary: Color(0xFF00E5FF),
    tertiary: Color(0xFF9D4EDD),
    border: 2,
    shadow: 4,
    radius: 6,
    wallpaper: 'atardecer',
    dock: 'oscuro',
  );

  static const formal = SgTheme(
    id: 'formal',
    name: 'Formal',
    ink: Color(0xFF0A0F1A),
    night: Color(0xFF111827),
    panel: Color(0xFF1E293B),
    cream: Color(0xFFF1F5F9),
    primary: Color(0xFF1E3A8A),
    secondary: Color(0xFFD4AF37),
    tertiary: Color(0xFF64748B),
    border: 0,
    shadow: 0,
    radius: 10,
    font: SgFonts.system,
    wallpaper: 'tema',
    dock: 'cristal',
    clock: 'mediano',
    tileSize: 'l',
    mascot: false,
  );

  static const pastel = SgTheme(
    id: 'pastel',
    name: 'Pastel',
    ink: Color(0xFF3D2C4E),
    night: Color(0xFF4A3B63),
    panel: Color(0xFF5B4A78),
    cream: Color(0xFFFFF5FA),
    primary: Color(0xFFFF6F9C),
    secondary: Color(0xFFFFD3A5),
    tertiary: Color(0xFF7FCFB9),
    border: 3,
    shadow: 4,
    radius: 22,
    wallpaper: 'cielo',
  );

  static const pixel = SgTheme(
    id: 'pixel',
    name: '8-bit',
    ink: Color(0xFF000000),
    night: Color(0xFF1D2B53),
    panel: Color(0xFF29366F),
    cream: Color(0xFFFFF1E8),
    primary: Color(0xFFFF004D),
    secondary: Color(0xFFFFEC27),
    tertiary: Color(0xFF00E436),
    border: 3,
    shadow: 4,
    radius: 0,
    font: SgFonts.pixel,
    wallpaper: 'pixel',
    dock: 'oscuro',
    mascot: true,
  );

  static const presets = [retro, hacker, gamer, formal, pastel, pixel];

  /// Tema sugerido según la hora del día.
  static SgTheme suggestedFor(DateTime t) {
    final h = t.hour;
    if (h >= 6 && h < 12) return pastel;
    if (h >= 12 && h < 17) return retro;
    if (h >= 17 && h < 21) return gamer;
    if (h >= 21 || h < 2) return pixel;
    return hacker;
  }

  static String suggestionReason(DateTime t) {
    final h = t.hour;
    if (h >= 6 && h < 12) return 'Mañana tranquila: colores suaves';
    if (h >= 12 && h < 17) return 'Tarde: el clásico de SG Alfa';
    if (h >= 17 && h < 21) return 'Hora de jugar';
    if (h >= 21 || h < 2) return 'Noche retro con Alfi';
    return 'Madrugada: modo terminal';
  }

  /// Fondos disponibles. 'tema' = degradado con los colores del tema.
  static const wallpapers = <String, String>{
    'noche-roja': 'Noche roja',
    'atardecer': 'Atardecer retro',
    'arcade': 'Arcade',
    'cielo': 'Cielo de cómic',
    'matrix': 'Código verde',
    'pixel': 'Paisaje 8-bit',
    'tema': 'Degradado del tema',
  };

  static String? wallpaperAsset(String id) => id == 'tema' ? null : 'assets/wallpapers/$id.jpg';

  /// Paleta de colores para el editor (retro, neón, pastel y neutros).
  static const palette = [
    Color(0xFF000000), Color(0xFF1D1A16), Color(0xFF121212), Color(0xFF26203A),
    Color(0xFF3B3150), Color(0xFF1A0B33), Color(0xFF0E1A2B), Color(0xFF1F3A2E),
    Color(0xFFFFF1D0), Color(0xFFF2F2F2), Color(0xFFFFF5FA), Color(0xFFF5E6C8),
    Color(0xFFE63946), Color(0xFFFF004D), Color(0xFFFF2E97), Color(0xFFFF6F9C),
    Color(0xFFFFB703), Color(0xFFFFEC27), Color(0xFFE2B84A), Color(0xFFFF8A3D),
    Color(0xFF2A9D8F), Color(0xFF34C38F), Color(0xFF00E5FF), Color(0xFF29ADFF),
    Color(0xFF3D7BFF), Color(0xFF9D4EDD), Color(0xFF7FCFB9), Color(0xFF8B1E3F),
  ];
}

class ThemeModel extends ChangeNotifier {
  SgTheme _current = SgThemes.retro;
  String _selectedId = SgThemes.retro.id;
  List<SgTheme> _custom = [];
  bool _auto = false;
  String _dayId = SgThemes.retro.id;
  String _nightId = SgThemes.pixel.id;
  Timer? _timer;

  /// Se llama al cambiar el tema: el inicio se redibuja entero con los colores nuevos.
  VoidCallback? onApplied;

  SgTheme get current => _current;
  String get selectedId => _selectedId;
  List<SgTheme> get custom => List.unmodifiable(_custom);
  List<SgTheme> get all => [...SgThemes.presets, ..._custom];
  bool get auto => _auto;
  String get dayId => _dayId;
  String get nightId => _nightId;

  SgTheme byId(String id) => all.firstWhere((t) => t.id == id, orElse: () => SgThemes.retro);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      final raw = p.getString('custom_themes');
      if (raw != null) {
        _custom = (jsonDecode(raw) as List).whereType<Map>().map((m) => SgTheme.fromJson(m.cast())).toList();
      }
    } catch (_) {}
    _selectedId = p.getString('theme') ?? _selectedId;
    _auto = p.getBool('theme_auto') ?? false;
    _dayId = p.getString('theme_day') ?? _dayId;
    _nightId = p.getString('theme_night') ?? _nightId;
    _applyActive();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_auto) _applyActive();
    });
  }

  static bool isDay(DateTime t) => t.hour >= 7 && t.hour < 19;

  void _applyActive() {
    final id = _auto ? (isDay(DateTime.now()) ? _dayId : _nightId) : _selectedId;
    _apply(byId(id));
  }

  void _apply(SgTheme t) {
    final changed = !identical(t, _current);
    _current = t;
    Retro.apply(t);
    notifyListeners();
    if (changed) onApplied?.call();
  }

  /// Vista previa en directo (el editor la usa mientras cambias cosas).
  void preview(SgTheme t) => _apply(t);

  /// Vuelve al tema guardado (al salir del editor sin guardar).
  void restore() => _applyActive();

  Future<void> select(String id) async {
    _selectedId = id;
    _auto = false;
    _applyActive();
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', id);
    await p.setBool('theme_auto', false);
  }

  Future<void> setAuto(bool on, {String? dayId, String? nightId}) async {
    _auto = on;
    if (dayId != null) _dayId = dayId;
    if (nightId != null) _nightId = nightId;
    _applyActive();
    final p = await SharedPreferences.getInstance();
    await p.setBool('theme_auto', _auto);
    await p.setString('theme_day', _dayId);
    await p.setString('theme_night', _nightId);
  }

  /// Guarda (o actualiza) un tema propio y lo deja puesto.
  Future<void> saveCustom(SgTheme t) async {
    final i = _custom.indexWhere((c) => c.id == t.id);
    final saved = t.copyWith(custom: true);
    if (i >= 0) {
      _custom[i] = saved;
    } else {
      _custom.add(saved);
    }
    await _persist();
    await select(saved.id);
  }

  Future<void> deleteCustom(String id) async {
    _custom.removeWhere((c) => c.id == id);
    await _persist();
    if (_selectedId == id) await select(SgThemes.retro.id);
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('custom_themes', jsonEncode(_custom.map((t) => t.toJson()).toList()));
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
