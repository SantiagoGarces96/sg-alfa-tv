/*
 * SG Alfa Home — panel de ajustes (lateral, estilo cómic).
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import '../core/native.dart';
import '../core/device_model.dart';
import '../core/theme_model.dart';
import 'mascot.dart';
import 'automations_screen.dart';
import 'home_widgets.dart';
import 'retro.dart';

Future<void> showSettingsPanel(BuildContext context, {String? page}) => showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Ajustes',
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<AppsModel>()),
          ChangeNotifierProvider.value(value: context.read<ThemeModel>()),
          ChangeNotifierProvider.value(value: context.read<DeviceModel>()),
          ChangeNotifierProvider.value(value: context.read<TodayModel>()),
        ],
        child: _Panel(initialPage: page),
      ),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

class _Panel extends StatelessWidget {
  final String? initialPage;

  const _Panel({this.initialPage});

  @override
  Widget build(BuildContext context) {
    final nav = GlobalKey<NavigatorState>();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 520,
        height: double.infinity,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        decoration: BoxDecoration(
          color: Retro.night,
          border: Border(right: BorderSide(color: Retro.ink, width: 5)),
          boxShadow: [BoxShadow(color: Retro.ink, offset: Offset(8, 0))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              if (nav.currentState?.canPop() ?? false) {
                nav.currentState!.pop();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Navigator(
              key: nav,
              onGenerateInitialRoutes: (_, __) => [
                _route(const _MainPage()),
                if (initialPage == 'protection') _route(const _ProtectionPage()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route _route(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 160),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    );

/// Página del panel: título retro + lista de opciones.
class _Page extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Page({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 34, 34, 40),
        children: [
          Text(title, style: Retro.title(30)),
          const SizedBox(height: 22),
          ...children,
        ],
      );
}

/// Fila de opción: chapita con icono, título, subtítulo y lo que haga falta a la derecha.
class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool autofocus;

  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RetroButton(
          autofocus: autofocus,
          color: Retro.panel,
          focusColor: Retro.red,
          onPressed: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: Retro.box(color: Retro.mustard, radius: 10, border: 2.5, shadow: 2),
              child: Icon(icon, size: 22, color: Retro.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Retro.body(18, weight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!, style: Retro.body(14, color: Retro.cream.withValues(alpha: 0.85), weight: FontWeight.w500)),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ]),
        ),
      );
}

/// Interruptor retro (cápsula con contorno de tinta).
class RetroSwitch extends StatelessWidget {
  final bool value;

  const RetroSwitch(this.value, {super.key});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 58,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? Retro.positive : Retro.muted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Retro.ink, width: 2.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Retro.cream,
              shape: BoxShape.circle,
              border: Border.all(color: Retro.ink, width: 2),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------- páginas

class _MainPage extends StatelessWidget {
  const _MainPage();

  @override
  Widget build(BuildContext context) {
    final today = context.watch<TodayModel>();
    return _Page(title: 'AJUSTES', children: [
      _Row(
        autofocus: true,
        icon: Icons.shield,
        title: 'Protección SG Alfa',
        subtitle: today.adblock ? 'Bloqueo de anuncios activo' : 'Anuncios, pop-ups y automatizaciones',
        trailing: Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () => Navigator.of(context).push(_route(const _ProtectionPage())),
      ),
      _Row(
        icon: Icons.palette,
        title: 'Temas',
        subtitle: context.watch<ThemeModel>().auto
            ? 'Automático (día / noche)'
            : 'Ahora: ${context.watch<ThemeModel>().current.name}',
        trailing: Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () => Navigator.of(context).push(_route(const _ThemesPage())),
      ),
      _Row(
        icon: Icons.visibility_off,
        title: 'Apps ocultas',
        subtitle: '${context.watch<AppsModel>().hiddenApps.length} ocultas',
        trailing: Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () => Navigator.of(context).push(_route(const _HiddenPage())),
      ),
      _Row(
        icon: Icons.settings,
        title: context.watch<DeviceModel>().isTv ? 'Ajustes de la tele' : 'Ajustes del deco',
        onTap: Native.openSystemSettings,
      ),
      _Row(
        icon: Icons.info_outline,
        title: 'Acerca de SG Alfa Home',
        onTap: () => Navigator.of(context).push(_route(const _AboutPage())),
      ),
    ]);
  }
}

class _ProtectionPage extends StatefulWidget {
  const _ProtectionPage();

  @override
  State<_ProtectionPage> createState() => _ProtectionPageState();
}

class _ProtectionPageState extends State<_ProtectionPage> {
  bool _busy = false;

  Future<void> _setAdblock(bool on) async {
    setState(() => _busy = true);
    try {
      await Native.protection.invokeMethod('setAdblock', on);
      await Future.delayed(const Duration(milliseconds: 700));
    } catch (_) {}
    if (mounted) await context.read<TodayModel>().refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TodayModel>();
    return _Page(title: 'PROTECCIÓN', children: [
      _Row(
        autofocus: true,
        icon: Icons.shield,
        title: 'Bloquear anuncios',
        subtitle: t.adblock
            ? 'Activo · ${t.ads} bloqueados hoy'
            : 'Filtra anuncios y pop-ups en todas las apps (sin root)',
        trailing: _busy ? const SizedBox(width: 58, child: LinearProgressIndicator()) : RetroSwitch(t.adblock),
        onTap: _busy ? null : () => _setAdblock(!t.adblock),
      ),
      _Row(
        icon: Icons.smart_button,
        title: 'Servicio de automatizaciones',
        subtitle: t.automation
            ? 'Activado · ${t.actions} avisos cerrados hoy'
            : 'Apagado · pulsa y activa «SG Alfa · Automatizaciones»',
        trailing: RetroSwitch(t.automation),
        onTap: () => Native.protection.invokeMethod('openAccessibilitySettings'),
      ),
      _Row(
        icon: Icons.edit_note,
        title: 'Crear y editar automatizaciones',
        subtitle: 'CUANDO / SOLO SI / ENTONCES',
        trailing: Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () async {
          await SgAutomationsScreen.open(context);
          if (context.mounted) context.read<TodayModel>().refresh();
        },
      ),
      const SizedBox(height: 10),
      Text(
        'Si usas otra VPN (AdGuard, Blokada…), apágala antes: solo puede haber una a la vez.',
        style: Retro.body(14, color: Retro.cream.withValues(alpha: 0.85), weight: FontWeight.w500),
      ),
    ]);
  }
}

class _HiddenPage extends StatelessWidget {
  const _HiddenPage();

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppsModel>();
    final hidden = apps.hiddenApps;
    return _Page(title: 'OCULTAS', children: [
      if (hidden.isEmpty)
        Text('No hay apps ocultas. Para ocultar una: mantén OK sobre ella → Ocultar.',
            style: Retro.body(16, weight: FontWeight.w500)),
      for (var i = 0; i < hidden.length; i++)
        _Row(
          autofocus: i == 0,
          icon: Icons.visibility,
          title: hidden[i].label,
          subtitle: 'Pulsa para volver a mostrarla',
          onTap: () => apps.setHidden(hidden[i].package, false),
        ),
    ]);
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) => _Page(title: 'ACERCA DE', children: [
        Row(children: [
          Container(
            width: 90,
            height: 90,
            padding: const EdgeInsets.all(6),
            decoration: Retro.box(color: Retro.cream, radius: 18, shadow: 5),
            child: Image.asset('assets/helmet.png'),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SG ALFA HOME', style: Retro.title(28)),
              const SizedBox(height: 8),
              RetroSticker('VERSIÓN 2.0', color: Retro.mustard, textColor: Retro.ink),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Text(
          'Tu pantalla de inicio retro con bloqueo de anuncios, cierre de pop-ups, '
          'automatizaciones y sugerencias según tus hábitos.',
          style: Retro.body(17, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text('github.com/SantiagoGarces96', style: Retro.body(15, color: Retro.mustard)),
        const SizedBox(height: 20),
        _Row(
          autofocus: true,
          icon: Icons.description_outlined,
          title: 'Licencias de componentes',
          subtitle: 'Flutter, tipografía Bungee y librerías usadas',
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'SG Alfa Home',
            applicationVersion: '2.0',
          ),
        ),
      ]);
}

// ---------------------------------------------------------------- temas

/// Muestra de un tema: sus colores y su letra en pequeño.
class _ThemeSwatch extends StatelessWidget {
  final SgTheme t;

  const _ThemeSwatch(this.t);

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        height: 54,
        decoration: BoxDecoration(
          color: t.night,
          borderRadius: BorderRadius.circular(t.radius / 3),
          border: Border.all(color: t.ink, width: 2),
        ),
        padding: const EdgeInsets.all(6),
        child: Stack(children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text('Aa',
                style: TextStyle(
                  fontFamily: t.font == SgFonts.system ? null : t.font,
                  fontWeight: FontWeight.w900,
                  fontSize: t.font == SgFonts.pixel ? 11 : 16,
                  color: t.cream,
                )),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Row(children: [
              for (final c in [t.primary, t.secondary, t.tertiary])
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(color: c, border: Border.all(color: t.ink, width: 1.5)),
                ),
            ]),
          ),
          if (t.mascot) const Positioned(left: 0, bottom: 0, child: AlfiSprite(size: 22)),
        ]),
      );
}

class _ThemesPage extends StatelessWidget {
  const _ThemesPage();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ThemeModel>();
    final now = DateTime.now();
    final suggested = SgThemes.suggestedFor(now);

    Widget themeRow(SgTheme t, {bool autofocus = false}) {
      final selected = !m.auto && m.selectedId == t.id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RetroButton(
          autofocus: autofocus,
          color: selected ? Retro.mustard : Retro.panel,
          focusColor: Retro.red,
          padding: const EdgeInsets.all(8),
          onPressed: () => m.select(t.id),
          child: Row(children: [
            _ThemeSwatch(t),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                if (t.id == suggested.id) const Text('★ Sugerido para ahora', style: TextStyle(fontSize: 12)),
                if (t.custom) const Text('Tu tema', style: TextStyle(fontSize: 12)),
              ]),
            ),
            if (selected) const Icon(Icons.check_circle, size: 26),
          ]),
        ),
      );
    }

    String nameOf(String id) => m.byId(id).name;
    String nextId(String id) {
      final all = m.all;
      final i = all.indexWhere((t) => t.id == id);
      return all[(i + 1) % all.length].id;
    }

    return _Page(title: 'TEMAS', children: [
      // Sugerencia del momento.
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: Retro.box(color: Retro.teal, radius: 12, shadow: 4),
        child: Row(children: [
          const AlfiSprite(size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Sugerencia: «${suggested.name}». ${SgThemes.suggestionReason(now)}.',
                style: TextStyle(color: Retro.on(Retro.teal), fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ]),
      ),
      for (var i = 0; i < SgThemes.presets.length; i++) themeRow(SgThemes.presets[i], autofocus: i == 0),
      if (m.custom.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('MIS TEMAS', style: Retro.title(16)),
        const SizedBox(height: 10),
        for (final t in m.custom)
          Row(children: [
            Expanded(child: themeRow(t)),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: RetroButton(
                padding: const EdgeInsets.all(10),
                onPressed: () => Navigator.of(context).push(_route(_ThemeEditor(base: t))),
                child: const Icon(Icons.edit),
              ),
            ),
          ]),
      ],
      const SizedBox(height: 6),
      _Row(
        icon: Icons.add_circle,
        title: 'Crear mi tema',
        subtitle: 'Parte del tema actual y cámbialo todo',
        trailing: Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () => Navigator.of(context).push(_route(_ThemeEditor(
          base: m.current.copyWith(
            id: 'mio-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Mi tema ${m.custom.length + 1}',
            custom: true,
          ),
        ))),
      ),
      const SizedBox(height: 6),
      Text('AUTOMÁTICO', style: Retro.title(16)),
      const SizedBox(height: 10),
      _Row(
        icon: Icons.brightness_6,
        title: 'Cambiar solo según la hora',
        subtitle: 'De día (7:00–19:00) uno, de noche otro',
        trailing: RetroSwitch(m.auto),
        onTap: () => m.setAuto(!m.auto),
      ),
      if (m.auto) ...[
        _Row(
          icon: Icons.wb_sunny,
          title: 'De día: ${nameOf(m.dayId)}',
          subtitle: 'OK para cambiar',
          onTap: () => m.setAuto(true, dayId: nextId(m.dayId)),
        ),
        _Row(
          icon: Icons.nightlight_round,
          title: 'De noche: ${nameOf(m.nightId)}',
          subtitle: 'OK para cambiar',
          onTap: () => m.setAuto(true, nightId: nextId(m.nightId)),
        ),
      ],
    ]);
  }
}

/// Editor de tema con vista previa en directo: todo el inicio cambia mientras editas.
class _ThemeEditor extends StatefulWidget {
  final SgTheme base;

  const _ThemeEditor({required this.base});

  @override
  State<_ThemeEditor> createState() => _ThemeEditorState();
}

class _ThemeEditorState extends State<_ThemeEditor> {
  late SgTheme _t;
  bool _saved = false;
  late final ThemeModel _model;

  @override
  void initState() {
    super.initState();
    _t = widget.base;
    _model = context.read<ThemeModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _model.preview(_t));
  }

  @override
  void dispose() {
    if (!_saved) _model.restore();
    super.dispose();
  }

  void _set(SgTheme t) {
    setState(() => _t = t);
    _model.preview(t);
  }

  static String _cycle(List<String> opts, String v) => opts[(opts.indexOf(v) + 1) % opts.length];

  Future<void> _pickColor(String label, Color current, ValueChanged<Color> onPick) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 430,
          padding: const EdgeInsets.all(16),
          decoration: Retro.box(color: Retro.night, shadow: 6),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: Retro.title(18)),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in SgThemes.palette)
                _Swatch(
                  color: c,
                  selected: c.toARGB32() == current.toARGB32(),
                  autofocus: c.toARGB32() == current.toARGB32(),
                  onTap: () => Navigator.of(ctx).pop(c),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (picked != null) onPick(picked);
  }

  Future<void> _rename() async {
    final c = TextEditingController(text: _t.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(16),
          decoration: Retro.box(color: Retro.cream, shadow: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: c,
              autofocus: true,
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
              style: TextStyle(color: Retro.on(Retro.cream), fontSize: 20, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Nombre del tema'),
            ),
            const SizedBox(height: 10),
            RetroButton(color: Retro.teal, onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('LISTO')),
          ]),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 1), c.dispose);
    if (name != null && name.trim().isNotEmpty) _set(_t.copyWith(name: name.trim()));
  }

  Widget _colorRow(String label, Color c, ValueChanged<Color> set, {bool autofocus = false}) => _Row(
        autofocus: autofocus,
        icon: Icons.format_color_fill,
        title: label,
        trailing: Container(
          width: 46,
          height: 28,
          decoration: BoxDecoration(color: c, border: Border.all(color: Retro.ink, width: 2.5), borderRadius: BorderRadius.circular(6)),
        ),
        onTap: () => _pickColor(label, c, set),
      );

  Widget _stepper(String label, double value, double step, double min, double max, ValueChanged<double> set) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(label, style: Retro.body(16, weight: FontWeight.w800))),
          RetroButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            onPressed: value > min ? () => set((value - step).clamp(min, max)) : null,
            child: const Text('−', style: TextStyle(fontSize: 20)),
          ),
          SizedBox(
            width: 56,
            child: Text(value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                textAlign: TextAlign.center, style: Retro.title(18)),
          ),
          RetroButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            onPressed: value < max ? () => set((value + step).clamp(min, max)) : null,
            child: const Text('+', style: TextStyle(fontSize: 20)),
          ),
        ]),
      );

  Widget _option(IconData icon, String title, String value, VoidCallback next) => _Row(
        icon: icon,
        title: title,
        subtitle: value,
        trailing: Icon(Icons.sync, color: Retro.cream),
        onTap: next,
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    const sizes = {'s': 'Pequeñas (7 por fila)', 'm': 'Medianas (6 por fila)', 'l': 'Grandes (5 por fila)'};
    const docks = {'crema': 'Crema', 'oscuro': 'Oscuro', 'cristal': 'Cristal', 'oculto': 'Sin dock'};
    const clocks = {'grande': 'Grande', 'mediano': 'Mediano', 'oculto': 'Oculto'};
    return _Page(title: 'MI TEMA', children: [
      Text('Los cambios se ven al momento en toda la pantalla.',
          style: Retro.body(14, color: Retro.cream.withValues(alpha: 0.85), weight: FontWeight.w500)),
      const SizedBox(height: 12),
      _Row(icon: Icons.badge, title: 'Nombre', subtitle: t.name, onTap: _rename, autofocus: true),
      const SizedBox(height: 6),
      Text('COLORES', style: Retro.title(16)),
      const SizedBox(height: 10),
      _colorRow('Fondo de paneles', t.night, (c) => _set(t.copyWith(night: c))),
      _colorRow('Tarjetas', t.panel, (c) => _set(t.copyWith(panel: c))),
      _colorRow('Texto', t.cream, (c) => _set(t.copyWith(cream: c))),
      _colorRow('Acento', t.primary, (c) => _set(t.copyWith(primary: c))),
      _colorRow('Foco del mando', t.secondary, (c) => _set(t.copyWith(secondary: c))),
      _colorRow('Color extra', t.tertiary, (c) => _set(t.copyWith(tertiary: c))),
      _colorRow('Contorno y sombras', t.ink, (c) => _set(t.copyWith(ink: c))),
      const SizedBox(height: 6),
      Text('FORMA', style: Retro.title(16)),
      const SizedBox(height: 10),
      _stepper('Contorno', t.border, 0.5, 0, 6, (v) => _set(t.copyWith(border: v))),
      _stepper('Sombra', t.shadow, 1, 0, 10, (v) => _set(t.copyWith(shadow: v))),
      _stepper('Esquinas', t.radius, 2, 0, 24, (v) => _set(t.copyWith(radius: v))),
      _option(Icons.text_fields, 'Letra de títulos', SgFonts.label(t.font),
          () => _set(t.copyWith(font: _cycle(SgFonts.all, t.font)))),
      const SizedBox(height: 6),
      Text('INICIO', style: Retro.title(16)),
      const SizedBox(height: 10),
      _option(Icons.wallpaper, 'Fondo de pantalla', SgThemes.wallpapers[t.wallpaper] ?? t.wallpaper,
          () => _set(t.copyWith(wallpaper: _cycle(SgThemes.wallpapers.keys.toList(), t.wallpaper)))),
      _option(Icons.grid_view, 'Tamaño de las apps', sizes[t.tileSize]!,
          () => _set(t.copyWith(tileSize: _cycle(sizes.keys.toList(), t.tileSize)))),
      _option(Icons.dock, 'Dock de favoritas', docks[t.dock]!,
          () => _set(t.copyWith(dock: _cycle(docks.keys.toList(), t.dock)))),
      _option(Icons.schedule, 'Reloj', clocks[t.clock]!,
          () => _set(t.copyWith(clock: _cycle(clocks.keys.toList(), t.clock)))),
      _Row(icon: Icons.subtitles, title: 'Nombres bajo las apps', trailing: RetroSwitch(t.names),
          onTap: () => _set(t.copyWith(names: !t.names))),
      _Row(icon: Icons.insights, title: 'Tarjeta TU TELE HOY', trailing: RetroSwitch(t.today),
          onTap: () => _set(t.copyWith(today: !t.today))),
      _Row(icon: Icons.smart_toy, title: 'Alfi, la mascota 8-bit', subtitle: 'Te saluda, avisa y sugiere',
          trailing: RetroSwitch(t.mascot), onTap: () => _set(t.copyWith(mascot: !t.mascot))),
      const SizedBox(height: 10),
      Row(children: [
        RetroButton(
          color: Retro.teal,
          onPressed: () async {
            _saved = true;
            await _model.saveCustom(_t);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Row(children: [Icon(Icons.save), SizedBox(width: 6), Text('GUARDAR')]),
        ),
        RetroButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCELAR')),
        if (widget.base.custom && context.read<ThemeModel>().custom.any((c) => c.id == widget.base.id))
          RetroButton(
            color: Retro.muted,
            onPressed: () async {
              _saved = true;
              await _model.deleteCustom(widget.base.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('BORRAR'),
          ),
      ]),
    ]);
  }
}

class _Swatch extends StatefulWidget {
  final Color color;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  const _Swatch({required this.color, required this.selected, required this.autofocus, required this.onTap});

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _f = false;

  @override
  Widget build(BuildContext context) => InkWell(
        autofocus: widget.autofocus,
        onTap: widget.onTap,
        onFocusChange: (f) => setState(() => _f = f),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _f ? Retro.mustard : (widget.selected ? Retro.cream : Retro.ink),
              width: _f ? 5 : 2.5,
            ),
          ),
          child: widget.selected ? Icon(Icons.check, color: Retro.on(widget.color)) : null,
        ),
      );
}
