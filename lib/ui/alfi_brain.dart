/*
 * SG Alfa Home — el «cerebro» de Alfi: junta lo que sabe de la tele, decide qué es
 * más importante decir ahora y propone una acción para cada consejo.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/alfi_model.dart';
import '../core/apps_model.dart';
import '../core/device_model.dart';
import '../core/native.dart';
import 'automations_screen.dart';
import 'home_widgets.dart';

class AlfiTip {
  final String text;
  final int priority; // más alto = más importante
  final String? actionLabel;
  final IconData? actionIcon;
  final void Function(BuildContext context)? action;

  const AlfiTip(this.text, this.priority, {this.actionLabel, this.actionIcon, this.action});
}

String _slotNow(DateTime t) {
  final h = t.hour;
  if (h >= 6 && h < 12) return 'mañana';
  if (h >= 12 && h < 19) return 'tarde';
  if (h >= 19) return 'noche';
  return 'madrugada';
}

bool _weekend(DateTime t) => t.weekday == DateTime.saturday || t.weekday == DateTime.sunday;

/// Todo lo que Alfi podría decir ahora, de más a menos importante.
List<AlfiTip> alfiTips(BuildContext context, {required VoidCallback openReport}) {
  final now = DateTime.now();
  final t = context.read<TodayModel>();
  final d = context.read<DeviceModel>();
  final a = context.read<AlfiModel>();
  final apps = context.read<AppsModel>();
  final your = d.your;
  final h = now.hour;
  final tips = <AlfiTip>[];

  final hello = h >= 6 && h < 12 ? '¡Buenos días!' : (h >= 12 && h < 19 ? '¡Buenas tardes!' : '¡Buenas noches!');
  tips.add(AlfiTip('$hello Soy Alfi y cuido de $your.', 1000));

  // --- Anuncios: lo que ha visto y lo que se coló.
  final byApp = a.adsByAppToday;
  if (byApp.isNotEmpty) {
    final top = byApp.first;
    tips.add(AlfiTip(
      'He visto ${top.value} anuncio${top.value == 1 ? '' : 's'} en ${top.key} hoy. Lo tengo apuntado: ¿creamos un cierre automático?',
      95,
      actionLabel: 'VER',
      actionIcon: Icons.visibility,
      action: (_) => openReport(),
    ));
  }
  final leaked = a.leakedDomains;
  if (leaked.isNotEmpty) {
    tips.add(AlfiTip(
      'Se ${leaked.length == 1 ? 'coló 1 dominio' : 'colaron ${leaked.length} dominios'} de anuncios. ¿Los bloqueo?',
      90,
      actionLabel: 'BLOQUEAR',
      actionIcon: Icons.block,
      action: (_) => a.blockAllLeaked(),
    ));
  }
  if (!t.adblock) {
    tips.add(AlfiTip(
      'El bloqueo de anuncios está apagado. Si lo enciendo, quito anuncios y pop-ups de todas las apps.',
      80,
      actionLabel: 'ENCENDER',
      actionIcon: Icons.shield,
      action: (_) async {
        await Native.protection.invokeMethod('setAdblock', true);
        await Future.delayed(const Duration(milliseconds: 800));
        await t.refresh();
      },
    ));
  } else if (t.ads > 0) {
    tips.add(AlfiTip('Hoy he bloqueado ${t.ads} anuncios. ¡Ni uno se me escapa!', 45));
  }
  if (t.automation && t.actions > 0) tips.add(AlfiTip('He cerrado ${t.actions} avisos por ti hoy.', 40));

  // --- Limpieza semanal y automatizaciones recomendadas.
  if (t.cleanLast.isNotEmpty) tips.add(AlfiTip('En la última limpieza automática: ${t.cleanLast}', 36));
  if (!t.cleanWeekly && a.cacheTotalMb > 200) {
    tips.add(AlfiTip(
      'Si quieres, cada lunes borro yo la caché de todas tus apps. Se activa en Ajustes → Protección.',
      48,
    ));
  }
  if (t.missingTemplates > 0) {
    tips.add(AlfiTip(
      'Tengo ${t.missingTemplates} automatizaciones nuevas recomendadas: saltar intros, resúmenes, «¿sigues ahí?»…',
      52,
      actionLabel: 'VER',
      actionIcon: Icons.bolt,
      action: (ctx) => SgAutomationsScreen.open(ctx),
    ));
  }

  // --- Espacio y limpieza.
  if (!d.isTv && d.lowStorage) {
    tips.add(AlfiTip(
      'A $your le queda poco espacio (${d.freeGb!.toStringAsFixed(1)} GB). Te ayudo a limpiar.',
      88,
      actionLabel: 'LIMPIAR',
      actionIcon: Icons.cleaning_services,
      action: (_) => openReport(),
    ));
  }
  if (a.cacheTotalMb > 300) {
    final big = a.cache.isNotEmpty ? ' ${a.cache.first.name} es la que más guarda.' : '';
    tips.add(AlfiTip(
      'Hay ${AlfiModel.size(a.cacheTotalMb)} de caché acumulada.$big',
      50,
      actionLabel: 'LIMPIAR',
      actionIcon: Icons.cleaning_services,
      action: (_) => openReport(),
    ));
  }

  // --- Lo que ves y lo que ha aprendido.
  final last = a.last;
  if (last != null && a.lastMinutesAgo >= 2 && a.lastMinutesAgo < 90) {
    tips.add(AlfiTip(
      'Hace ${a.lastMinutesAgo} min estabas en ${last.name}. ¿Sigues?',
      78,
      actionLabel: 'SEGUIR',
      actionIcon: Icons.play_arrow_rounded,
      action: (_) => Native.launch(last.package),
    ));
  }
  final slot = _slotNow(now);
  final weekendHabit = _weekend(now) ? a.slots['${slot}_finde'] : null;
  final habit = weekendHabit ?? a.slots[slot];
  if (habit != null) {
    final when = weekendHabit != null ? 'Los fines de semana por la $slot' : 'Por la $slot';
    tips.add(AlfiTip(
      '$when sueles ver ${habit.name}. Lo he aprendido de tus últimas semanas.',
      70,
      actionLabel: 'ABRIR',
      actionIcon: Icons.play_arrow_rounded,
      action: (_) => Native.launch(habit.package),
    ));
  }
  if (a.todayMinutes > 180) {
    tips.add(AlfiTip('Llevas ${AlfiModel.duration(a.todayMinutes)} de tele hoy. ¿Una pausa para estirar las piernas?', 65));
  } else if (a.todayMinutes > 0 && a.yesterdayMinutes > 0) {
    final more = a.todayMinutes > a.yesterdayMinutes;
    tips.add(AlfiTip(
      'Hoy llevas ${AlfiModel.duration(a.todayMinutes)}; ayer viste ${AlfiModel.duration(a.yesterdayMinutes)}'
      '${more ? '. ¡Hoy vas ganando!' : '.'}',
      35,
    ));
  }
  for (final n in a.newApps) {
    if (apps.isFavorite(n.package)) continue;
    tips.add(AlfiTip(
      'Has instalado ${n.name} hace poco. ¿La pongo en el dock?',
      60,
      actionLabel: 'AL DOCK',
      actionIcon: Icons.star,
      action: (_) => apps.toggleFavorite(n.package),
    ));
    break;
  }
  if (a.week.isNotEmpty && !apps.isFavorite(a.week.first.package)) {
    final top = a.week.first;
    tips.add(AlfiTip(
      '${top.name} es tu app de la semana (${AlfiModel.duration(top.value.toInt())}) y no está en el dock.',
      55,
      actionLabel: 'AL DOCK',
      actionIcon: Icons.star,
      action: (_) => apps.toggleFavorite(top.package),
    ));
  }
  if (a.forgotten.isNotEmpty) {
    final f = a.forgotten.first;
    tips.add(AlfiTip(
      'No abres ${f.name} desde hace semanas. ¿La oculto para que no estorbe?',
      30,
      actionLabel: 'OCULTAR',
      actionIcon: Icons.visibility_off,
      action: (_) => apps.setHidden(f.package, true),
    ));
  }

  // --- Consejos según el aparato y la hora.
  if (d.isTv) tips.add(const AlfiTip('Para cambiar a HDMI o a la antena, usa el botón de entradas de arriba.', 15));
  if (h >= 23 || h < 5) tips.add(const AlfiTip('Es tarde… ¿el último capítulo y a dormir?', 62));
  if (apps.favorites.isEmpty) {
    tips.add(const AlfiTip('Tu dock está vacío. Mantén OK sobre una app para añadirla.', 58));
  }
  tips.add(const AlfiTip('Puedes cambiar mi mundo en Ajustes → Temas.', 5));

  tips.sort((x, y) => y.priority.compareTo(x.priority));
  return tips;
}
