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

### Alfi, la mascota 8-bit
Un pequeño espartano pixelado (personaje original de SG Alfa) que vive en el inicio y habla contigo:
- Te da el resumen del día: anuncios bloqueados, avisos cerrados y tiempo de tele.
- **Registra lo que ves**: tiempo por app hoy y esta semana.
- **Aprende tus costumbres**: qué sueles ver por la mañana, tarde, noche y madrugada, y te lo sugiere.
- **Ayuda con la limpieza**: mide la caché de cada app y te lleva a borrarla; avisa de las apps olvidadas.
- Sabe si está en un **televisor o en un deco** y adapta lo que dice y los accesos (entradas HDMI e imagen
  en un televisor; espacio libre en un deco).
Todo se calcula en la propia tele con el registro de uso de Android; no se envía nada fuera.

### Temas
- **Sugeridos**: Cómic, Hacker, Gamer, Formal, Pastel y 8-bit (con Alfi). La app sugiere uno según la hora.
- **Automático**: un tema de día y otro de noche que cambian solos.
- **Crea el tuyo**: colores, contorno, sombra, esquinas, tipografía, fondo, tamaño de las apps, estilo del
  dock, reloj, nombres y mascota, con vista previa en directo. Guarda todos los que quieras.

### Protección SG Alfa
- **Bloqueo de anuncios y pop-ups** para toda la tele, sin root: una VPN local que solo filtra el DNS
  (AdGuard DNS + lista propia). El resto del tráfico no pasa por ella.
- **Automatizaciones estilo MacroDroid**, con editor en la propia tele:
  **CUANDO** aparece un botón o un texto · **SOLO SI** también se ve otro texto o estás en cierta app ·
  **ENTONCES** pulsar ese botón, Atrás o Inicio (con espera opcional).
  Incluye plantillas para «¿Sigues viendo?», «Continuar usando», «Saltar anuncio» y pop-ups de publicidad.

### Ajustes
Protección, temas (con 6 fondos propios), apps ocultas y acceso a los ajustes de la tele o del deco.

---

## Instalar

- **Desde el teléfono**, con la app [SG Alfa (tv-debloater)](https://github.com/SantiagoGarces96/tv-debloater):
  botón «Poner la pantalla de inicio SG Alfa».
- **Con Downloader** en la tele: `https://github.com/SantiagoGarces96/sg-alfa-tv/releases/latest/download/sg-alfa-home.apk`
- **Se actualiza sola**: cuando hay versión nueva, Alfi avisa con el botón «ACTUALIZAR» (también en Ajustes → Acerca de).

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

Código © 2026 SG Alfa. Componentes de terceros: Flutter y sus librerías (BSD/MIT) y las tipografías **Bungee** y
**Press Start 2P** (SIL Open Font License, ver `assets/fonts/`). La lista completa está en la app:
Ajustes → Acerca de → Licencias de componentes.
