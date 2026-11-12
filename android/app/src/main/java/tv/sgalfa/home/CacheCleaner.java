/*
 * SG Alfa Home — limpieza automática de caché (p. ej. los lunes).
 *
 * Android no deja que una app borre la caché de otras, así que lo hace el servicio de
 * accesibilidad igual que lo haría una persona: abre la ficha de cada app y pulsa «Borrar caché».
 *
 * Seguridad (muy estricta):
 *  - Solo actúa dentro de los Ajustes del sistema.
 *  - Solo pulsa un elemento que se llame EXACTAMENTE «Borrar caché» / «Clear cache».
 *  - En la confirmación solo pulsa «Aceptar» / «OK» si en pantalla NO aparece «Borrar datos» /
 *    «Clear data» / «Clear storage» y sí aparece «caché»/«cache».
 *  - Si algo no cuadra en 10 s, salta a la siguiente app sin tocar nada más.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.accessibilityservice.AccessibilityService;
import android.app.usage.StorageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.os.Process;
import android.os.storage.StorageManager;
import android.provider.Settings;
import android.view.accessibility.AccessibilityNodeInfo;

import java.text.SimpleDateFormat;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public final class CacheCleaner {

    private static final String PREFS = "alfi_clean";
    private static final long STEP_TIMEOUT_MS = 10_000;

    private enum Phase { IDLE, FIND_BUTTON, CONFIRM }

    private final AccessibilityService svc;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ArrayDeque<String> queue = new ArrayDeque<>();
    private Phase phase = Phase.IDLE;
    private String current;
    private int total;
    private int done;
    private int cleaned;
    private long cacheBefore;
    private final Runnable timeout = this::next;

    CacheCleaner(AccessibilityService svc) {
        this.svc = svc;
    }

    boolean running() {
        return phase != Phase.IDLE;
    }

    // ---------- Programación semanal ----------

    static boolean weeklyEnabled(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("weekly", true);
    }

    /** Día de la semana (Calendar.MONDAY = 2 … SUNDAY = 1). Por defecto, lunes. */
    static int weekday(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("weekday", Calendar.MONDAY);
    }

    static void setWeekly(Context c, boolean on, int weekday) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("weekly", on).putInt("weekday", weekday).apply();
    }

    private static String today() {
        return new SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(new Date());
    }

    /** ¿Toca limpiar hoy? (día elegido, desde las 7:00, aún no hecho ni saltado hoy). */
    static boolean due(Context c) {
        if (!weeklyEnabled(c)) return false;
        Calendar cal = Calendar.getInstance();
        if (cal.get(Calendar.DAY_OF_WEEK) != weekday(c) || cal.get(Calendar.HOUR_OF_DAY) < 7) return false;
        String last = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("last_day", "");
        return !today().equals(last);
    }

    static void skipToday(Context c) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("last_day", today()).apply();
    }

    static String lastSummary(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("last_summary", "");
    }

    // ---------- Medir caché ----------

    static long cacheBytes(Context c, String pkg) {
        try {
            StorageStatsManager ssm = (StorageStatsManager) c.getSystemService(Context.STORAGE_STATS_SERVICE);
            return ssm.queryStatsForPackage(StorageManager.UUID_DEFAULT, pkg, Process.myUserHandle()).getCacheBytes();
        } catch (Exception e) {
            return 0;
        }
    }

    /** Apps con al menos 1 MB de caché, de más a menos. */
    static List<String> candidates(Context c) {
        List<String> pkgs = new ArrayList<>();
        List<long[]> sizes = new ArrayList<>();
        android.content.pm.PackageManager pm = c.getPackageManager();
        for (android.content.pm.ApplicationInfo ai : pm.getInstalledApplications(0)) {
            if (ai.packageName.equals(c.getPackageName())) continue;
            if (pm.getLeanbackLaunchIntentForPackage(ai.packageName) == null
                    && pm.getLaunchIntentForPackage(ai.packageName) == null) continue;
            long b = cacheBytes(c, ai.packageName);
            if (b < 1024 * 1024) continue;
            pkgs.add(ai.packageName);
            sizes.add(new long[]{b});
        }
        List<Integer> idx = new ArrayList<>();
        for (int i = 0; i < pkgs.size(); i++) idx.add(i);
        idx.sort((a, b) -> Long.compare(sizes.get(b)[0], sizes.get(a)[0]));
        List<String> out = new ArrayList<>();
        for (int i : idx) out.add(pkgs.get(i));
        return out;
    }

    // ---------- La limpieza ----------

    void start(List<String> pkgs) {
        if (running() || pkgs.isEmpty()) return;
        queue.clear();
        queue.addAll(pkgs);
        total = pkgs.size();
        done = 0;
        cleaned = 0;
        cacheBefore = 0;
        for (String p : pkgs) cacheBefore += cacheBytes(svc, p);
        AlfiOverlay.progress(svc, "¡Hora de limpiar! Borro la caché de " + total + " apps. No toques el mando un momento.", 0f, 0);
        main.postDelayed(this::next, 2500);
    }

    private void next() {
        main.removeCallbacks(timeout);
        if (current != null) done++;
        current = queue.poll();
        if (current == null) {
            finish();
            return;
        }
        phase = Phase.FIND_BUTTON;
        String name = current;
        try {
            name = String.valueOf(svc.getPackageManager().getApplicationLabel(
                    svc.getPackageManager().getApplicationInfo(current, 0)));
        } catch (Exception ignored) {
        }
        AlfiOverlay.progress(svc, "Limpiando la caché… " + (done + 1) + " de " + total + "\n" + name, (float) done / total, 0);
        try {
            Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", current, null));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK | Intent.FLAG_ACTIVITY_NO_ANIMATION);
            svc.startActivity(i);
        } catch (Exception e) {
            main.post(this::next);
            return;
        }
        main.postDelayed(timeout, STEP_TIMEOUT_MS);
    }

    private void finish() {
        phase = Phase.IDLE;
        long after = 0;
        // Se mide sobre las mismas apps (ya vacías de la cola, así que se recalcula por candidatos actuales).
        for (String p : candidates(svc)) after += cacheBytes(svc, p);
        long freed = Math.max(0, cacheBefore - after);
        String mb = freed >= 1024L * 1024 * 1024
                ? String.format(Locale.ROOT, "%.1f GB", freed / (1024.0 * 1024 * 1024))
                : (freed / (1024 * 1024)) + " MB";
        String summary = "Limpié la caché de " + cleaned + " apps y liberé " + mb + ".";
        svc.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("last_day", today())
                .putString("last_summary", summary)
                .apply();
        AlfiOverlay.progress(svc, "¡Listo! " + summary, 1f, 6000);
        // Vuelta a la pantalla de inicio.
        try {
            Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            svc.startActivity(home);
        } catch (Exception ignored) {
        }
    }

    // ---------- Lo que ve el servicio durante la limpieza ----------

    private static String norm(CharSequence s) {
        return s == null ? "" : s.toString().trim().toLowerCase(Locale.ROOT);
    }

    private static boolean isClearCache(String t) {
        return t.equals("borrar caché") || t.equals("borrar cache") || t.equals("clear cache")
                || t.equals("eliminar caché") || t.equals("vaciar caché");
    }

    private static boolean isDataWord(String t) {
        return t.equals("borrar datos") || t.equals("clear data") || t.equals("clear storage")
                || t.equals("borrar almacenamiento") || t.equals("eliminar datos");
    }

    private static boolean isConfirm(String t) {
        return t.equals("aceptar") || t.equals("ok") || t.equals("borrar") || t.equals("eliminar");
    }

    /** Se llama en cada evento de accesibilidad mientras limpia. */
    void onScreen(String pkg, AccessibilityNodeInfo root, List<AccessibilityNodeInfo> nodes, String screen) {
        if (!running() || pkg == null || !pkg.contains("settings")) return;
        if (phase == Phase.FIND_BUTTON) {
            for (AccessibilityNodeInfo n : nodes) {
                if (!isClearCache(norm(n.getText()))) continue;
                if (!n.isEnabled()) return; // aún calculando o caché vacía: esperamos (o salta el tiempo)
                if (clickUp(n)) {
                    phase = Phase.CONFIRM;
                    main.removeCallbacks(timeout);
                    main.postDelayed(timeout, STEP_TIMEOUT_MS);
                }
                return;
            }
        } else if (phase == Phase.CONFIRM) {
            // Algunos decos borran sin preguntar: si vuelve a verse «Borrar caché» desactivado, ya está.
            for (AccessibilityNodeInfo n : nodes) {
                if (isClearCache(norm(n.getText())) && !n.isEnabled()) {
                    cleaned++;
                    phase = Phase.FIND_BUTTON;
                    main.removeCallbacks(timeout);
                    main.postDelayed(this::next, 700);
                    return;
                }
            }
            String sc = screen.toLowerCase(Locale.ROOT);
            if (!sc.contains("cach")) return;
            for (AccessibilityNodeInfo n : nodes) {
                if (isDataWord(norm(n.getText()))) return; // nunca en una pantalla con «Borrar datos»
            }
            for (AccessibilityNodeInfo n : nodes) {
                if (isConfirm(norm(n.getText())) && clickUp(n)) {
                    cleaned++;
                    phase = Phase.FIND_BUTTON;
                    main.removeCallbacks(timeout);
                    main.postDelayed(this::next, 900);
                    return;
                }
            }
        }
    }

    private static boolean clickUp(AccessibilityNodeInfo node) {
        AccessibilityNodeInfo cur = node;
        for (int hops = 0; cur != null && hops <= 4; hops++) {
            if (cur.isClickable() && cur.isEnabled()) return cur.performAction(AccessibilityNodeInfo.ACTION_CLICK);
            cur = cur.getParent();
        }
        return false;
    }
}
