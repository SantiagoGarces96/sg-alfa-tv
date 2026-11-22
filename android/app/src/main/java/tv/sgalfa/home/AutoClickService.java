/*
 * SG Alfa Home — automatizaciones y cierre de pop-ups.
 */
package tv.sgalfa.home;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Estilo MacroDroid: CUANDO aparece un botón o un texto, SOLO SI se cumplen las condiciones,
 * ENTONCES pulsa ese botón, Atrás o Inicio. No guarda ni envía nada de lo que ve en pantalla.
 * Solo funciona en apps que muestran su interfaz de forma accesible.
 */
public class AutoClickService extends AccessibilityService {

    static final String PREFS = "autoclick";
    static final String KEY_MACROS = "macros";
    private static final int MAX_DEPTH = 40;
    private static final int MAX_NODES = 350;

    /** El servicio activo (para lanzar la limpieza desde la pantalla de inicio). */
    static volatile AutoClickService instance;
    CacheCleaner cleaner;

    private volatile List<Macros.Macro> macros = new ArrayList<>();
    private final Map<String, Long> lastRun = new HashMap<>();
    private final Set<String> pending = new HashSet<>();
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final SharedPreferences.OnSharedPreferenceChangeListener listener = (p, k) -> loadMacros();

    /** ¿Está activado el servicio en Accesibilidad? */
    public static boolean isEnabled(Context c) {
        String list = Settings.Secure.getString(c.getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if (list == null) return false;
        // Android puede guardarlo con el nombre completo o abreviado («paquete/.AutoClickService»).
        return list.contains(c.getPackageName() + "/" + AutoClickService.class.getName())
                || list.contains(c.getPackageName() + "/." + AutoClickService.class.getSimpleName());
    }

    static List<Macros.Macro> load(Context c) {
        String json = c.getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_MACROS, null);
        List<Macros.Macro> list = Macros.decodeOrNull(json);
        if (list == null) return new ArrayList<>(Macros.templates());
        // Una sola vez: añadir el reintento automático de «sin conexión al encender» a quien ya tenía su lista.
        SharedPreferences p = c.getSharedPreferences(PREFS, MODE_PRIVATE);
        if (!p.getBoolean("upd2_added", false)) {
            // Una vez: añadir las reglas nuevas de «ignorar actualización».
            java.util.Set<String> have0 = new java.util.HashSet<>();
            for (Macros.Macro m : list) have0.add(m.id);
            for (Macros.Macro m : Macros.templates()) {
                if (m.id.startsWith("tpl-upd-") && !have0.contains(m.id)) list.add(m);
            }
            p.edit().putString(KEY_MACROS, Macros.encode(list)).putBoolean("upd2_added", true).apply();
        }
        if (!p.getBoolean("retry_added", false)) {
            java.util.Set<String> have = new java.util.HashSet<>();
            for (Macros.Macro m : list) have.add(m.id);
            for (Macros.Macro m : Macros.templates()) {
                if ((m.id.equals("tpl-retry") || m.id.equals("tpl-reintentar")) && !have.contains(m.id)) list.add(m);
            }
            p.edit().putString(KEY_MACROS, Macros.encode(list)).putBoolean("retry_added", true).apply();
        }
        return list;
    }

    static void save(Context c, List<Macros.Macro> list) {
        c.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_MACROS, Macros.encode(list)).apply();
    }

    private SharedPreferences prefs() {
        return getSharedPreferences(PREFS, MODE_PRIVATE);
    }

    private void loadMacros() {
        macros = load(this);
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        instance = this;
        ProTools.installCrashLog(this);
        cleaner = new CacheCleaner(this);
        loadMacros();
        prefs().registerOnSharedPreferenceChangeListener(listener);
        // Vigilante: si el bloqueador de anuncios se apagó solo, se vuelve a encender.
        handler.removeCallbacks(watchdog);
        handler.postDelayed(watchdog, 5_000);
        handler.removeCallbacks(watchTick);
        handler.postDelayed(watchTick, WATCH_TICK_MS);
    }

    static final long WATCH_TICK_MS = 30_000;

    /** Cada 30 s: si suena un capítulo de WiwyXuper/Hydra, se suma al tiempo visto de ese capítulo. */
    private final Runnable watchTick = new Runnable() {
        @Override
        public void run() {
            try {
                android.view.accessibility.AccessibilityNodeInfo root = getRootInActiveWindow();
                CharSequence pkg = root != null ? root.getPackageName() : null;
                if (pkg != null) ContinueWatch.tick(AutoClickService.this, pkg.toString(), WATCH_TICK_MS);
            } catch (Exception ignored) {
            }
            handler.postDelayed(this, WATCH_TICK_MS);
        }
    };

    private final Runnable watchdog = new Runnable() {
        @Override
        public void run() {
            DnsBlockVpnService.ensure(AutoClickService.this);
            handler.postDelayed(this, 60_000);
        }
    };

    // ---------------------------------------------------------------- anuncios a pantalla completa

    /** Pantallas de anuncios de las redes más comunes (Unity, ironSource, AppLovin, Google…). */
    private static final String[] AD_SCREENS = {
            "com.unity3d.ads.", "com.unity3d.services.ads.", "com.ironsource.", "com.applovin.adview.",
            "com.applovin.impl.adview.", "com.applovin.mediation.", "com.vungle.", "com.mbridge.msdk.",
            "com.bytedance.sdk.openadsdk.", "com.fyber.", "com.inmobi.ads.", "com.inmobi.media.",
            "com.chartboost.sdk.", "com.moloco.sdk.", "com.yandex.mobile.ads.", "com.facebook.ads.",
            "com.google.android.gms.ads.AdActivity", "com.adcolony.", "com.startapp.", "io.bidmachine."};
    private static final String[] CLOSE_WORDS = {
            "close", "cerrar", "skip", "omitir", "saltar", "skip ad", "close ad", "×", "✕", "x", "continuar",
            "continue", "no, gracias", "no thanks"};
    /** A dónde suelen mandar los anuncios para que cueste volver. */
    private static final Set<String> REDIRECT_TARGETS = new HashSet<>(java.util.Arrays.asList(
            "com.android.vending", "com.android.chrome", "org.chromium.webview_shell", "com.google.android.tv.web",
            "com.opera.browser", "org.mozilla.firefox", "com.android.browser", "com.amazon.cloud9"));

    private String adPkg;
    private long adUntil;
    private int adTries;
    private boolean adOnScreen;

    private static boolean isAdScreen(CharSequence cls) {
        if (cls == null) return false;
        String c = cls.toString();
        for (String p : AD_SCREENS) if (c.startsWith(p)) return true;
        return false;
    }

    /** Cada cambio de ventana: ¿apareció un anuncio, o el anuncio nos mandó a otra app? */
    private String lastFrontPkg;

    // ------------------------------------------------------------ anuncios de Mercado Play

    static final String MPLAY = "com.mercadolibre.android.mplay_tv";
    private boolean adWatching = false;
    private boolean adMuted = false;
    /** Hay un anuncio en pantalla ahora (Mercado Play): no se guarda nada en «Continuar viendo». */
    static volatile long adSeenAt = 0;
    static boolean adNow() { return SystemClock.uptimeMillis() - adSeenAt < 4000; }
    private int savedVol = -1;
    private long lastSkipTap = 0;

    private void startAdWatch() {
        if (adWatching || android.os.Build.VERSION.SDK_INT < 30) return;
        adWatching = true;
        handler.post(adWatch);
    }

    /**
     * Mercado Play pega los anuncios dentro del video (no se pueden bloquear). Cada 1,5 s se mira la
     * pantalla: si está la marca amarilla «Ad», se quita el sonido.
     * Al volver la serie o película, el sonido vuelve. Las series con protección salen en negro en la
     * captura, así que solo se reconoce el anuncio.
     */
    private final Runnable adWatch = new Runnable() {
        @Override
        public void run() {
            if (!MPLAY.equals(lastFrontPkg)) {
                adWatching = false;
                adEnd();
                return;
            }
            try {
                takeScreenshot(android.view.Display.DEFAULT_DISPLAY, getMainExecutor(), new TakeScreenshotCallback() {
                    @Override
                    public void onSuccess(ScreenshotResult r) {
                        boolean ad = false;
                        int w = 0, h = 0;
                        try {
                            android.graphics.Bitmap hw = android.graphics.Bitmap.wrapHardwareBuffer(r.getHardwareBuffer(), r.getColorSpace());
                            if (hw != null) {
                                android.graphics.Bitmap b = hw.copy(android.graphics.Bitmap.Config.ARGB_8888, false);
                                w = b.getWidth();
                                h = b.getHeight();
                                ad = adBadge(b);
                                b.recycle();
                            }
                            r.getHardwareBuffer().close();
                        } catch (Exception ignored) {
                        }
                        if (ad) adSeenAt = SystemClock.uptimeMillis();
                        if (ad) adStart(w, h);
                        else adEnd();
                    }

                    @Override
                    public void onFailure(int errorCode) {
                    }
                });
            } catch (Exception ignored) {
            }
            handler.postDelayed(this, 1500);
        }
    };

    /** La pastilla amarilla «Ad» abajo a la izquierda (x≈160-210, y≈795-835 en 1920×1080). */
    private static boolean adBadge(android.graphics.Bitmap b) {
        int w = b.getWidth(), h = b.getHeight();
        int x0 = w * 150 / 1920, x1 = w * 215 / 1920, y0 = h * 790 / 1080, y1 = h * 842 / 1080;
        int yellow = 0, total = 0;
        for (int y = y0; y < y1; y += 2) {
            for (int x = x0; x < x1; x += 2) {
                int c = b.getPixel(x, y);
                int R = (c >> 16) & 255, G = (c >> 8) & 255, B = c & 255;
                total++;
                if (R > 220 && G > 190 && B < 90) yellow++;
            }
        }
        return total > 0 && yellow * 100 / total >= 35;
    }

    private void adStart(int w, int h) {
        android.media.AudioManager am = (android.media.AudioManager) getSystemService(AUDIO_SERVICE);
        if (!adMuted && am != null) {
            savedVol = am.getStreamVolume(android.media.AudioManager.STREAM_MUSIC);
            am.adjustStreamVolume(android.media.AudioManager.STREAM_MUSIC, android.media.AudioManager.ADJUST_MUTE, 0);
            adMuted = true;
            Stats.add(this, Stats.ADS);
        }
        // Sin «Saltar ad» automático: en decos y teles sin pantalla táctil un toque simulado cuelga el
        // control remoto del sistema y reinicia el equipo. Solo se silencia.
    }

    private void adEnd() {
        if (!adMuted) return;
        adMuted = false;
        android.media.AudioManager am = (android.media.AudioManager) getSystemService(AUDIO_SERVICE);
        if (am != null) {
            am.adjustStreamVolume(android.media.AudioManager.STREAM_MUSIC, android.media.AudioManager.ADJUST_UNMUTE, 0);
            if (savedVol > 0 && am.getStreamVolume(android.media.AudioManager.STREAM_MUSIC) == 0) {
                am.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, savedVol, 0);
            }
        }
    }

    private void watchWindow(String pkg, CharSequence cls) {
        long now = SystemClock.uptimeMillis();
        if (isAdScreen(cls)) {
            if (!adOnScreen) {
                adOnScreen = true;
                adPkg = pkg;
                adTries = 0;
                Stats.add(this, Stats.ADS);
                AlfiOverlay.say(this, "Anuncio a pantalla completa: lo cierro.", 2500);
            }
            adUntil = now + 30_000;
            handler.removeCallbacks(closeAd);
            handler.postDelayed(closeAd, 600);
            return;
        }
        if (adOnScreen && pkg.equals(adPkg)) {
            adOnScreen = false; // volvió a la app: anuncio cerrado
            handler.removeCallbacks(closeAd);
            return;
        }
        // El anuncio abrió la tienda o el navegador: volver a la app.
        if (adPkg != null && now < adUntil && !pkg.equals(adPkg) && REDIRECT_TARGETS.contains(pkg)) {
            adOnScreen = false;
            handler.removeCallbacks(closeAd);
            performGlobalAction(GLOBAL_ACTION_BACK);
            handler.postDelayed(() -> {
                AccessibilityNodeInfo r = getRootInActiveWindow();
                CharSequence p = r == null ? null : r.getPackageName();
                if (p != null && REDIRECT_TARGETS.contains(p.toString())) performGlobalAction(GLOBAL_ACTION_BACK);
            }, 900);
            AlfiOverlay.say(this, "El anuncio quiso sacarte de la app: te devolví.", 2500);
        }
    }

    /** Intenta cerrar el anuncio: botón «Cerrar/Omitir» si se puede, si no Atrás. Reintenta hasta 25 s. */
    private final Runnable closeAd = new Runnable() {
        @Override
        public void run() {
            if (!adOnScreen || adTries++ > 30) return;
            AccessibilityNodeInfo root = getRootInActiveWindow();
            boolean clicked = false;
            if (root != null) {
                List<AccessibilityNodeInfo> found = new ArrayList<>();
                findClose(root, found, 0);
                for (AccessibilityNodeInfo n : found) {
                    AccessibilityNodeInfo t = n;
                    while (t != null && !t.isClickable()) t = t.getParent();
                    if (t != null && t.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                        clicked = true;
                        break;
                    }
                }
            }
            if (!clicked) performGlobalAction(GLOBAL_ACTION_BACK);
            handler.postDelayed(this, 800);
        }
    };

    private void findClose(AccessibilityNodeInfo n, List<AccessibilityNodeInfo> out, int depth) {
        if (n == null || depth > 30 || out.size() > 4) return;
        CharSequence t = n.getText() != null ? n.getText() : n.getContentDescription();
        if (t != null) {
            String l = t.toString().trim().toLowerCase(java.util.Locale.ROOT);
            for (String w : CLOSE_WORDS) {
                if (l.equals(w) || (w.length() > 2 && l.startsWith(w) && l.length() <= w.length() + 12)) {
                    out.add(n);
                    break;
                }
            }
        }
        for (int i = 0; i < n.getChildCount(); i++) findClose(n.getChild(i), out, depth + 1);
    }

    private static final class Snapshot {
        final String pkg;
        final String screen;
        final List<AccessibilityNodeInfo> nodes;
        /**
         * Solo los textos cortos (botones, títulos de avisos). Las palabras «anuncio»/«publicidad»
         * se buscan aquí: así el chat de Kick o una descripción larga no cuentan como anuncio.
         */
        final String brief;

        Snapshot(String pkg, String screen, List<AccessibilityNodeInfo> nodes) {
            this.pkg = pkg;
            this.screen = screen;
            this.nodes = nodes;
            StringBuilder b = new StringBuilder();
            for (AccessibilityNodeInfo n : nodes) {
                CharSequence t = n.getText() != null ? n.getText() : n.getContentDescription();
                if (t != null && t.length() <= 60) b.append(t).append(' ');
            }
            this.brief = b.toString();
        }
    }

    private Snapshot snapshot() {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return null;
        StringBuilder screen = new StringBuilder();
        List<AccessibilityNodeInfo> nodes = new ArrayList<>();
        collect(root, screen, nodes, 0);
        CharSequence pkg = root.getPackageName();
        return new Snapshot(pkg == null ? null : pkg.toString(), screen.toString(), nodes);
    }

    private void collect(AccessibilityNodeInfo node, StringBuilder screen, List<AccessibilityNodeInfo> out, int depth) {
        if (depth > MAX_DEPTH || out.size() > MAX_NODES) return;
        CharSequence text = node.getText();
        CharSequence desc = node.getContentDescription();
        if (text != null) screen.append(text).append(' ');
        if (desc != null) screen.append(desc).append(' ');
        if (text != null || desc != null) out.add(node);
        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo child = node.getChild(i);
            if (child != null) collect(child, screen, out, depth + 1);
        }
    }

    private static String label(AccessibilityNodeInfo n) {
        CharSequence t = n.getText() != null ? n.getText() : n.getContentDescription();
        return t == null ? null : t.toString();
    }

    /** Devuelve el botón encontrado, o el propio root si es un disparador de texto; null si no se cumple. */
    /** Apps con chat en vivo: lo que escribe la gente («ese anuncio…») no es un aviso de la app. */
    static boolean chatApp(String pkg) {
        return pkg != null && (pkg.startsWith("com.kick.") || pkg.startsWith("tv.twitch.")
                || pkg.equals("com.google.android.youtube.tv.chat"));
    }

    private Object evaluate(Macros.Macro m, Snapshot s) {
        // En apps de chat, las reglas que dependen de palabras en pantalla (p. ej. «Cerrar» si dice
        // «anuncio») no se usan; los botones exactos («Saltar anuncio») sí.
        if (chatApp(s.pkg) && (!m.context.isEmpty() || "TEXT".equals(m.trigger))) return null;
        // Ignorar actualizaciones solo dentro de las apps, nunca donde se instala a propósito.
        if (Macros.isUpdateRule(m) && s.pkg != null && (s.pkg.equals("com.android.vending")
                || s.pkg.contains("packageinstaller") || s.pkg.contains("settings") || s.pkg.equals(getPackageName()))) return null;
        // WiwyXuper: sus avisos de actualizar se dejan como estaban (son necesarios). Solo se salta la
        // pantalla de «Versión no compatible».
        if (m.id.startsWith("tpl-upd-") && !m.id.equals("tpl-upd-incompatible") && !m.id.equals("tpl-upd-descontinuada")
                && s.pkg != null && s.pkg.startsWith("com.xuper.")) return null;
        // La lista de notificaciones que abre la persona (WiwyXuper) no es un aviso: tiene «Cerrar».
        if (Macros.isUpdateRule(m) && s.brief.toLowerCase(java.util.Locale.ROOT).contains("notificaciones")) return null;
        if ("BUTTON".equals(m.trigger)) {
            for (AccessibilityNodeInfo n : s.nodes) {
                String l = label(n);
                if (l == null || l.trim().length() > m.text.trim().length() + 12) continue;
                if (!pressable(n)) continue;
                // Nunca botones de pago (alquilar, comprar, suscribirse).
                if (Macros.normalize(l).matches("(alquilar|comprar|rentar|suscribete|suscribirse|pagar).*")) continue;
                if (Macros.buttonMatches(m, l, s.brief, s.pkg)) return n;
            }
            return null;
        }
        return Macros.textMatches(m, s.brief, s.pkg) ? Boolean.TRUE : null;
    }

    private static boolean pressable(AccessibilityNodeInfo n) {
        if (n.isClickable()) return true;
        AccessibilityNodeInfo p = n.getParent();
        return p != null && p.isClickable();
    }

    private final Map<String, Long> lastAdCheck = new HashMap<>();

    /** Si en pantalla hay algo con pinta de anuncio, Alfi lo apunta en su libreta. */
    private void spotAd(Snapshot s) {
        if (chatApp(s.pkg)) return;
        if (s.pkg == null || s.pkg.equals(getPackageName())
                || (s.pkg.startsWith("com.android.") && !s.pkg.equals("com.android.chrome"))
                || s.pkg.equals("com.google.android.tvlauncher") || s.pkg.equals("com.spocky.projengmenu")) return;
        long now = SystemClock.uptimeMillis();
        Long last = lastAdCheck.get(s.pkg);
        if (last != null && now - last < 3000) return;
        lastAdCheck.put(s.pkg, now);
        String screen = s.brief.toLowerCase(java.util.Locale.ROOT);
        String hit = null;
        for (String w : AdLog.AD_SCREEN_WORDS) {
            if (screen.contains(w)) {
                hit = w;
                break;
            }
        }
        if (hit == null) return;
        int at = Math.max(0, screen.indexOf(hit) - 40);
        String text = s.brief.substring(at, Math.min(s.brief.length(), at + 120)).replaceAll("\\s+", " ").trim();
        List<String> buttons = new ArrayList<>();
        for (AccessibilityNodeInfo n : s.nodes) {
            String l = label(n);
            if (l == null) continue;
            l = l.trim();
            if (l.isEmpty() || l.length() > 30 || buttons.contains(l)) continue;
            boolean clickable = n.isClickable() || (n.getParent() != null && n.getParent().isClickable());
            if (clickable) buttons.add(l);
            if (buttons.size() >= 6) break;
        }
        String name = s.pkg;
        try {
            name = String.valueOf(getPackageManager().getApplicationLabel(getPackageManager().getApplicationInfo(s.pkg, 0)));
        } catch (Exception ignored) {
        }
        AdLog.popup(this, s.pkg, name, text, buttons);
        String key = s.pkg + "@" + new java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.ROOT).format(new java.util.Date());
        if (AlfiOverlay.enabled(this) && announced.add(key)) {
            AlfiOverlay.say(this, "¡Te pillé, anuncio! Lo apunto en mi libreta para bloquearlo.", 3500);
        }
    }

    private final Set<String> announced = new HashSet<>();

    // Apps donde nunca hay nada que cerrar: no se leen (teclados, barra del sistema, inicio).
    private static final Set<String> IGNORE = new HashSet<>(java.util.Arrays.asList(
            "com.android.systemui", "com.google.android.inputmethod.latin", "com.samsung.android.honeyboard",
            "com.touchtype.swiftkey", "com.miui.home", "com.mi.android.globallauncher", "com.sec.android.app.launcher",
            "com.google.android.apps.nexuslauncher", "com.android.launcher3", "com.google.android.tvlauncher",
            "com.google.android.apps.tv.launcherx", "com.spocky.projengmenu"));
    private static final long SETTLE_MS = 600;
    private long lastAudioCheck = 0;
    private boolean playingNow = false;
    private long lastScan;
    private boolean scanQueued;
    private final Runnable queuedScan = () -> {
        scanQueued = false;
        scan();
    };

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        CharSequence p = event.getPackageName();
        String pkg = p == null ? "" : p.toString();
        int et = event.getEventType();
        if (et == AccessibilityEvent.TYPE_VIEW_FOCUSED || et == AccessibilityEvent.TYPE_VIEW_SELECTED
                || et == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            lastKeyAt = SystemClock.uptimeMillis(); // alguien usa el control
            if (et != AccessibilityEvent.TYPE_VIEW_CLICKED) return;
        }
        if (event.getEventType() == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            // Lo que se elige dentro de una app (película, serie, canal): título para «Continuar viendo».
            ContinueWatch.onClick(this, pkg, event.getSource(), event.getText());
            return;
        }
        boolean cleaning = cleaner != null && cleaner.running();
        if (event.getEventType() == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && !pkg.isEmpty()
                && !pkg.equals("com.android.systemui")) {
            // Se cambió de app (o se volvió al inicio): guardar ya lo que se veía en la anterior.
            if (lastFrontPkg != null && !lastFrontPkg.equals(pkg)) ContinueWatch.onLeave(this, lastFrontPkg);
            lastFrontPkg = pkg;
            // (Sin vigilancia por capturas en Mercado Play: capturar su video protegido reinicia el deco.)
        }
        if (event.getEventType() == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && !cleaning && !pkg.equals(getPackageName())) {
            watchWindow(pkg, event.getClassName());
        }
        if (!cleaning && (pkg.equals(getPackageName()) || IGNORE.contains(pkg))) return;
        // Leer la pantalla como mucho una vez cada 0,6 s: así las apps van fluidas al deslizar.
        long now = SystemClock.uptimeMillis();
        boolean windowChanged = event.getEventType() == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED;
        // Con video o música sonando, la pantalla cambia sin parar (subtítulos, barra de tiempo): mirar
        // con menos frecuencia para que la app vaya fluida. Los cambios de ventana se miran al momento.
        long settle = SETTLE_MS;
        if (!windowChanged && now - lastAudioCheck > 2000) {
            lastAudioCheck = now;
            android.media.AudioManager am = (android.media.AudioManager) getSystemService(AUDIO_SERVICE);
            playingNow = am != null && am.isMusicActive();
        }
        if (playingNow && !windowChanged) settle = 2000;
        if (cleaning) {
            handler.removeCallbacks(queuedScan);
            scanQueued = false;
            scan();
            return;
        }
        // Esperar a que la pantalla se calme: mientras se navega con el control (cada tecla cambia la
        // pantalla) no se lee nada; se lee 0,4 s después del último cambio de ventana o 0,9 s después
        // del último cambio de contenido. Así el control responde siempre al instante.
        long wait = windowChanged ? 400 : Math.max(900, settle);
        if (now - lastKeyAt < 1500) wait = Math.max(wait, 1200);
        handler.removeCallbacks(queuedScan);
        scanQueued = true;
        handler.postDelayed(queuedScan, wait);
    }

    private void scan() {
        lastScan = SystemClock.uptimeMillis();
        Snapshot s = snapshot();
        if (s == null) return;
        if (cleaner != null && cleaner.running()) {
            cleaner.onScreen(s.pkg, getRootInActiveWindow(), s.nodes, s.screen);
            return;
        }
        if (ContinueOpen.onScreen(this, s.pkg, s.nodes)) return;
        if (ContinueOpen.active() && !scanQueued) {
            // Abriendo algo de «Continuar viendo»: volver a mirar aunque la app no avise de cambios.
            scanQueued = true;
            handler.postDelayed(queuedScan, 1200);
        }
        spotAd(s);
        ContinueWatch.onScreen(this, s.pkg, s.nodes);
        long now = SystemClock.uptimeMillis();
        for (Macros.Macro m : macros) {
            if (!m.enabled || pending.contains(m.id)) continue;
            Long last = lastRun.get(m.id);
            if (last != null && now - last < cooldown(m)) continue;
            if (tooMany(m.id, now)) continue;
            Long until = givenUp.get(m.id + "@" + s.pkg);
            if (until != null && now < until) continue;
            Object hit = evaluate(m, s);
            if (hit == null) continue;
            lastRun.put(m.id, now);
            if (m.delaySeconds > 0) {
                pending.add(m.id);
                handler.postDelayed(() -> runAfterDelay(m), m.delaySeconds * 1000L);
            } else {
                perform(m, hit);
            }
            break; // una acción por evento
        }
    }

    /** Freno de seguridad: como mucho 3 acciones por minuto de la misma automatización. */
    private final Map<String, java.util.ArrayDeque<Long>> recent = new HashMap<>();

    private boolean tooMany(String id, long now) {
        java.util.ArrayDeque<Long> q = recent.get(id);
        if (q == null) recent.put(id, q = new java.util.ArrayDeque<>());
        while (!q.isEmpty() && now - q.peekFirst() > 60_000L) q.pollFirst();
        return q.size() >= 3;
    }

    private void noteRun(String id) {
        java.util.ArrayDeque<Long> q = recent.get(id);
        if (q == null) recent.put(id, q = new java.util.ArrayDeque<>());
        q.addLast(SystemClock.uptimeMillis());
    }

    private void runAfterDelay(Macros.Macro m) {
        pending.remove(m.id);
        Snapshot s = snapshot();
        if (s == null) return;
        Object hit = evaluate(m, s);
        if (hit != null) perform(m, hit);
    }

    private void closeBlockingScreen() {
        try {
            AccessibilityNodeInfo root = getRootInActiveWindow();
            if (root == null) return;
            Snapshot s = snapshot();
            if (s == null || !Macros.normalize(s.brief).contains("version no compatible")) return;
            StringBuilder dump = new StringBuilder("Ventana «Versión no compatible» en " + s.pkg + "\n");
            for (AccessibilityNodeInfo n : s.nodes) {
                dump.append(n.getViewIdResourceName()).append(" | ").append(n.getClassName()).append(" | ")
                        .append(label(n)).append(n.isClickable() ? " | pulsable" : "").append("\n");
            }
            ProTools.logError(this, dump.toString());
            for (AccessibilityNodeInfo n : s.nodes) {
                String l = Macros.normalize(label(n));
                if (l.equals("x") || l.equals("cerrar") || l.equals("close") || l.equals("omitir") || l.equals("skip")
                        || l.equals("cancelar") || l.equals("cancel") || l.equals("salir") || l.equals("despues")) {
                    AccessibilityNodeInfo c = n;
                    for (int i = 0; i < 4 && c != null; i++, c = c.getParent()) {
                        if (c.isClickable() && c.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return;
                    }
                }
            }
            performGlobalAction(GLOBAL_ACTION_BACK); // sin botón de cerrar: un solo «Atrás»
        } catch (Exception ignored) {
        }
    }

    /** Automatizaciones que no consiguieron cerrar su aviso en una app: se dejan descansar. */
    private final Map<String, Long> givenUp = new HashMap<>();

    private void perform(Macros.Macro m, Object hit) {
        noteRun(m.id);
        switch (m.action) {
            case "BACK":
                if (m.id.equals("tpl-upd-incompatible") || m.id.equals("tpl-upd-descontinuada")) {
                    // Solo con esa ventana a la vista: se guarda cómo está hecha (para afinar) y se quita sin
                    // cerrar la app: primero su propio botón de cerrar; si no tiene, un único «Atrás», que en una
                    // ventana encima de la app solo cierra la ventana.
                    closeBlockingScreen();
                    done(m);
                    break;
                }
                performGlobalAction(GLOBAL_ACTION_BACK);
                done(m);
                break;
            case "HOME":
                performGlobalAction(GLOBAL_ACTION_HOME);
                done(m);
                break;
            default:
                if (hit instanceof AccessibilityNodeInfo) {
                    Snapshot before = snapshot();
                    press(m, (AccessibilityNodeInfo) hit);
                    verify(m, before == null ? null : before.pkg, 2);
                }
        }
    }

    /** Cuenta la acción y Alfi lo anuncia (solo cuando de verdad funcionó). */
    private void done(Macros.Macro m) {
        Stats.add(this, Stats.ACTIONS);
        android.util.Log.i("SGAlfa", "Hecho: «" + m.name + "»");
        if (!AlfiOverlay.enabled(this)) return;
        String what;
        switch (m.action) {
            case "BACK": what = "Cerré «" + m.name + "» por ti."; break;
            case "HOME": what = "Te llevé al inicio («" + m.name + "»)."; break;
            default: what = "¡Pulsé «" + m.text.trim() + "» por ti!";
        }
        AlfiOverlay.say(this, what, 3500);
    }

    /** Un momento después: ¿se fue el botón? Si sigue, otro intento; si no hay manera, se deja. */
    private void verify(Macros.Macro m, String pkg, int left) {
        handler.postDelayed(() -> {
            Snapshot s = snapshot();
            Object again = s == null ? null : evaluate(m, s);
            if (!(again instanceof AccessibilityNodeInfo)) {
                done(m);
                return;
            }
            if (left > 0) {
                AccessibilityNodeInfo n = (AccessibilityNodeInfo) again;
                if (!tap(n)) click(n);
                verify(m, pkg, left - 1);
            } else {
                givenUp.put(m.id + "@" + (pkg == null ? s.pkg : pkg), SystemClock.uptimeMillis() + 10 * 60_000L);
                android.util.Log.i("SGAlfa", "No se pudo: «" + m.name + "» en " + s.pkg + " (lo dejo 10 min)");
            }
        }, 800);
    }

    /** Pulsa el botón: primero lo vuelve a localizar (las páginas web cambian mientras cargan). */
    private boolean press(Macros.Macro m, AccessibilityNodeInfo node) {
        Snapshot fresh = snapshot();
        if (fresh != null) {
            Object again = evaluate(m, fresh);
            if (again instanceof AccessibilityNodeInfo) node = (AccessibilityNodeInfo) again;
        }
        node.performAction(AccessibilityNodeInfo.ACTION_FOCUS);
        if (click(node)) return true;
        return tap(node);
    }

    private Boolean touch;

    /** Toque en el centro del botón, como haría un dedo. En aparatos sin pantalla táctil (decos, teles) no se usa. */
    private boolean tap(AccessibilityNodeInfo node) {
        if (touch == null) touch = getPackageManager().hasSystemFeature(android.content.pm.PackageManager.FEATURE_TOUCHSCREEN);
        if (!touch) return false;
        try {
            android.graphics.Rect r = new android.graphics.Rect();
            node.getBoundsInScreen(r);
            if (r.isEmpty()) return false;
            android.graphics.Path p = new android.graphics.Path();
            p.moveTo(r.exactCenterX(), r.exactCenterY());
            android.accessibilityservice.GestureDescription g = new android.accessibilityservice.GestureDescription.Builder()
                    .addStroke(new android.accessibilityservice.GestureDescription.StrokeDescription(p, 0, 80))
                    .build();
            return dispatchGesture(g, null, null);
        } catch (Exception e) {
            return false;
        }
    }

    /** Pulsar es inofensivo cada 2 s; Atrás/Inicio esperan más para no sacarte de la app en bucle. */
    private static long cooldown(Macros.Macro m) {
        return "CLICK".equals(m.action) ? 2_000L : 6_000L;
    }

    private static boolean click(AccessibilityNodeInfo node) {
        // Si el botón ya no existe tal cual (la pantalla cambió), no fingir que se pulsó.
        if (!node.refresh()) return false;
        AccessibilityNodeInfo current = node;
        int hops = 0;
        while (current != null && hops <= 4) {
            if (current.isClickable() && current.isEnabled()) {
                return current.performAction(AccessibilityNodeInfo.ACTION_CLICK);
            }
            current = current.getParent();
            hops++;
        }
        return false;
    }

    /** Última vez que se pulsó una tecla del control (para saber si una pausa la hizo la persona). */
    static volatile long lastKeyAt = 0;


    @Override
    public void onInterrupt() {
    }

    @Override
    public void onDestroy() {
        if (instance == this) instance = null;
        AlfiOverlay.hide(this);
        handler.removeCallbacksAndMessages(null);
        try {
            prefs().unregisterOnSharedPreferenceChangeListener(listener);
        } catch (Exception ignored) {
        }
        super.onDestroy();
    }
}
