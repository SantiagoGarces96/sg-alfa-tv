/*
 * SG Alfa Home — lo que Alfi sabe de la tele: tiempo de uso por app, hábitos por franja,
 * apps olvidadas y caché. Todo se calcula en la propia tele; no se envía nada fuera.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.app.usage.StorageStats;
import android.app.usage.StorageStatsManager;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Process;
import android.os.storage.StorageManager;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class AlfiReport {

    private static final long DAY = 24L * 60 * 60 * 1000;

    private AlfiReport() {
    }

    /** Apps con icono en la tele (lo que tiene sentido contar). */
    private static Map<String, String> launchable(Context c) {
        PackageManager pm = c.getPackageManager();
        Map<String, String> out = new LinkedHashMap<>();
        for (String cat : new String[]{Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER}) {
            for (ResolveInfo r : pm.queryIntentActivities(new Intent(Intent.ACTION_MAIN).addCategory(cat), 0)) {
                String pkg = r.activityInfo.packageName;
                if (!out.containsKey(pkg)) out.put(pkg, String.valueOf(r.loadLabel(pm)));
            }
        }
        out.remove(c.getPackageName());
        // Las pantallas de inicio no cuentan como «ver la tele».
        for (ResolveInfo r : pm.queryIntentActivities(new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)) {
            out.remove(r.activityInfo.packageName);
        }
        out.remove("com.android.tv.settings");
        return out;
    }

    private static long startOfToday() {
        Calendar cal = Calendar.getInstance();
        cal.set(Calendar.HOUR_OF_DAY, 0);
        cal.set(Calendar.MINUTE, 0);
        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);
        return cal.getTimeInMillis();
    }

    /** Minutos en primer plano por app entre dos momentos, a partir de los eventos (preciso). */
    private static Map<String, Long> foregroundMs(UsageStatsManager usm, long from, long to, Set<String> only) {
        Map<String, Long> total = new HashMap<>();
        Map<String, Long> openSince = new HashMap<>();
        UsageEvents ev = usm.queryEvents(from, to);
        UsageEvents.Event e = new UsageEvents.Event();
        while (ev != null && ev.hasNextEvent()) {
            ev.getNextEvent(e);
            String p = e.getPackageName();
            if (p == null || !only.contains(p)) continue;
            int type = e.getEventType();
            if (type == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                openSince.put(p, e.getTimeStamp());
            } else if (type == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                Long s = openSince.remove(p);
                if (s != null) total.put(p, (total.containsKey(p) ? total.get(p) : 0) + (e.getTimeStamp() - s));
            }
        }
        // Lo que sigue abierto ahora mismo.
        for (Map.Entry<String, Long> o : openSince.entrySet()) {
            long add = Math.max(0, Math.min(to, System.currentTimeMillis()) - o.getValue());
            total.put(o.getKey(), (total.containsKey(o.getKey()) ? total.get(o.getKey()) : 0) + add);
        }
        return total;
    }

    private static List<Map<String, Object>> top(Map<String, Long> ms, Map<String, String> names, int max) {
        List<Map.Entry<String, Long>> list = new ArrayList<>(ms.entrySet());
        list.sort((a, b) -> Long.compare(b.getValue(), a.getValue()));
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map.Entry<String, Long> en : list) {
            long min = en.getValue() / 60000;
            if (min < 1) continue;
            Map<String, Object> m = new HashMap<>();
            m.put("package", en.getKey());
            m.put("name", names.get(en.getKey()));
            m.put("minutes", min);
            out.add(m);
            if (out.size() >= max) break;
        }
        return out;
    }

    /** Franja del día: mañana, tarde, noche o madrugada. */
    private static String slot(int h) {
        if (h >= 6 && h < 12) return "mañana";
        if (h >= 12 && h < 19) return "tarde";
        if (h >= 19) return "noche";
        return "madrugada";
    }

    public static Map<String, Object> build(Context c) {
        Map<String, Object> out = new HashMap<>();
        Map<String, String> names = launchable(c);
        Set<String> pkgs = names.keySet();
        UsageStatsManager usm = (UsageStatsManager) c.getSystemService(Context.USAGE_STATS_SERVICE);
        long now = System.currentTimeMillis();

        if (usm != null) {
            try {
                Map<String, Long> today = foregroundMs(usm, startOfToday(), now, pkgs);
                Map<String, Long> week = foregroundMs(usm, now - 7 * DAY, now, pkgs);
                long todayTotal = 0;
                for (long v : today.values()) todayTotal += v;
                long weekTotal = 0;
                for (long v : week.values()) weekTotal += v;
                out.put("todayMinutes", todayTotal / 60000);
                out.put("weekMinutes", weekTotal / 60000);
                out.put("today", top(today, names, 6));
                Map<String, Long> yesterday = foregroundMs(usm, startOfToday() - DAY, startOfToday(), pkgs);
                long yTotal = 0;
                for (long v : yesterday.values()) yTotal += v;
                out.put("yesterdayMinutes", yTotal / 60000);
                out.put("week", top(week, names, 6));

                // Lo aprendido: la app más vista en cada franja (3 semanas).
                Map<String, Map<String, Integer>> bySlot = new HashMap<>();
                Map<String, Long> lastUsed = new HashMap<>();
                Set<String> counted = new HashSet<>();
                Calendar cal = Calendar.getInstance();
                UsageEvents ev = usm.queryEvents(now - 21 * DAY, now);
                UsageEvents.Event e = new UsageEvents.Event();
                while (ev != null && ev.hasNextEvent()) {
                    ev.getNextEvent(e);
                    String p = e.getPackageName();
                    if (p == null || !pkgs.contains(p) || e.getEventType() != UsageEvents.Event.MOVE_TO_FOREGROUND) continue;
                    lastUsed.put(p, e.getTimeStamp());
                    cal.setTimeInMillis(e.getTimeStamp());
                    int dow = cal.get(Calendar.DAY_OF_WEEK);
                    boolean weekend = dow == Calendar.SATURDAY || dow == Calendar.SUNDAY;
                    String s = slot(cal.get(Calendar.HOUR_OF_DAY)) + (weekend ? "_finde" : "");
                    String key = p + "@" + s + "@" + (e.getTimeStamp() / DAY);
                    if (!counted.add(key)) continue; // una vez por día y franja
                    Map<String, Integer> m = bySlot.get(s);
                    if (m == null) {
                        m = new HashMap<>();
                        bySlot.put(s, m);
                    }
                    m.put(p, (m.containsKey(p) ? m.get(p) : 0) + 1);
                }
                Map<String, Object> slots = new LinkedHashMap<>();
                for (String s : new String[]{"mañana", "tarde", "noche", "madrugada",
                        "mañana_finde", "tarde_finde", "noche_finde", "madrugada_finde"}) {
                    Map<String, Integer> m = bySlot.get(s);
                    if (m == null) continue;
                    String best = null;
                    int bestN = 0;
                    for (Map.Entry<String, Integer> en : m.entrySet()) {
                        if (en.getValue() > bestN) {
                            best = en.getKey();
                            bestN = en.getValue();
                        }
                    }
                    if (best != null && bestN >= 2) {
                        Map<String, Object> v = new HashMap<>();
                        v.put("package", best);
                        v.put("name", names.get(best));
                        v.put("days", bestN);
                        slots.put(s, v);
                    }
                }
                out.put("slots", slots);

                // Lo último que se vio (para «¿sigues con…?»).
                String lastPkg = null;
                long lastTs = 0;
                for (Map.Entry<String, Long> en : lastUsed.entrySet()) {
                    if (en.getValue() > lastTs) {
                        lastTs = en.getValue();
                        lastPkg = en.getKey();
                    }
                }
                if (lastPkg != null) {
                    Map<String, Object> l = new HashMap<>();
                    l.put("package", lastPkg);
                    l.put("name", names.get(lastPkg));
                    l.put("minutesAgo", (now - lastTs) / 60000);
                    out.put("last", l);
                }

                // Apps instaladas hace menos de 3 días.
                List<Map<String, Object>> fresh = new ArrayList<>();
                for (String p : pkgs) {
                    try {
                        long installed = c.getPackageManager().getPackageInfo(p, 0).firstInstallTime;
                        if (now - installed < 3 * DAY) {
                            Map<String, Object> m = new HashMap<>();
                            m.put("package", p);
                            m.put("name", names.get(p));
                            fresh.add(m);
                        }
                    } catch (Exception ignored) {
                    }
                }
                out.put("newApps", fresh);

                // Apps olvidadas: instaladas por ti y sin abrir en 3 semanas.
                PackageManager pm = c.getPackageManager();
                List<Map<String, Object>> forgotten = new ArrayList<>();
                for (String p : pkgs) {
                    if (lastUsed.containsKey(p)) continue;
                    try {
                        ApplicationInfo ai = pm.getApplicationInfo(p, 0);
                        if ((ai.flags & ApplicationInfo.FLAG_SYSTEM) != 0) continue;
                        long installed = pm.getPackageInfo(p, 0).firstInstallTime;
                        if (now - installed < 21 * DAY) continue;
                    } catch (Exception ex) {
                        continue;
                    }
                    Map<String, Object> m = new HashMap<>();
                    m.put("package", p);
                    m.put("name", names.get(p));
                    forgotten.add(m);
                    if (forgotten.size() >= 6) break;
                }
                out.put("forgotten", forgotten);
            } catch (Exception ignored) {
            }
        }

        // Caché por app (necesita el permiso de estadísticas de uso).
        try {
            StorageStatsManager ssm = (StorageStatsManager) c.getSystemService(Context.STORAGE_STATS_SERVICE);
            List<Map<String, Object>> cache = new ArrayList<>();
            long total = 0;
            for (Map.Entry<String, String> en : names.entrySet()) {
                try {
                    StorageStats st = ssm.queryStatsForPackage(StorageManager.UUID_DEFAULT, en.getKey(), Process.myUserHandle());
                    long b = st.getCacheBytes();
                    total += b;
                    if (b < 5L * 1024 * 1024) continue; // menos de 5 MB no merece la pena
                    Map<String, Object> m = new HashMap<>();
                    m.put("package", en.getKey());
                    m.put("name", en.getValue());
                    m.put("mb", b / (1024.0 * 1024.0));
                    cache.add(m);
                } catch (Exception ignored) {
                }
            }
            cache.sort((a, b) -> Double.compare((Double) b.get("mb"), (Double) a.get("mb")));
            out.put("cache", cache.size() > 8 ? cache.subList(0, 8) : cache);
            out.put("cacheTotalMb", total / (1024.0 * 1024.0));
        } catch (Exception ignored) {
        }
        return out;
    }
}
