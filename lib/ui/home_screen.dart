/*
 * SG Alfa Home — pantalla de inicio.
 * Arriba: marca y estado. En medio: hora, app enfocada y «TU TELE HOY».
 * Abajo: dock de favoritas y, al bajar, todas las apps.
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import '../core/native.dart';
import '../core/theme_model.dart';
import 'app_options.dart';
import 'app_tile.dart';
import 'clean_prompt.dart';
import 'dashboard.dart';
import 'first_run.dart';
import 'update_dialog.dart';
import '../core/update_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_widgets.dart';
import 'nav.dart';
import 'retro.dart';
import 'settings_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();

  static const _topBar = 56.0;
  static const _dockHeight = 110.0;

  bool _cleanPrompted = false;

  @override
  void initState() {
    super.initState();
    Native.onHomePressed(_goHome);
    context.read<TodayModel>().addListener(_maybeClean);
    // Versión nueva en GitHub: se descarga sola y se ofrece instalar (una vez por versión).
    context.read<UpdateModel>().addListener(_maybeUpdate);
    // Deco o tele nuevos: pedir de una vez los permisos (bloqueo, automatizaciones, lo que suena).
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) maybeFirstRun(context);
    });
  }

  bool _updating = false;

  /// Pop-up de versión nueva: sale al estar en el inicio y, si se deja para más tarde, recuerda cada 24 h.
  Future<void> _maybeUpdate() async {
    final u = context.read<UpdateModel>();
    if (!u.available || _updating || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _updating = true;
    try {
      final p = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final again = now - (p.getInt('update_offered_at') ?? 0) > const Duration(hours: 24).inMilliseconds;
      if (p.getString('update_offered') == u.latest && !again) return;
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      await p.setString('update_offered', u.latest);
      await p.setInt('update_offered_at', now);
      if (!mounted) return;
      await showUpdateDialog(context);
    } finally {
      _updating = false;
    }
  }

  /// El día de limpieza, la primera vez que se ve el inicio, Alfi propone limpiar.
  void _maybeClean() {
    final t = context.read<TodayModel>();
    if (!t.cleanDue || _cleanPrompted || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _cleanPrompted = true;
    showCleanPrompt(context);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Inicio estando ya en el inicio: arriba del todo y foco en la primera app.
  void _goHome() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    Nav.toDock();
  }

  void _openSettings([String? page]) => showSettingsPanel(context, page: page);

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppsModel>();
    final theme = context.watch<ThemeModel>().current;
    final size = MediaQuery.sizeOf(context);
    final favorites = apps.favorites;
    final others = apps.others;
    // Escaparate (Apple TV): la imagen ocupa ~60 % de la pantalla y la franja de apps queda abajo,
    // con la fila siguiente asomando.
    // Tablero: medidas de una pantalla de 1600×900 (u = ancho / 1600); la franja empieza en y = 660.
    final tab = theme.tablero;
    final u = size.width / 1600;
    final topH = tab ? 140 * u : _topBar;
    final heroHeight = _heroH = tab
        ? 660 * u - topH
        : theme.showcase
        ? (size.height * 0.70 - _topBar).clamp(200.0, 2000.0)
        : (size.height - _topBar - _dockHeight - 30).clamp(260.0, 2000.0);

    return PopScope(
      canPop: false,
      child: Focus(
        // Números del control: cada uno abre su app (solo aquí, en el inicio; dentro de las apps
        // los números siguen funcionando normal porque esta pantalla no recibe sus teclas).
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent) return KeyEventResult.ignored;
          final d = _digit(e.logicalKey);
          if (d == null) return KeyEventResult.ignored;
          final app = apps.appForDigit(d);
          if (app == null) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 2),
                content: Text(
                  'El número $d no tiene app. Asígnala en Ajustes → Números del control.',
                ),
              ),
            );
          } else {
            apps.launch(app);
          }
          return KeyEventResult.handled;
        },
        child: Scaffold(
          backgroundColor: Retro.night,
          body: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: _wallpaper(
                    theme,
                    context.watch<ThemeModel>().effectiveWallpaper,
                    size,
                  ),
                ),
              ),
              // Velo inferior para que el texto y las apps se lean sobre cualquier fondo.
              if (theme.veil > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.33 * theme.veil),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6 * theme.veil),
                          ],
                          stops: const [0, 0.35, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              Column(
                children: [
                  SizedBox(
                    height: topH,
                    child: tab
                        ? DashTopBar(
                            onSettings: () => _openSettings(),
                            onProtection: () => _openSettings('protection'),
                          )
                        : TopBar(
                            onSettings: () => _openSettings(),
                            onProtection: () => _openSettings('protection'),
                          ),
                  ),
                  Expanded(
                    child: !apps.loaded
                        ? Center(
                            child: Text('CARGANDO…', style: Retro.title(28)),
                          )
                        : CustomScrollView(
                            controller: _scroll,
                            slivers: [
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: heroHeight,
                                  child: tab
                                      ? ContinueHero(topBarHeight: topH)
                                      : theme.showcase
                                      ? const ShowcaseHero()
                                      : const HomeHero(),
                                ),
                              ),
                              if (theme.dock != 'oculto')
                                SliverToBoxAdapter(
                                  child: _dock(favorites, theme),
                                ),
                              if (others.isNotEmpty ||
                                  theme.dock == 'oculto') ...[
                                if (tab)
                                  SliverToBoxAdapter(
                                    child: SizedBox(height: 62 * u),
                                  )
                                else if (!theme.showcase)
                                  const SliverToBoxAdapter(
                                    child: SectionTitle('Todas las apps'),
                                  )
                                else
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 26),
                                  ),
                                SliverToBoxAdapter(
                                  child: _grid(
                                    theme.dock == 'oculto'
                                        ? [...favorites, ...others]
                                        : others,
                                    theme,
                                    favorites.isEmpty || theme.dock == 'oculto',
                                  ),
                                ),
                              ],
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 80),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _heroH = 0;

  /// Tablero: al bajar a «todas las apps», la parte de arriba desaparece entera (sin quedar cortada).
  void _gridScroll(BuildContext ctx) {
    if (!_scroll.hasClients) return;
    if (_scroll.offset < _heroH - 1) {
      _scroll.animateTo(
        _heroH,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static int? _digit(LogicalKeyboardKey k) {
    const keys = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const pad = [
      LogicalKeyboardKey.numpad0,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final i = keys.indexOf(k);
    if (i >= 0) return i;
    final j = pad.indexOf(k);
    return j >= 0 ? j : null;
  }

  /// En el dock la página se queda arriba (para ver la hora y TU TELE HOY).
  void _scrollTop(BuildContext _) {
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _tile(
    TvApp app, {
    bool first = false,
    bool inDock = false,
    required bool showNames,
    bool nameSpace = false,
  }) {
    final apps = context.read<AppsModel>();
    final tab = context.read<ThemeModel>().current.tablero;
    return AppTile(
      app: app,
      autofocus: first,
      focusNode: first ? Nav.dock : null,
      onFocusScroll: inDock ? _scrollTop : (tab ? _gridScroll : null),
      showName: showNames,
      nameSpace: nameSpace,
      onOpen: () => apps.launch(app),
      onOptions: () => showAppOptions(context, app),
    );
  }

  static int _columns(SgTheme t) => switch (t.tileSize) {
    's' => 7,
    'l' => 5,
    _ => 6,
  };

  static double _dockTile(SgTheme t) => switch (t.tileSize) {
    's' => 112,
    'l' => 150,
    _ => 130,
  };

  static double _gap(SgTheme t) => switch (t.spacing) {
    'compacto' => 14,
    'amplio' => 30,
    _ => 21,
  };

  Widget _wallpaper(SgTheme t, String id, Size size) {
    if (id == 'app') {
      return AppBackdrop(
        key: const ValueKey('app-backdrop'),
        fallback: t.night,
      );
    }
    if (id == 'solido') {
      return ColoredBox(
        key: ValueKey('solid-${t.id}'),
        color: t.night,
        child: SizedBox(width: size.width, height: size.height),
      );
    }
    if (id.startsWith('file:')) {
      final f = File(id.substring(5));
      if (f.existsSync()) {
        return Image.file(
          f,
          key: ValueKey(id),
          fit: BoxFit.cover,
          width: size.width,
          height: size.height,
        );
      }
    }
    final asset = SgThemes.wallpaperAsset(
      id.startsWith('file:') ? t.wallpaper : id,
    );
    if (asset == null) {
      return DecoratedBox(
        key: ValueKey('grad-${t.id}'),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.6, 0.9),
            radius: 1.4,
            colors: [
              Color.lerp(t.primary, t.night, 0.45)!,
              t.night,
              Color.lerp(t.night, Colors.black, 0.5)!,
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: SizedBox(width: size.width, height: size.height),
      );
    }
    return Image.asset(
      asset,
      key: ValueKey(asset),
      fit: BoxFit.cover,
      width: size.width,
      height: size.height,
      filterQuality: id == 'pixel' ? FilterQuality.none : FilterQuality.medium,
    );
  }

  Widget _dock(List<TvApp> favorites, SgTheme theme) {
    if (theme.tablero) return _tabDock(favorites);
    return Nav.arrows(
      up: Nav.aboveDock,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: _dockHeight - 16,
          decoration: theme.showcase
              ? BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                )
              : switch (theme.dock) {
                  'fila' => null,
                  'oscuro' => Retro.box(
                    color: Retro.night.withValues(alpha: 0.85),
                    radius: 22,
                    border: 4,
                    shadow: 7,
                  ),
                  'cristal' => Retro.box(
                    color: Colors.white.withValues(alpha: 0.10),
                    radius: 22,
                    border: 2,
                    shadow: 0,
                    borderColor: Retro.cream.withValues(alpha: 0.35),
                  ),
                  _ => Retro.box(
                    color: Retro.cream.withValues(alpha: 0.88),
                    radius: 22,
                    border: 4,
                    shadow: 7,
                  ),
                },
          child: favorites.isEmpty
              ? Center(
                  child: Text(
                    'Mantén OK sobre una app para añadirla aquí',
                    style: TextStyle(
                      color: theme.dock == 'crema'
                          ? Retro.on(Retro.cream)
                          : Retro.cream,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < favorites.length; i++)
                        Padding(
                          padding: EdgeInsets.only(right: _gap(theme)),
                          child: SizedBox(
                            width: _dockTile(theme),
                            height: _dockTile(theme) * 9 / 16 + 1,
                            child: _tile(
                              favorites[i],
                              first: i == 0,
                              inDock: true,
                              showNames: false,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _tabDock(List<TvApp> favorites) {
    final u = MediaQuery.sizeOf(context).width / 1600;
    return Nav.arrows(
      up: Nav.aboveDock,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 95 * u),
        child: Container(
          height: 140 * u,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(40 * u),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.5 * u,
            ),
          ),
          child: favorites.isEmpty
              ? Center(
                  child: Text(
                    'Mantén OK sobre una app para añadirla aquí',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24 * u,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.symmetric(horizontal: 31 * u),
                  child: Row(
                    children: [
                      for (var i = 0; i < favorites.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: i == favorites.length - 1 ? 0 : 34.6 * u,
                          ),
                          child: SizedBox(
                            width: 138 * u,
                            height: 77.6 * u,
                            child: _tile(
                              favorites[i],
                              first: i == 0,
                              inDock: true,
                              showNames: false,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _grid(List<TvApp> apps, SgTheme theme, bool focusFirst) {
    final showNames = theme.names;
    if (theme.tablero) {
      final u = MediaQuery.sizeOf(context).width / 1600;
      return Padding(
        padding: EdgeInsets.only(left: 126 * u, right: 126 * u),
        child: Wrap(
          spacing: 34.6 * u,
          runSpacing: 34.6 * u,
          children: [
            for (var i = 0; i < apps.length; i++)
              SizedBox(
                width: 138 * u,
                child: _tile(
                  apps[i],
                  first: focusFirst && i == 0,
                  showNames: false,
                ),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, c) {
          final gap = _gap(theme);
          final cols = _columns(theme);
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: showNames || theme.focusName ? gap + 4 : gap,
            children: [
              for (var i = 0; i < apps.length; i++)
                SizedBox(
                  width: w,
                  child: _tile(
                    apps[i],
                    first: focusFirst && i == 0,
                    showNames: showNames,
                    nameSpace: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
