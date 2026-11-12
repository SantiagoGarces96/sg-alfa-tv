/*
 * SG Alfa Home — «A esta hora sueles ver…».
 * Usa el registro de uso de Android (UsageStats) de la propia tele; no se envía nada fuera.
 */
package tv.sgalfa.home;

import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;

import java.util.Calendar;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class Habits {

    private static final long DAY = 24L * 60 * 60 * 1000;
    private static final int DAYS = 21;

    private Habits() {
    }

    /** Paquetes que son pantallas de inicio (no tiene sentido sugerirlas). */
    private static Set<String> launchers(Context c) {
        Set<String> out = new HashSet<>();
        Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        for (ResolveInfo r : c.getPackageManager().queryIntentActivities(home, 0)) {
            out.add(r.activityInfo.packageName);
        }
        return out;
    }

    /**
     * App más abierta a esta hora (±1 h) en las últimas 3 semanas, o null.
     * Devuelve {packageName, name, times}.
     */
    public static Map<String, Object> suggestion(Context c) {
        UsageStatsManager usm = (UsageStatsManager) c.getSystemService(Context.USAGE_STATS_SERVICE);
        if (usm == null) return null;
        long now = System.currentTimeMillis();
        UsageEvents events;
        try {
            events = usm.queryEvents(now - DAYS * DAY, now);
        } catch (Exception e) {
            return null;
        }
        if (events == null) return null;

        Calendar cal = Calendar.getInstance();
        int hourNow = cal.get(Calendar.HOUR_OF_DAY);
        Set<String> skip = launchers(c);
        skip.add(c.getPackageName());
        skip.add("com.android.tv.settings");
        skip.add("com.android.settings");
        skip.add("com.android.systemui");

        PackageManager pm = c.getPackageManager();
        Map<String, Integer> score = new HashMap<>();
        Map<String, Long> lastDay = new HashMap<>();
        UsageEvents.Event e = new UsageEvents.Event();
        while (events.hasNextEvent()) {
            events.getNextEvent(e);
            if (e.getEventType() != UsageEvents.Event.MOVE_TO_FOREGROUND) continue;
            String pkg = e.getPackageName();
            if (pkg == null || skip.contains(pkg)) continue;
            cal.setTimeInMillis(e.getTimeStamp());
            int h = cal.get(Calendar.HOUR_OF_DAY);
            int diff = Math.min(Math.abs(h - hourNow), 24 - Math.abs(h - hourNow));
            if (diff > 1) continue;
            // Cuenta como mucho una vez por día y app (no premia abrir y cerrar 20 veces).
            long day = e.getTimeStamp() / DAY;
            String k = pkg + "@" + day;
            if (lastDay.containsKey(k)) continue;
            lastDay.put(k, day);
            score.put(pkg, (score.containsKey(pkg) ? score.get(pkg) : 0) + (diff == 0 ? 2 : 1));
        }

        String best = null;
        int bestScore = 0;
        for (Map.Entry<String, Integer> s : score.entrySet()) {
            boolean launchable = pm.getLeanbackLaunchIntentForPackage(s.getKey()) != null
                    || pm.getLaunchIntentForPackage(s.getKey()) != null;
            if (s.getValue() > bestScore && launchable) {
                best = s.getKey();
                bestScore = s.getValue();
            }
        }
        // Al menos 3 «puntos» (p. ej. tres días distintos) para no sugerir por casualidad.
        if (best == null || bestScore < 3) return null;

        Map<String, Object> out = new HashMap<>();
        out.put("packageName", best);
        try {
            out.put("name", pm.getApplicationLabel(pm.getApplicationInfo(best, 0)).toString());
        } catch (Exception ex) {
            out.put("name", best);
        }
        out.put("score", bestScore);
        return out;
    }

}
