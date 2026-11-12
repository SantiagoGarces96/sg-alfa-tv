/*
 * SG Alfa Home — pantalla de inicio retro para Android TV.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/alfi_model.dart';
import 'core/apps_model.dart';
import 'core/device_model.dart';
import 'core/theme_model.dart';
import 'core/update_model.dart';
import 'ui/home_screen.dart';
import 'ui/home_widgets.dart';
import 'ui/retro.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Tipografías incluidas (licencia SIL OFL).
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Bungee (tipografía)'], await rootBundle.loadString('assets/fonts/OFL-Bungee.txt'));
    yield LicenseEntryWithLineBreaks(
        ['Press Start 2P (tipografía)'], await rootBundle.loadString('assets/fonts/OFL-PressStart2P.txt'));
  });

  final theme = ThemeModel()..load();
  final apps = AppsModel()..load();
  final device = DeviceModel()..load();
  final today = TodayModel()..start();
  final alfi = AlfiModel()..start();
  final updates = UpdateModel()..start();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider.value(value: apps),
      ChangeNotifierProvider.value(value: device),
      ChangeNotifierProvider.value(value: today),
      ChangeNotifierProvider.value(value: alfi),
      ChangeNotifierProvider.value(value: updates),
    ],
    child: const SgAlfaApp(),
  ));
}

class SgAlfaApp extends StatefulWidget {
  const SgAlfaApp({super.key});

  @override
  State<SgAlfaApp> createState() => _SgAlfaAppState();
}

class _SgAlfaAppState extends State<SgAlfaApp> {
  @override
  void initState() {
    super.initState();
    // Al cambiar de tema se redibuja toda la interfaz con los colores nuevos,
    // sin perder dónde estabas (paneles abiertos, foco, desplazamiento).
    context.read<ThemeModel>().onApplied = () {
      if (!mounted) return;
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    };
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeModel>();
    return MaterialApp(
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
}

class _TvCanvas extends StatelessWidget {
  final Widget child;

  const _TvCanvas({required this.child});

  static const _size = Size(960, 540);

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
