/*
 * SG Alfa Home — pantalla de inicio.
 * Arriba: marca y estado. En medio: hora, app enfocada y «TU TELE HOY».
 * Abajo: dock de favoritas y, al bajar, todas las apps.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import '../core/native.dart';
import '../core/settings_model.dart';
import 'app_options.dart';
import 'app_tile.dart';
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
  static const _columns = 6;

  @override
  void initState() {
    super.initState();
    Native.onHomePressed(_goHome);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Inicio estando ya en el inicio: arriba del todo y foco en la primera app.
  void _goHome() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    Nav.toDock();
  }

  void _openSettings([String? page]) => showSettingsPanel(context, page: page);

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppsModel>();
    final settings = context.watch<SettingsModel>();
    final size = MediaQuery.sizeOf(context);
    final favorites = apps.favorites;
    final others = apps.others;
    final heroHeight = (size.height - _topBar - _dockHeight - 30).clamp(260.0, 2000.0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Retro.night,
        body: Stack(children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Image.asset(
                settings.wallpaper.asset,
                key: ValueKey(settings.wallpaper.id),
                fit: BoxFit.cover,
                width: size.width,
                height: size.height,
              ),
            ),
          ),
          // Velo inferior para que el texto y las apps se lean sobre cualquier fondo.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x55000000), Color(0x00000000), Color(0x99000000)],
                    stops: [0, 0.35, 1],
                  ),
                ),
              ),
            ),
          ),
          Column(children: [
            SizedBox(
              height: _topBar,
              child: TopBar(
                onSettings: () => _openSettings(),
                onProtection: () => _openSettings('protection'),
              ),
            ),
            Expanded(
              child: !apps.loaded
                  ? Center(child: Text('CARGANDO…', style: Retro.title(28)))
                  : CustomScrollView(
                      controller: _scroll,
                      slivers: [
                        SliverToBoxAdapter(child: SizedBox(height: heroHeight, child: const HomeHero())),
                        SliverToBoxAdapter(child: _dock(favorites, settings.showNames)),
                        if (others.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SectionTitle('TODAS LAS APPS')),
                          SliverToBoxAdapter(child: _grid(others, settings.showNames, favorites.isEmpty)),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
            ),
          ]),
        ]),
      ),
    );
  }

  /// En el dock la página se queda arriba (para ver la hora y TU TELE HOY).
  void _scrollTop(BuildContext _) {
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    }
  }

  Widget _tile(TvApp app, {bool first = false, bool inDock = false, required bool showNames}) {
    final apps = context.read<AppsModel>();
    return AppTile(
      app: app,
      autofocus: first,
      focusNode: first ? Nav.dock : null,
      onFocusScroll: inDock ? _scrollTop : null,
      showName: showNames,
      onOpen: () => apps.launch(app),
      onOptions: () => showAppOptions(context, app),
    );
  }

  Widget _dock(List<TvApp> favorites, bool showNames) {
    return Nav.arrows(
      up: Nav.aboveDock,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: _dockHeight - 16,
        decoration: Retro.box(color: Retro.cream.withValues(alpha: 0.88), radius: 22, border: 4, shadow: 7),
        child: favorites.isEmpty
            ? Center(
                child: Text('Mantén OK sobre una app para añadirla aquí',
                    style: TextStyle(color: Retro.ink, fontSize: 20, fontWeight: FontWeight.w700)),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  for (var i = 0; i < favorites.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 21),
                      child: SizedBox(
                        width: 130,
                        height: 74,
                        child: _tile(favorites[i], first: i == 0, inDock: true, showNames: false),
                      ),
                    ),
                ]),
              ),
      ),
    ),
    );
  }

  Widget _grid(List<TvApp> apps, bool showNames, bool focusFirst) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(builder: (context, c) {
        const gap = 21.0;
        final w = (c.maxWidth - gap * (_columns - 1)) / _columns;
        return Wrap(
          spacing: gap,
          runSpacing: showNames ? 22 : gap,
          children: [
            for (var i = 0; i < apps.length; i++)
              SizedBox(width: w, child: _tile(apps[i], first: focusFirst && i == 0, showNames: showNames)),
          ],
        );
      }),
    );
  }
}
