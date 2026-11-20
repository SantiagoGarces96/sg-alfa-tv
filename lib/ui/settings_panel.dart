/*
 * SG Alfa Home — panel de ajustes (lateral, estilo profesional).
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import '../core/native.dart';
import '../core/device_model.dart';
import '../core/theme_model.dart';
import 'mascot.dart';
import 'update_dialog.dart';
import '../core/update_model.dart';
import '../core/widgets_model.dart';
import 'automations_screen.dart';
import 'home_widgets.dart';
import 'pro.dart';

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
          ChangeNotifierProvider.value(value: context.read<UpdateModel>()),
          ChangeNotifierProvider.value(value: context.read<TodayModel>()),
          ChangeNotifierProvider.value(value: context.read<WidgetsModel>()),
        ],
        child: _Panel(initialPage: page),
      ),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 1.03, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );

class _Panel extends StatefulWidget {
  final String? initialPage;

  const _Panel({this.initialPage});

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  // La navegación del panel se crea UNA vez: si se recreara en cada redibujado (p. ej. al
  // previsualizar un tema), el panel volvería solo a la primera página.
  final nav = GlobalKey<NavigatorState>();

  String? get initialPage => widget.initialPage;

  @override
  Widget build(BuildContext context) {
    // Pantalla completa, como los ajustes de Apple TV: icono grande a la izquierda y lista a la derecha.
    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(color: Pro.bg.withValues(alpha: 0.97)),
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

/// Página de ajustes al estilo Apple TV: título arriba al centro, icono grande a la izquierda
/// y la lista de opciones a la derecha.
class _Page extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Page({required this.title, required this.children});

  static IconData _iconFor(String t) {
    final l = t.toLowerCase();
    if (l.contains('protec')) return Icons.shield_outlined;
    if (l.contains('mi tema')) return Icons.brush_outlined;
    if (l.contains('tema')) return Icons.palette_outlined;
    if (l.contains('fondo')) return Icons.wallpaper_outlined;
    if (l.contains('imágenes')) return Icons.photo_library_outlined;
    if (l.contains('ocult')) return Icons.visibility_off_outlined;
    if (l.contains('acerca')) return Icons.info_outline;
    return Icons.settings_outlined;
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 34, bottom: 18),
          child: Text(_titleCase(title), style: Pro.title(30)),
        ),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Icon(_iconFor(title), size: 210, color: Pro.sub.withValues(alpha: 0.55)),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 6, 56, 40),
                children: children,
              ),
            ),
          ]),
        ),
      ]);
}

/// «AJUSTES» → «Ajustes» (los títulos de página no van en mayúsculas).
String _titleCase(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1).toLowerCase();

/// Fila de opción: icono en cuadrito de color, título, subtítulo gris y lo que haga falta a la derecha.
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
  Widget build(BuildContext context) {
    // Valores cortos («Mi tema 1», «Activado») van a la derecha, como en Apple TV;
    // las explicaciones largas, debajo del título.
    final short = subtitle != null && subtitle!.length <= 26;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ProButton(
        autofocus: autofocus,
        plain: true,
        onPressed: onTap,
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Builder(builder: (context) {
          final fg = DefaultTextStyle.of(context).style.color ?? Pro.text;
          final dim = fg.withValues(alpha: 0.6);
          return Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: fg)),
                if (subtitle != null && !short) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: TextStyle(fontSize: 14, color: dim)),
                ],
              ]),
            ),
            if (short) ...[
              const SizedBox(width: 12),
              Text(subtitle!, style: TextStyle(fontSize: 17, color: dim)),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 10),
              IconTheme.merge(data: IconThemeData(color: dim), child: trailing!),
            ],
          ]);
        }),
      ),
    );
  }
}

/// Interruptor de los ajustes (estilo móvil).
class RetroSwitch extends StatelessWidget {
  final bool value;

  const RetroSwitch(this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final fg = DefaultTextStyle.of(context).style.color ?? Pro.text;
    return Text(value ? 'Activado' : 'Desactivado', style: TextStyle(fontSize: 17, color: fg.withValues(alpha: 0.6)));
  }
}

// ---------------------------------------------------------------- páginas

class _MainPage extends StatelessWidget {
  const _MainPage();

  @override
  Widget build(BuildContext context) {
    final today = context.watch<TodayModel>();
    final wd = context.watch<WidgetsModel>();
    return _Page(title: 'AJUSTES', children: [
      _Row(
        icon: Icons.wb_cloudy_outlined,
        title: 'Ciudad del clima',
        subtitle: wd.city.isEmpty ? 'Sin elegir' : wd.city,
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final c = TextEditingController(text: wd.city);
          final r = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Pro.card,
              title: Text('Ciudad del clima', style: Pro.title(24)),
              content: TextField(
                controller: c,
                autofocus: true,
                style: TextStyle(color: Pro.text, fontSize: 20),
                decoration: const InputDecoration(hintText: 'Por ejemplo: Bogotá, Medellín, Cali…'),
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
              ),
              actions: [
                ProButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
                ProButton(color: Pro.accent, onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Guardar')),
              ],
            ),
          );
          if (r != null && r.trim().isNotEmpty) wd.setCity(r);
        },
      ),
      _Row(
        icon: Icons.music_note_outlined,
        title: 'Mostrar lo que suena',
        subtitle: wd.media['access'] == true ? 'Permitido' : 'Pide permiso a Android',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => wd.openMediaAccess(),
      ),
      _Row(
        autofocus: true,
        icon: Icons.shield,
        title: 'Protección SG Alfa',
        subtitle: today.adblock ? 'Bloqueo de anuncios activo' : 'Anuncios, pop-ups y automatizaciones',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(_route(const _ProtectionPage())),
      ),
      _Row(
        icon: Icons.wallpaper,
        title: 'Fondo de pantalla',
        subtitle: _wallpaperName(context.watch<ThemeModel>()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(_route(const _WallpaperPage())),
      ),
      _Row(
        icon: Icons.palette,
        title: 'Temas',
        subtitle: context.watch<ThemeModel>().auto
            ? 'Automático (día / noche)'
            : 'Ahora: ${context.watch<ThemeModel>().current.name}',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(_route(const _ThemesPage())),
      ),
      _Row(
        icon: Icons.visibility_off,
        title: 'Apps ocultas',
        subtitle: '${context.watch<AppsModel>().hiddenApps.length} ocultas',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(_route(const _HiddenPage())),
      ),
      _Row(
        icon: Icons.dialpad,
        title: 'Números del control',
        subtitle: 'En el inicio, cada número abre una app',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(_route(const _NumbersPage())),
      ),
      _Row(
        icon: Icons.settings,
        title: context.watch<DeviceModel>().isTv ? 'Ajustes de la tele' : 'Ajustes del deco',
        onTap: Native.openSystemSettings,
      ),
      _Row(
        icon: Icons.info_outline,
        title: 'Acerca de SG Alfa Home',
        subtitle: context.watch<UpdateModel>().available ? '¡Hay una versión nueva!' : null,
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
      if (t.spotify)
        _Row(
          icon: Icons.music_note,
          title: 'Anuncios de Spotify',
          subtitle: '${t.spotifyAds} ${t.spotifyAds == 1 ? 'bloqueado' : 'bloqueados'} hoy · los de audio se silencian solos',
          onTap: () => context.read<TodayModel>().refresh(),
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
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await SgAutomationsScreen.open(context);
          if (context.mounted) context.read<TodayModel>().refresh();
        },
      ),
      _Row(
        icon: Icons.cleaning_services,
        title: 'Limpieza semanal de caché',
        subtitle: t.cleanWeekly
            ? 'Los ${_dayName(t.cleanWeekday)}, Alfi borra la caché de todas las apps'
            : 'Apagada',
        trailing: RetroSwitch(t.cleanWeekly),
        onTap: () async {
          await Native.protection.invokeMethod('setWeeklyClean', {'enabled': !t.cleanWeekly, 'weekday': t.cleanWeekday});
          await t.refresh();
        },
      ),
      if (t.cleanWeekly)
        _Row(
          icon: Icons.event,
          title: 'Día de limpieza: ${_dayName(t.cleanWeekday)}',
          subtitle: 'OK para cambiar',
          onTap: () async {
            final next = t.cleanWeekday % 7 + 1; // 1 = domingo … 7 = sábado
            await Native.protection.invokeMethod('setWeeklyClean', {'enabled': true, 'weekday': next});
            await t.refresh();
          },
        ),
      _Row(
        icon: Icons.auto_delete,
        title: 'Limpiar la caché ahora',
        subtitle: t.cleanLast.isNotEmpty ? 'Última vez: ${t.cleanLast}' : 'Necesita el servicio de automatizaciones',
        onTap: () async {
          final ok = await Native.protection.invokeMethod('cleanNow');
          if (ok != true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Activa primero el servicio de automatizaciones (arriba).')));
          }
        },
      ),
      _Row(
        icon: Icons.smart_toy,
        title: 'Alfi aparece al actuar',
        subtitle: 'Sale un momento en la esquina cuando cierra un aviso o limpia',
        trailing: RetroSwitch(t.alfiToasts),
        onTap: () async {
          await Native.protection.invokeMethod('setAlfiToasts', !t.alfiToasts);
          await t.refresh();
        },
      ),
      const SizedBox(height: 10),
      Text(
        'Si usas otra VPN (AdGuard, Blokada…), apágala antes: solo puede haber una a la vez.',
        style: Pro.body(14, color: Pro.text.withValues(alpha: 0.85), weight: FontWeight.w500),
      ),
    ]);
  }
}

/// Qué app abre cada número del control (en el inicio).
class _NumbersPage extends StatelessWidget {
  const _NumbersPage();

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppsModel>();
    const digits = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
    return _Page(title: 'NÚMEROS DEL CONTROL', children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('Pulsa un número del control en el inicio y se abre su app. Sin elegir, sigue el orden del dock.',
            style: Pro.body(15, color: Pro.sub)),
      ),
      for (var i = 0; i < digits.length; i++)
        _Row(
          autofocus: i == 0,
          icon: Icons.dialpad,
          title: 'Número ${digits[i]}',
          subtitle: apps.appForDigit(digits[i])?.label ?? 'Sin app',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(_route(_PickAppPage(digit: digits[i]))),
        ),
    ]);
  }
}

class _PickAppPage extends StatelessWidget {
  final int digit;

  const _PickAppPage({required this.digit});

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppsModel>();
    final list = [...apps.favorites, ...apps.others];
    final current = apps.numberKeys['$digit'];
    return _Page(title: 'NÚMERO $digit', children: [
      _Row(
        autofocus: true,
        icon: Icons.auto_awesome,
        title: 'Automático (orden del dock)',
        subtitle: current == null ? 'Elegido' : null,
        onTap: () {
          apps.setNumberKey(digit, null);
          Navigator.of(context).pop();
        },
      ),
      for (final a in list)
        _Row(
          icon: Icons.apps,
          title: a.label,
          subtitle: current == a.package ? 'Elegido' : null,
          onTap: () {
            apps.setNumberKey(digit, a.package);
            Navigator.of(context).pop();
          },
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
            style: Pro.body(16, weight: FontWeight.w500)),
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
            decoration: Pro.box(color: Pro.text, radius: 18, shadow: 5),
            child: Image.asset('assets/helmet.png'),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SG Alfa Home', style: Pro.title(28)),
              const SizedBox(height: 8),
              ProTag('VERSIÓN ${context.watch<UpdateModel>().current}', color: Pro.accent),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Text(
          'Tu pantalla de inicio retro con bloqueo de anuncios, cierre de pop-ups, '
          'automatizaciones y sugerencias según tus hábitos.',
          style: Pro.body(17, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text('github.com/SantiagoGarces96', style: Pro.body(15, color: Pro.accent)),
        const SizedBox(height: 20),
        _Row(
          autofocus: true,
          icon: Icons.system_update_alt,
          title: context.watch<UpdateModel>().available
              ? '¡Actualizar a la ${context.watch<UpdateModel>().latest}!'
              : 'Buscar actualizaciones',
          subtitle: 'Tienes la ${context.watch<UpdateModel>().current}',
          onTap: () {
            final u = context.read<UpdateModel>();
            if (!u.available) u.check();
            showUpdateDialog(context);
          },
        ),
        _Row(
          icon: Icons.description_outlined,
          title: 'Licencias de componentes',
          subtitle: 'Flutter, tipografía Bungee y librerías usadas',
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'SG Alfa Home',
            applicationVersion: context.read<UpdateModel>().current,
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
        child: ProButton(
          autofocus: autofocus,
          color: selected ? Pro.accent : Pro.card,
          focusColor: Pro.accent,
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
        decoration: Pro.box(color: Pro.accent, radius: 12, shadow: 4),
        child: Row(children: [
          const AlfiSprite(size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Sugerencia: «${suggested.name}». ${SgThemes.suggestionReason(now)}.',
                style: TextStyle(color: Pro.on(Pro.accent), fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ]),
      ),
      for (var i = 0; i < SgThemes.presets.length; i++) themeRow(SgThemes.presets[i], autofocus: i == 0),
      if (m.custom.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('MIS TEMAS', style: Pro.title(16)),
        const SizedBox(height: 10),
        for (final t in m.custom)
          Row(children: [
            Expanded(child: themeRow(t)),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: ProButton(
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
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(_route(_ThemeEditor(
          base: m.current.copyWith(
            id: 'mio-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Mi tema ${m.custom.length + 1}',
            custom: true,
          ),
        ))),
      ),
      const SizedBox(height: 6),
      Text('AUTOMÁTICO', style: Pro.title(16)),
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
          decoration: Pro.box(color: Pro.bg, shadow: 6),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: Pro.title(18)),
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
          decoration: Pro.box(color: Pro.text, shadow: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: c,
              autofocus: true,
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
              style: TextStyle(color: Pro.on(Pro.text), fontSize: 20, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Nombre del tema'),
            ),
            const SizedBox(height: 10),
            ProButton(color: Pro.accent, onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Listo')),
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
          decoration: BoxDecoration(color: c, border: Border.all(color: Pro.line, width: 1), borderRadius: BorderRadius.circular(6)),
        ),
        onTap: () => _pickColor(label, c, set),
      );

  Widget _stepper(String label, double value, double step, double min, double max, ValueChanged<double> set) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(label, style: Pro.body(16, weight: FontWeight.w800))),
          ProButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            onPressed: value > min ? () => set((value - step).clamp(min, max)) : null,
            child: const Text('−', style: TextStyle(fontSize: 20)),
          ),
          SizedBox(
            width: 56,
            child: Text(value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                textAlign: TextAlign.center, style: Pro.title(18)),
          ),
          ProButton(
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
        trailing: const Icon(Icons.sync),
        onTap: next,
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    const sizes = {'s': 'Pequeñas (7 por fila)', 'm': 'Medianas (6 por fila)', 'l': 'Grandes (5 por fila)'};
    const docks = {'fila': 'Sin fondo', 'crema': 'Crema', 'oscuro': 'Oscuro', 'cristal': 'Cristal', 'oculto': 'Sin dock'};
    const clocks = {'grande': 'Grande', 'mediano': 'Mediano', 'pequeno': 'Pequeño', 'oculto': 'Oculto'};
    const focuses = {
      'aro': 'Borde blanco con brillo',
      'escala': 'Crece con sombra (Apple TV)',
      'borde': 'Aro de color (Android)',
      'brillo': 'Brillo de color',
      'comic': 'Cómic con contorno',
    };
    const spacings = {'compacto': 'Compacto', 'normal': 'Normal', 'amplio': 'Amplio'};
    const weights = {'ligera': 'Fina', 'normal': 'Normal', 'gruesa': 'Gruesa'};
    return _Page(title: 'MI TEMA', children: [
      Text('Los cambios se ven al momento en toda la pantalla.',
          style: Pro.body(14, color: Pro.text.withValues(alpha: 0.85), weight: FontWeight.w500)),
      const SizedBox(height: 12),
      _Row(icon: Icons.badge, title: 'Nombre', subtitle: t.name, onTap: _rename, autofocus: true),
      const SizedBox(height: 6),
      Text('COLORES', style: Pro.title(16)),
      const SizedBox(height: 10),
      _colorRow('Fondo de paneles', t.night, (c) => _set(t.copyWith(night: c))),
      _colorRow('Tarjetas', t.panel, (c) => _set(t.copyWith(panel: c))),
      _colorRow('Texto', t.cream, (c) => _set(t.copyWith(cream: c))),
      _colorRow('Acento', t.primary, (c) => _set(t.copyWith(primary: c))),
      _colorRow('Foco del mando', t.secondary, (c) => _set(t.copyWith(secondary: c))),
      _colorRow('Color extra', t.tertiary, (c) => _set(t.copyWith(tertiary: c))),
      _colorRow('Contorno y sombras', t.ink, (c) => _set(t.copyWith(ink: c))),
      const SizedBox(height: 6),
      Text('FORMA', style: Pro.title(16)),
      const SizedBox(height: 10),
      _stepper('Contorno', t.border, 0.5, 0, 6, (v) => _set(t.copyWith(border: v))),
      _stepper('Sombra', t.shadow, 1, 0, 10, (v) => _set(t.copyWith(shadow: v))),
      _stepper('Esquinas', t.radius, 2, 0, 24, (v) => _set(t.copyWith(radius: v))),
      _option(Icons.text_fields, 'Letra de títulos', SgFonts.label(t.font),
          () => _set(t.copyWith(font: _cycle(SgFonts.all, t.font)))),
      _option(Icons.format_bold, 'Grosor de la letra', weights[t.weight] ?? 'Gruesa',
          () => _set(t.copyWith(weight: _cycle(weights.keys.toList(), t.weight)))),
      _Row(icon: Icons.title, title: 'Títulos en MAYÚSCULAS', trailing: RetroSwitch(t.caps),
          onTap: () => _set(t.copyWith(caps: !t.caps))),
      const SizedBox(height: 6),
      Text('ESTILO', style: Pro.title(16)),
      const SizedBox(height: 10),
      _option(Icons.center_focus_strong, 'Al enfocar una app', focuses[t.focus] ?? 'Cómic con contorno',
          () => _set(t.copyWith(focus: _cycle(focuses.keys.toList(), t.focus)))),
      _option(
          Icons.view_carousel,
          'Disposición del inicio',
          switch (t.layout) {
            'tablero' => 'Tablero (hora, clima, música y Continuar viendo)',
            'escaparate' => 'Escaparate (imagen grande, como Apple TV)',
            _ => 'Clásica (hora grande y paneles)',
          },
          () => _set(t.copyWith(
              layout: switch (t.layout) { 'clasico' => 'tablero', 'tablero' => 'escaparate', _ => 'clasico' }))),
      _option(Icons.space_bar, 'Espacio entre apps', spacings[t.spacing] ?? 'Normal',
          () => _set(t.copyWith(spacing: _cycle(spacings.keys.toList(), t.spacing)))),
      _stepper('Oscurecer el fondo', t.veil * 10, 1, 0, 10, (v) => _set(t.copyWith(veil: v / 10))),
      _Row(icon: Icons.waving_hand, title: 'Saludo sobre la hora', trailing: RetroSwitch(t.greeting),
          onTap: () => _set(t.copyWith(greeting: !t.greeting))),
      _Row(icon: Icons.shield_moon, title: 'Logo SG Alfa arriba', trailing: RetroSwitch(t.brand),
          onTap: () => _set(t.copyWith(brand: !t.brand))),
      _Row(icon: Icons.help_outline, title: 'Ayuda al enfocar', subtitle: 'Nombre grande y «OK para abrir»',
          trailing: RetroSwitch(t.hint), onTap: () => _set(t.copyWith(hint: !t.hint))),
      _Row(icon: Icons.short_text, title: 'Nombre bajo la app enfocada', subtitle: 'Como en Apple TV',
          trailing: RetroSwitch(t.focusName), onTap: () => _set(t.copyWith(focusName: !t.focusName))),
      const SizedBox(height: 6),
      Text('INICIO', style: Pro.title(16)),
      const SizedBox(height: 10),
      _Row(
        icon: Icons.wallpaper,
        title: 'Fondo de pantalla',
        subtitle: t.wallpaper.startsWith('file:') ? 'Una foto tuya' : (SgThemes.wallpapers[t.wallpaper] ?? t.wallpaper),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Para ver el fondo del tema hay que quitar el fondo general, si había uno.
          if (_model.wallpaperOverride.isNotEmpty) _model.setWallpaperOverride('');
          Navigator.of(context).push(_route(_WallpaperPage(
            current: t.wallpaper,
            onSelect: (id) => _set(_t.copyWith(wallpaper: id)),
          )));
        },
      ),
      _option(Icons.grid_view, 'Tamaño de las apps', sizes[t.tileSize]!,
          () => _set(t.copyWith(tileSize: _cycle(sizes.keys.toList(), t.tileSize)))),
      _option(Icons.dock, 'Dock de favoritas', docks[t.dock] ?? 'Crema',
          () => _set(t.copyWith(dock: _cycle(docks.keys.toList(), t.dock)))),
      _option(Icons.schedule, 'Reloj', clocks[t.clock] ?? 'Grande',
          () => _set(t.copyWith(clock: _cycle(clocks.keys.toList(), t.clock)))),
      _Row(icon: Icons.subtitles, title: 'Nombres bajo las apps', trailing: RetroSwitch(t.names),
          onTap: () => _set(t.copyWith(names: !t.names))),
      _Row(icon: Icons.insights, title: 'Tarjeta TU TELE HOY', trailing: RetroSwitch(t.today),
          onTap: () => _set(t.copyWith(today: !t.today))),
      _Row(icon: Icons.smart_toy, title: 'Alfi, la mascota 8-bit', subtitle: 'Te saluda, avisa y sugiere',
          trailing: RetroSwitch(t.mascot), onTap: () => _set(t.copyWith(mascot: !t.mascot))),
      const SizedBox(height: 10),
      Row(children: [
        ProButton(
          color: Pro.accent,
          onPressed: () async {
            _saved = true;
            await _model.saveCustom(_t);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Row(children: [Icon(Icons.save), SizedBox(width: 6), Text('Guardar')]),
        ),
        ProButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        if (widget.base.custom && context.read<ThemeModel>().custom.any((c) => c.id == widget.base.id))
          ProButton(
            color: Pro.sub,
            onPressed: () async {
              _saved = true;
              await _model.deleteCustom(widget.base.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Borrar'),
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
              color: _f ? Pro.accent : (widget.selected ? Pro.text : Pro.text),
              width: _f ? 5 : 2.5,
            ),
          ),
          child: widget.selected ? Icon(Icons.check, color: Pro.on(widget.color)) : null,
        ),
      );
}

String _dayName(int calendarDay) => const {
      1: 'domingos',
      2: 'lunes',
      3: 'martes',
      4: 'miércoles',
      5: 'jueves',
      6: 'viernes',
      7: 'sábados',
    }[calendarDay] ??
    'lunes';

// ---------------------------------------------------------------- fondo de pantalla

String _wallpaperName(ThemeModel m) {
  final o = m.wallpaperOverride;
  final w = m.current.wallpaper;
  if (o.isEmpty) return 'El del tema (${w.startsWith('file:') ? 'una foto tuya' : SgThemes.wallpapers[w] ?? w})';
  if (o.startsWith('file:')) return 'Tu imagen';
  return SgThemes.wallpapers[o] ?? o;
}

/// Elige fondo. Sin [onSelect] es el fondo general (vale para TODOS los temas);
/// con [onSelect] es el fondo propio de un tema (desde el editor).
class _WallpaperPage extends StatefulWidget {
  final String? current;
  final ValueChanged<String>? onSelect;

  const _WallpaperPage({this.current, this.onSelect});

  @override
  State<_WallpaperPage> createState() => _WallpaperPageState();
}

class _WallpaperPageState extends State<_WallpaperPage> {
  String? _picked;

  bool get _forTheme => widget.onSelect != null;

  void _choose(ThemeModel m, String id) {
    if (_forTheme) {
      setState(() => _picked = id);
      widget.onSelect!(id);
    } else {
      m.setWallpaperOverride(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ThemeModel>();
    final current = _forTheme ? (_picked ?? widget.current ?? '') : m.wallpaperOverride;
    final fileNow = current.startsWith('file:');

    Widget preview(String id) {
      if (id.isEmpty) id = m.current.wallpaper;
      if (id.startsWith('file:')) {
        final file = File(id.substring(5));
        if (file.existsSync()) return Image.file(file, fit: BoxFit.cover, cacheWidth: 256);
        return const SizedBox();
      }
      final asset = SgThemes.wallpaperAsset(id);
      if (asset != null) return Image.asset(asset, fit: BoxFit.cover, cacheWidth: 256);
      // 'tema': degradado con los colores del tema.
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [m.current.night, m.current.primary.withValues(alpha: 0.6)]),
        ),
      );
    }

    Widget choice(String id, String name) {
      final selected = current == id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ProButton(
          color: selected ? Pro.accent : Pro.card,
          focusColor: Pro.accent,
          padding: const EdgeInsets.all(8),
          onPressed: () => _choose(m, id),
          child: Row(children: [
            Container(
              width: 128,
              height: 72,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(border: Border.all(color: Pro.line, width: 1), color: m.current.night),
              child: preview(id),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            if (selected) const Icon(Icons.check_circle, size: 26),
          ]),
        ),
      );
    }

    return _Page(title: _forTheme ? 'FONDO DEL TEMA' : 'FONDO', children: [
      Text(
        _forTheme
            ? 'Este fondo será parte de tu tema. Se ve al momento.'
            : 'Este fondo se usa con TODOS los temas. Elige «El del tema» para que cada tema use el suyo.',
        style: Pro.body(14, color: Pro.text.withValues(alpha: 0.85), weight: FontWeight.w500),
      ),
      const SizedBox(height: 12),
      _Row(
        autofocus: true,
        icon: Icons.photo_library,
        title: 'Mis imágenes',
        subtitle: fileNow ? 'Ahora mismo: una foto tuya' : 'Fotos guardadas en el deco o en un USB',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(_route(_GalleryPage(onPicked: (id) => _choose(m, id)))),
      ),
      const SizedBox(height: 6),
      if (fileNow) choice(current, 'Tu foto'),
      if (!_forTheme) choice('', 'El del tema'),
      for (final e in SgThemes.wallpapers.entries)
        if (_forTheme || e.key != 'tema') choice(e.key, e.value),
    ]);
  }
}

/// Galería de tus imágenes: elige una con el mando y queda de fondo.
class _GalleryPage extends StatefulWidget {
  final ValueChanged<String> onPicked;

  const _GalleryPage({required this.onPicked});

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> with WidgetsBindingObserver {
  bool? _allowed;
  List<Map> _images = const [];
  bool _loading = true;
  String? _applying;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver del aviso de permiso de Android, vuelve a mirar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final ok = await Native.launcher.invokeMethod('imagesPermission') == true;
    List<Map> imgs = const [];
    if (ok) {
      final r = await Native.launcher.invokeMethod<List>('listImages');
      imgs = (r ?? const []).whereType<Map>().toList();
    }
    if (!mounted) return;
    setState(() {
      _allowed = ok;
      _images = imgs;
      _loading = false;
    });
  }

  Future<void> _apply(String uri) async {
    setState(() => _applying = uri);
    final path = await Native.launcher.invokeMethod<String>('applyImage', uri);
    if (!mounted) return;
    setState(() => _applying = null);
    if (path != null) {
      widget.onPicked('file:$path');
      // Vuelve a «Fondo», que ya dice «Ahora mismo tienes una imagen tuya».
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _Page(title: 'MIS IMÁGENES', children: [Text('Buscando fotos…', style: Pro.body(16))]);
    if (_allowed != true) {
      return _Page(title: 'MIS IMÁGENES', children: [
        Text('Para ver tus fotos, Android pide permiso una vez. Pulsa el botón y acepta en el aviso.',
            style: Pro.body(15)),
        const SizedBox(height: 12),
        _Row(
          autofocus: true,
          icon: Icons.lock_open,
          title: 'Dar permiso para ver mis fotos',
          onTap: () => Native.launcher.invokeMethod('requestImagesPermission'),
        ),
      ]);
    }
    return _Page(title: 'MIS IMÁGENES', children: [
      if (_images.isEmpty)
        Text(
          'No encontré fotos. Descarga alguna (con Downloader o el gestor de archivos) o conecta un USB, '
          'y vuelve aquí.',
          style: Pro.body(15),
        ),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < _images.length; i++)
          _Thumb(
            uri: '${_images[i]['uri']}',
            name: '${_images[i]['name']}',
            usb: _images[i]['usb'] == true,
            autofocus: i == 0,
            busy: _applying == _images[i]['uri'],
            onTap: () => _apply('${_images[i]['uri']}'),
          ),
      ]),
    ]);
  }
}

class _Thumb extends StatefulWidget {
  final String uri;
  final String name;
  final bool usb;
  final bool autofocus;
  final bool busy;
  final VoidCallback onTap;

  const _Thumb({
    required this.uri,
    required this.name,
    required this.usb,
    required this.autofocus,
    required this.busy,
    required this.onTap,
  });

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  bool _f = false;
  late final Future<Uint8List?> _img = Native.launcher.invokeMethod<Uint8List>('imageThumb', widget.uri);

  @override
  Widget build(BuildContext context) => InkWell(
        autofocus: widget.autofocus,
        onTap: widget.onTap,
        onFocusChange: (f) {
          setState(() => _f = f);
          if (f) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 160));
        },
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 140,
          height: 79,
          decoration: BoxDecoration(
            color: Pro.card,
            border: Border.all(color: _f ? Pro.accent : Pro.text, width: _f ? 4 : 2.5),
          ),
          child: Stack(fit: StackFit.expand, children: [
            FutureBuilder<Uint8List?>(
              future: _img,
              builder: (_, s) => s.data == null
                  ? Center(child: Text(widget.name, maxLines: 2, style: Pro.body(10)))
                  : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true),
            ),
            if (widget.usb)
              Positioned(right: 2, top: 2, child: ProTag('USB', color: Pro.accent)),
            if (widget.busy) const Center(child: CircularProgressIndicator()),
          ]),
        ),
      );
}
