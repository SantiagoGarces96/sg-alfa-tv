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
    private static final int MAX_NODES = 600;

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
        return list != null && list.contains(c.getPackageName() + "/" + AutoClickService.class.getName());
    }

    static List<Macros.Macro> load(Context c) {
        String json = c.getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_MACROS, null);
        List<Macros.Macro> list = Macros.decodeOrNull(json);
        return list != null ? list : new ArrayList<>(Macros.templates());
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
        cleaner = new CacheCleaner(this);
        loadMacros();
        prefs().registerOnSharedPreferenceChangeListener(listener);
    }

    private static final class Snapshot {
        final String pkg;
        final String screen;
        final List<AccessibilityNodeInfo> nodes;

        Snapshot(String pkg, String screen, List<AccessibilityNodeInfo> nodes) {
            this.pkg = pkg;
            this.screen = screen;
            this.nodes = nodes;
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
    private Object evaluate(Macros.Macro m, Snapshot s) {
        if ("BUTTON".equals(m.trigger)) {
            for (AccessibilityNodeInfo n : s.nodes) {
                String l = label(n);
                if (l != null && Macros.buttonMatches(m, l, s.screen, s.pkg)) return n;
            }
            return null;
        }
        return Macros.textMatches(m, s.screen, s.pkg) ? Boolean.TRUE : null;
    }

    private final Map<String, Long> lastAdCheck = new HashMap<>();

    /** Si en pantalla hay algo con pinta de anuncio, Alfi lo apunta en su libreta. */
    private void spotAd(Snapshot s) {
        if (s.pkg == null || s.pkg.equals(getPackageName())
                || (s.pkg.startsWith("com.android.") && !s.pkg.equals("com.android.chrome"))
                || s.pkg.equals("com.google.android.tvlauncher") || s.pkg.equals("com.spocky.projengmenu")) return;
        long now = SystemClock.uptimeMillis();
        Long last = lastAdCheck.get(s.pkg);
        if (last != null && now - last < 3000) return;
        lastAdCheck.put(s.pkg, now);
        String screen = s.screen.toLowerCase(java.util.Locale.ROOT);
        String hit = null;
        for (String w : AdLog.AD_SCREEN_WORDS) {
            if (screen.contains(w)) {
                hit = w;
                break;
            }
        }
        if (hit == null) return;
        int at = Math.max(0, screen.indexOf(hit) - 40);
        String text = s.screen.substring(at, Math.min(s.screen.length(), at + 120)).replaceAll("\\s+", " ").trim();
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

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        Snapshot s = snapshot();
        if (s == null) return;
        if (cleaner != null && cleaner.running()) {
            cleaner.onScreen(s.pkg, getRootInActiveWindow(), s.nodes, s.screen);
            return;
        }
        spotAd(s);
        long now = SystemClock.uptimeMillis();
        for (Macros.Macro m : macros) {
            if (!m.enabled || pending.contains(m.id)) continue;
            Long last = lastRun.get(m.id);
            if (last != null && now - last < cooldown(m)) continue;
            if (tooMany(m.id, now)) continue;
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

    private void perform(Macros.Macro m, Object hit) {
        noteRun(m.id);
        Stats.add(this, Stats.ACTIONS);
        if (AlfiOverlay.enabled(this)) {
            String what;
            switch (m.action) {
                case "BACK": what = "Cerré «" + m.name + "» por ti."; break;
                case "HOME": what = "Te llevé al inicio («" + m.name + "»)."; break;
                default: what = "¡Pulsé «" + m.text.trim() + "» por ti!";
            }
            AlfiOverlay.say(this, what, 3500);
        }
        switch (m.action) {
            case "BACK":
                performGlobalAction(GLOBAL_ACTION_BACK);
                break;
            case "HOME":
                performGlobalAction(GLOBAL_ACTION_HOME);
                break;
            default:
                if (hit instanceof AccessibilityNodeInfo) {
                    boolean ok = press(m, (AccessibilityNodeInfo) hit);
                    android.util.Log.i("SGAlfa", "Automatización «" + m.name + "»: pulsado=" + ok);
                    // Comprobar que el aviso se fue; si sigue ahí, volver a intentarlo (hasta 2 veces).
                    retry(m, 2);
                }
        }
    }

    private void retry(Macros.Macro m, int left) {
        if (left <= 0) return;
        handler.postDelayed(() -> {
            Snapshot s = snapshot();
            if (s == null) return;
            Object again = evaluate(m, s);
            if (again instanceof AccessibilityNodeInfo) {
                AccessibilityNodeInfo n = (AccessibilityNodeInfo) again;
                boolean ok = tap(n);
                AccessibilityNodeInfo parent = n.getParent();
                if (parent != null) parent.performAction(AccessibilityNodeInfo.ACTION_CLICK);
                android.util.Log.i("SGAlfa", "Reintento «" + m.name + "»: toque=" + ok);
                retry(m, left - 1);
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
        android.graphics.Rect r = new android.graphics.Rect();
        node.getBoundsInScreen(r);
        android.util.Log.i("SGAlfa", "Botón «" + label(node) + "» " + node.getClassName() + " en " + r.toShortString()
                + " clicable=" + node.isClickable() + " ventana=" + (fresh == null ? "?" : fresh.pkg));
        // En TV (navegadores web) enfocar primero ayuda a que el clic llegue.
        node.performAction(AccessibilityNodeInfo.ACTION_FOCUS);
        if (click(node)) return true;
        return tap(node);
    }

    /** Toque en el centro del botón, como haría un dedo (para apps que ignoran el clic de accesibilidad). */
    private boolean tap(AccessibilityNodeInfo node) {
        try {
            android.graphics.Rect r = new android.graphics.Rect();
            node.getBoundsInScreen(r);
            if (r.isEmpty()) return false;
            android.graphics.Path p = new android.graphics.Path();
            p.moveTo(r.exactCenterX(), r.exactCenterY());
            android.accessibilityservice.GestureDescription g = new android.accessibilityservice.GestureDescription.Builder()
                    .addStroke(new android.accessibilityservice.GestureDescription.StrokeDescription(p, 0, 100))
                    .build();
            final String where = r.toShortString();
            return dispatchGesture(g, new GestureResultCallback() {
                @Override
                public void onCompleted(android.accessibilityservice.GestureDescription d) {
                    android.util.Log.i("SGAlfa", "Toque hecho en " + where);
                }

                @Override
                public void onCancelled(android.accessibilityservice.GestureDescription d) {
                    android.util.Log.i("SGAlfa", "Toque cancelado en " + where);
                }
            }, null);
        } catch (Exception e) {
            android.util.Log.i("SGAlfa", "Toque falló: " + e);
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
                boolean ok = current.performAction(AccessibilityNodeInfo.ACTION_CLICK);
                android.util.Log.i("SGAlfa", "Clic de accesibilidad (salto " + hops + "): " + ok);
                return ok;
            }
            current = current.getParent();
            hops++;
        }
        return false;
    }

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
