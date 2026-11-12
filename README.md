# SG Alfa Home

**La pantalla de inicio retro para Android TV**, con bloqueo de anuncios, cierre automático de avisos y
sugerencias según tus hábitos. Diseño propio estilo cómic: contornos de tinta, sombras duras y colores
crema, rojo, mostaza y verde azulado.

Proyecto 100 % propio de **SG Alfa**: escrito desde cero (Flutter + Java), sin código de otros launchers.

---

## Qué tiene

### Pantalla de inicio
- **Barra superior**: marca SG Alfa, ajustes, estado de la red y la insignia de protección
  («Anuncios bloqueados» / «Sin bloqueo»).
- **Zona destacada**: saludo según la hora, la fecha, el reloj en grande y el nombre de la app enfocada.
- **TU TELE HOY**: cuántos anuncios se bloquearon hoy y cuántos avisos se cerraron solos.
- **«A esta hora sueles ver…»**: aprende qué app abres a cada hora (últimas 3 semanas) y te la propone.
  Todo se calcula dentro de la tele; no se envía nada a ningún sitio.
- **Dock de favoritas** y, al bajar, **todas las apps** con su banner de TV.
- Mantén **OK** sobre una app para: abrir, añadir/quitar del dock, moverla, ocultarla, ver su información
  o desinstalarla.

### Protección SG Alfa
- **Bloqueo de anuncios y pop-ups** para toda la tele, sin root: una VPN local que solo filtra el DNS
  (AdGuard DNS + lista propia). El resto del tráfico no pasa por ella.
- **Automatizaciones estilo MacroDroid**, con editor en la propia tele:
  **CUANDO** aparece un botón o un texto · **SOLO SI** también se ve otro texto o estás en cierta app ·
  **ENTONCES** pulsar ese botón, Atrás o Inicio (con espera opcional).
  Incluye plantillas para «¿Sigues viendo?», «Continuar usando», «Saltar anuncio» y pop-ups de publicidad.

### Ajustes
Protección, 4 fondos de pantalla propios (Noche roja, Atardecer retro, Arcade, Cielo de cómic), qué se
muestra en el inicio, apps ocultas y acceso a los ajustes de la tele.

---

## Instalar

- **Desde el teléfono**, con la app [SG Alfa (tv-debloater)](https://github.com/SantiagoGarces96/tv-debloater):
  botón «Poner la pantalla de inicio SG Alfa».
- **Con Downloader** en la tele: descarga el APK de la última versión publicada en este repositorio.

Después, para que funcionen las automatizaciones: Ajustes de SG Alfa → Protección → «Servicio de
automatizaciones» y actívalo en Accesibilidad. Para el bloqueo de anuncios, actívalo y acepta el aviso de VPN
(solo puede haber una VPN a la vez).

---

## Desarrollo

```bash
flutter pub get
flutter run -d <ip-de-la-tele>:5555
```

- Interfaz en Flutter (`lib/`): `core/` (modelos y puente nativo) y `ui/` (pantallas y estilo retro).
- Parte nativa en Java (`android/app/src/main/java/tv/sgalfa/home/`): lista de apps, bloqueo por DNS,
  servicio de automatizaciones, estadísticas del día y hábitos de uso.
- La interfaz se dibuja sobre un lienzo de 960×540 y se escala a la pantalla, así se ve igual en cualquier tele.
- Las versiones se firman siempre con la misma clave (secretos del repositorio) para poder actualizar sin
  desinstalar.

---

## Licencias

Código © 2026 SG Alfa. Componentes de terceros: Flutter y sus librerías (BSD/MIT) y la tipografía **Bungee**
(SIL Open Font License, ver `assets/fonts/OFL-Bungee.txt`). La lista completa está en la app:
Ajustes → Acerca de → Licencias de componentes.
