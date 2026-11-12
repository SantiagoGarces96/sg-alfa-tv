/*
 * SG Alfa Home — pantalla de inicio retro para Android TV.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/apps_model.dart';
import 'core/settings_model.dart';
import 'ui/home_screen.dart';
import 'ui/home_widgets.dart';
import 'ui/retro.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // La tipografía Bungee se distribuye con la licencia SIL OFL.
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL-Bungee.txt');
    yield LicenseEntryWithLineBreaks(['Bungee (tipografía)'], ofl);
  });

  final apps = AppsModel()..load();
  final settings = SettingsModel()..load();
  final today = TodayModel()..start();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: apps),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: today),
    ],
    child: const SgAlfaApp(),
  ));
}

class SgAlfaApp extends StatelessWidget {
  const SgAlfaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SG Alfa Home',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Retro.red,
            brightness: Brightness.dark,
            primary: Retro.red,
            secondary: Retro.mustard,
          ),
          scaffoldBackgroundColor: Retro.night,
          // El foco lo dibuja cada tarjeta a su estilo; nada de resaltados grises de Material.
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        // OK del mando = activar (además de Intro).
        shortcuts: {
          ...WidgetsApp.defaultShortcuts,
          const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        },
        // Lienzo fijo de 960×540 escalado a la pantalla: se ve igual en cualquier tele.
        builder: (context, child) => _TvCanvas(child: child!),
        home: const HomeScreen(),
      );
}

class _TvCanvas extends StatelessWidget {
  final Widget child;

  const _TvCanvas({required this.child});

  static const _size = Size(960, 540); // tamaño cómodo para ver desde el sofá

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ColoredBox(
      color: Retro.night,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox.fromSize(
          size: _size,
          child: MediaQuery(
            data: mq.copyWith(size: _size, textScaler: TextScaler.noScaling, padding: EdgeInsets.zero),
            child: child,
          ),
        ),
      ),
    );
  }
}
