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

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        Snapshot s = snapshot();
        if (s == null) return;
        long now = SystemClock.uptimeMillis();
        for (Macros.Macro m : macros) {
            if (!m.enabled || pending.contains(m.id)) continue;
            Long last = lastRun.get(m.id);
            if (last != null && now - last < cooldown(m)) continue;
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

    private void runAfterDelay(Macros.Macro m) {
        pending.remove(m.id);
        Snapshot s = snapshot();
        if (s == null) return;
        Object hit = evaluate(m, s);
        if (hit != null) perform(m, hit);
    }

    private void perform(Macros.Macro m, Object hit) {
        Stats.add(this, Stats.ACTIONS);
        switch (m.action) {
            case "BACK":
                performGlobalAction(GLOBAL_ACTION_BACK);
                break;
            case "HOME":
                performGlobalAction(GLOBAL_ACTION_HOME);
                break;
            default:
                if (hit instanceof AccessibilityNodeInfo) click((AccessibilityNodeInfo) hit);
        }
    }

    /** Pulsar es inofensivo cada 2 s; Atrás/Inicio esperan más para no sacarte de la app en bucle. */
    private static long cooldown(Macros.Macro m) {
        return "CLICK".equals(m.action) ? 2_000L : 6_000L;
    }

    private static boolean click(AccessibilityNodeInfo node) {
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

    @Override
    public void onInterrupt() {
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        try {
            prefs().unregisterOnSharedPreferenceChangeListener(listener);
        } catch (Exception ignored) {
        }
        super.onDestroy();
    }
}
