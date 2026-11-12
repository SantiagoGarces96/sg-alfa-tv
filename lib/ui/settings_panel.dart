/*
 * SG Alfa Home — panel de ajustes (lateral, estilo cómic).
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import '../core/native.dart';
import '../core/settings_model.dart';
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
          ChangeNotifierProvider.value(value: context.read<SettingsModel>()),
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
        decoration: const BoxDecoration(
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
          color: const Color(0xFF3B3150),
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
                  Text(subtitle!, style: Retro.body(14, color: const Color(0xFFE6DFCF), weight: FontWeight.w500)),
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
          color: value ? const Color(0xFF8FD694) : const Color(0xFFB9B4A8),
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
        trailing: const Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () => Navigator.of(context).push(_route(const _ProtectionPage())),
      ),
      _Row(
        icon: Icons.wallpaper,
        title: 'Fondo de pantalla',
        subtitle: context.watch<SettingsModel>().wallpaper.name,
        trailing: const Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () => Navigator.of(context).push(_route(const _WallpaperPage())),
      ),
      _Row(
        icon: Icons.dashboard_customize,
        title: 'Pantalla de inicio',
        subtitle: 'Qué se muestra en el inicio',
        trailing: const Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () => Navigator.of(context).push(_route(const _HomePage())),
      ),
      _Row(
        icon: Icons.visibility_off,
        title: 'Apps ocultas',
        subtitle: '${context.watch<AppsModel>().hiddenApps.length} ocultas',
        trailing: const Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () => Navigator.of(context).push(_route(const _HiddenPage())),
      ),
      _Row(icon: Icons.settings, title: 'Ajustes de la tele', onTap: Native.openSystemSettings),
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
        trailing: const Icon(Icons.chevron_right, color: Retro.cream),
        onTap: () async {
          await SgAutomationsScreen.open(context);
          if (context.mounted) context.read<TodayModel>().refresh();
        },
      ),
      const SizedBox(height: 10),
      Text(
        'Si usas otra VPN (AdGuard, Blokada…), apágala antes: solo puede haber una a la vez.',
        style: Retro.body(14, color: const Color(0xFFE6DFCF), weight: FontWeight.w500),
      ),
    ]);
  }
}

class _WallpaperPage extends StatelessWidget {
  const _WallpaperPage();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsModel>();
    return _Page(title: 'FONDO', children: [
      for (final w in SettingsModel.wallpapers)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RetroButton(
            autofocus: w.id == s.wallpaper.id,
            color: w.id == s.wallpaper.id ? Retro.mustard : const Color(0xFF3B3150),
            focusColor: Retro.red,
            padding: const EdgeInsets.all(8),
            onPressed: () => s.setWallpaper(w.id),
            child: Row(children: [
              Container(
                width: 160,
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(color: Retro.ink, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.asset(w.asset, fit: BoxFit.cover, cacheWidth: 320),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(w.name, style: Retro.body(18, weight: FontWeight.w800))),
              if (w.id == s.wallpaper.id) const Icon(Icons.check_circle, size: 28),
            ]),
          ),
        ),
    ]);
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsModel>();
    return _Page(title: 'INICIO', children: [
      _Row(
        autofocus: true,
        icon: Icons.insights,
        title: 'Tarjeta «TU TELE HOY»',
        subtitle: 'Anuncios bloqueados, avisos cerrados y sugerencia',
        trailing: RetroSwitch(s.showToday),
        onTap: () => s.setShowToday(!s.showToday),
      ),
      _Row(
        icon: Icons.subtitles,
        title: 'Nombres bajo las apps',
        subtitle: 'En la lista de todas las apps',
        trailing: RetroSwitch(s.showNames),
        onTap: () => s.setShowNames(!s.showNames),
      ),
      const SizedBox(height: 10),
      Text(
        'Para ordenar el dock: mantén OK sobre una app → Mover a la izquierda / derecha.',
        style: Retro.body(14, color: const Color(0xFFE6DFCF), weight: FontWeight.w500),
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
              const RetroSticker('VERSIÓN 2.0', color: Retro.mustard, textColor: Retro.ink),
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
