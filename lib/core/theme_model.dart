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

  // Estilo (temas minimalistas)
  final String focus; // comic | escala (Apple TV) | borde (Android) | brillo
  final bool caps; // títulos en MAYÚSCULAS
  final double veil; // 0..1: cuánto se oscurece el fondo para leer el texto
  final String weight; // ligera | normal | gruesa (letra Moderna)
  final bool greeting; // «Buenas tardes» sobre la hora
  final bool brand; // logo SG ALFA arriba a la izquierda
  final bool hint; // nombre de la app enfocada y «OK para abrir»
  final String spacing; // compacto | normal | amplio
  final bool focusName; // nombre solo bajo la app enfocada (como Apple TV)
  final String layout; // clasico | escaparate (imagen grande arriba y franja de apps, como Apple TV)

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
    this.focus = 'comic',
    this.caps = true,
    this.veil = 1,
    this.weight = 'gruesa',
    this.greeting = true,
    this.brand = true,
    this.hint = true,
    this.spacing = 'normal',
    this.focusName = false,
    this.layout = 'clasico',
  });

  bool get showcase => layout == 'escaparate';

  /// Sin contornos ni pegatinas: estilo limpio.
  bool get clean => focus != 'comic';

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
    String? focus,
    bool? caps,
    double? veil,
    String? weight,
    bool? greeting,
    bool? brand,
    bool? hint,
    String? spacing,
    bool? focusName,
    String? layout,
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
        focus: focus ?? this.focus,
        caps: caps ?? this.caps,
        veil: veil ?? this.veil,
        weight: weight ?? this.weight,
        greeting: greeting ?? this.greeting,
        brand: brand ?? this.brand,
        hint: hint ?? this.hint,
        spacing: spacing ?? this.spacing,
        focusName: focusName ?? this.focusName,
        layout: layout ?? this.layout,
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
        'focus': focus,
        'caps': caps,
        'veil': veil,
        'weight': weight,
        'greeting': greeting,
        'brand': brand,
        'hint': hint,
        'spacing': spacing,
        'focusName': focusName,
        'layout': layout,
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
      focus: '${j['focus'] ?? base.focus}',
      caps: j['caps'] != false,
      veil: n('veil', base.veil),
      weight: '${j['weight'] ?? base.weight}',
      greeting: j['greeting'] != false,
      brand: j['brand'] != false,
      hint: j['hint'] != false,
      spacing: '${j['spacing'] ?? base.spacing}',
      focusName: j['focusName'] == true,
      layout: '${j['layout'] ?? 'clasico'}',
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
    focus: 'escala',
    caps: false,
    weight: 'normal',
    greeting: false,
    hint: false,
    focusName: true,
    spacing: 'amplio',
    veil: 0.6,
  );

  // ---------------------------------------------- minimalistas

  /// Predeterminado: sobrio, sin adornos.
  static const esencial = SgTheme(
    id: 'esencial',
    name: 'Esencial',
    ink: Color(0xFF000000),
    night: Color(0xFF121214),
    panel: Color(0xFF1F1F23),
    cream: Color(0xFFEDEDED),
    primary: Color(0xFF3D7BFF),
    secondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF8E8E93),
    border: 0,
    shadow: 0,
    radius: 12,
    font: SgFonts.system,
    wallpaper: 'solido',
    dock: 'fila',
    clock: 'mediano',
    today: false,
    mascot: false,
    focus: 'escala',
    caps: false,
    veil: 0.3,
    weight: 'ligera',
    greeting: false,
    brand: false,
    hint: false,
    spacing: 'amplio',
    focusName: true,
  );

  /// Inspirado en Apple TV: tarjetas grandes que «saltan» al enfocarlas, sombra suave, letra fina.
  static const appleTv = SgTheme(
    id: 'appletv',
    name: 'Estilo Apple TV',
    ink: Color(0xFF000000),
    night: Color(0xFF0B0B10),
    panel: Color(0xFF1C1C22),
    cream: Color(0xFFFFFFFF),
    primary: Color(0xFF2C2C3A),
    secondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF8E8E93),
    border: 0,
    shadow: 0,
    radius: 18,
    font: SgFonts.system,
    wallpaper: 'atardecer',
    dock: 'cristal',
    clock: 'pequeno',
    tileSize: 'm',
    layout: 'escaparate',
    today: false,
    mascot: false,
    focus: 'escala',
    caps: false,
    veil: 0.4,
    weight: 'normal',
    greeting: false,
    brand: false,
    hint: false,
    spacing: 'normal',
    focusName: false,
  );

  /// Android / Google TV minimalista: gris oscuro, aro blanco al enfocar, nombres siempre visibles.
  static const androidMin = SgTheme(
    id: 'androidmin',
    name: 'Android minimalista',
    ink: Color(0xFF000000),
    night: Color(0xFF202124),
    panel: Color(0xFF303134),
    cream: Color(0xFFE8EAED),
    primary: Color(0xFF8AB4F8),
    secondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF81C995),
    border: 0,
    shadow: 0,
    radius: 10,
    font: SgFonts.system,
    wallpaper: 'solido',
    dock: 'fila',
    clock: 'mediano',
    names: true,
    today: false,
    mascot: false,
    focus: 'borde',
    caps: false,
    veil: 0.2,
    weight: 'normal',
    greeting: false,
    brand: false,
    hint: false,
  );

  /// Claro: fondo blanco roto y texto oscuro.
  static const claro = SgTheme(
    id: 'claro',
    name: 'Claro',
    ink: Color(0xFF8E8E93),
    night: Color(0xFFF2F2F7),
    panel: Color(0xFFFFFFFF),
    cream: Color(0xFF1C1C1E),
    primary: Color(0xFF007AFF),
    secondary: Color(0xFF007AFF),
    tertiary: Color(0xFF8E8E93),
    border: 0,
    shadow: 0,
    radius: 14,
    font: SgFonts.system,
    wallpaper: 'solido',
    dock: 'fila',
    clock: 'mediano',
    today: false,
    mascot: false,
    focus: 'escala',
    caps: false,
    veil: 0,
    weight: 'normal',
    greeting: false,
    brand: false,
    hint: false,
    spacing: 'amplio',
    focusName: true,
  );

  /// Negro puro (ideal para pantallas OLED): nada más que las apps.
  static const negro = SgTheme(
    id: 'negro',
    name: 'Negro puro',
    ink: Color(0xFF000000),
    night: Color(0xFF000000),
    panel: Color(0xFF141414),
    cream: Color(0xFFF5F5F5),
    primary: Color(0xFF3A3A3C),
    secondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF636366),
    border: 0,
    shadow: 0,
    radius: 8,
    font: SgFonts.system,
    wallpaper: 'solido',
    dock: 'fila',
    clock: 'pequeno',
    today: false,
    mascot: false,
    focus: 'borde',
    caps: false,
    veil: 0,
    weight: 'ligera',
    greeting: false,
    brand: false,
    hint: false,
    spacing: 'normal',
    focusName: true,
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

  static const presets = [esencial, appleTv, androidMin, claro, negro, formal, retro, hacker, gamer, pastel, pixel];

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
    'solido': 'Color liso',
  };

  static String? wallpaperAsset(String id) =>
      id == 'tema' || id == 'solido' || id.startsWith('file:') || !wallpapers.containsKey(id)
          ? null
          : 'assets/wallpapers/$id.jpg';

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
  SgTheme _current = SgThemes.esencial;
  String _selectedId = SgThemes.esencial.id;
  List<SgTheme> _custom = [];
  bool _auto = false;
  String _dayId = SgThemes.retro.id;
  String _nightId = SgThemes.pixel.id;
  Timer? _timer;

  /// Fondo elegido por ti, por encima del del tema: '' = el del tema; id de fondo incluido;
  /// o 'file:<ruta>' para una imagen tuya.
  String _wallpaperOverride = '';
  String get wallpaperOverride => _wallpaperOverride;

  /// El fondo que se ve ahora mismo (id incluido o 'file:<ruta>').
  String get effectiveWallpaper => _wallpaperOverride.isNotEmpty ? _wallpaperOverride : _current.wallpaper;

  Future<void> setWallpaperOverride(String v) async {
    _wallpaperOverride = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('wallpaper_override', v);
  }

  /// Se llama al cambiar el tema: el inicio se redibuja entero con los colores nuevos.
  VoidCallback? onApplied;

  SgTheme get current => _current;
  String get selectedId => _selectedId;
  List<SgTheme> get custom => List.unmodifiable(_custom);
  List<SgTheme> get all => [...SgThemes.presets, ..._custom];
  bool get auto => _auto;
  String get dayId => _dayId;
  String get nightId => _nightId;

  SgTheme byId(String id) => all.firstWhere((t) => t.id == id, orElse: () => SgThemes.esencial);

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
    _wallpaperOverride = p.getString('wallpaper_override') ?? '';
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
    if (_selectedId == id) await select(SgThemes.esencial.id);
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
