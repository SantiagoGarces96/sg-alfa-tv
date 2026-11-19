/*
 * SG Alfa Home — «Continuar viendo» abre lo que se estaba viendo, no solo la app.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.accessibilityservice.AccessibilityService;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.MediaMetadata;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.net.Uri;
import android.os.SystemClock;
import android.view.accessibility.AccessibilityNodeInfo;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Dos formas de llegar al contenido exacto:
 * <ul>
 *   <li>Apps de YouTube (TizenTube, YouTube, SmartTube…): se busca el vídeo por su título y se abre
 *   con un enlace directo en el segundo donde se quedó.</li>
 *   <li>Las demás (Anime Cast, WiwyXuper…): se abre la app y el servicio de automatizaciones toca
 *   en pantalla el título guardado (p. ej. el anime en su lista «Seguir viendo» o el canal).</li>
 * </ul>
 */
final class ContinueOpen {
    private ContinueOpen() {
    }

    private static final Pattern VIDEO_ID = Pattern.compile("\"videoId\":\"([A-Za-z0-9_-]{11})\"");
    private static final String CACHE = "sgalfa_yt_ids";
    private static final long WAIT_MS = 30_000;

    private static volatile String targetPkg;
    private static volatile String targetTitle;
    private static volatile long targetUntil;

    /** Desde el launcher (hilo de fondo). Devuelve true si abrió algo. */
    static boolean open(Context c, String pkg, String title, String sub, long posMs) {
        if (pkg == null || pkg.isEmpty()) return false;
        // Si la app sigue con ese mismo contenido abierto, basta con traerla al frente.
        if (sameAsNow(c, pkg, title)) return launch(c, pkg);
        if (title != null && !title.trim().isEmpty() && handlesYouTube(c, pkg)) {
            String id = videoId(c, title, sub);
            String url = id != null
                    ? "https://www.youtube.com/watch?v=" + id + (posMs > 5000 ? "&t=" + (posMs / 1000) : "")
                    : "https://www.youtube.com/results?search_query=" + enc(title);
            try {
                c.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)).setPackage(pkg)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                return true;
            } catch (Exception ignored) {
            }
        }
        boolean ok = launch(c, pkg);
        if (ok && title != null && !title.trim().isEmpty() && AutoClickService.isEnabled(c)) {
            targetPkg = pkg;
            targetTitle = title;
            targetUntil = SystemClock.uptimeMillis() + WAIT_MS;
        }
        return ok;
    }

    private static boolean launch(Context c, String pkg) {
        try {
            android.content.pm.PackageManager pm = c.getPackageManager();
            Intent i = pm.getLeanbackLaunchIntentForPackage(pkg);
            if (i == null) i = pm.getLaunchIntentForPackage(pkg);
            if (i == null) return false;
            c.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static boolean sameAsNow(Context c, String pkg, String title) {
        if (title == null) return false;
        try {
            MediaSessionManager msm = (MediaSessionManager) c.getSystemService(Context.MEDIA_SESSION_SERVICE);
            for (MediaController mc : msm.getActiveSessions(new ComponentName(c, MediaListener.class))) {
                if (!pkg.equals(mc.getPackageName()) || mc.getMetadata() == null) continue;
                String t = mc.getMetadata().getString(MediaMetadata.METADATA_KEY_TITLE);
                if (t != null && Macros.normalize(t).equals(Macros.normalize(title))) return true;
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    private static boolean handlesYouTube(Context c, String pkg) {
        try {
            Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
                    .setPackage(pkg);
            return !c.getPackageManager().queryIntentActivities(i, 0).isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    private static String enc(String s) {
        try {
            return URLEncoder.encode(s, "UTF-8");
        } catch (Exception e) {
            return s;
        }
    }

    /** Busca el vídeo por título (primer resultado) y lo recuerda para la próxima vez. */
    private static String videoId(Context c, String title, String sub) {
        SharedPreferences p = c.getSharedPreferences(CACHE, Context.MODE_PRIVATE);
        String key = Macros.normalize(title);
        String cached = p.getString(key, null);
        if (cached != null) return cached;
        HttpURLConnection con = null;
        try {
            String q = title + (sub != null && !sub.isEmpty() && !title.toLowerCase().contains(sub.toLowerCase()) ? " " + sub : "");
            con = (HttpURLConnection) new URL("https://www.youtube.com/results?search_query=" + enc(q)).openConnection();
            con.setConnectTimeout(4000);
            con.setReadTimeout(5000);
            con.setRequestProperty("User-Agent", "Mozilla/5.0 (X11; Linux x86_64)");
            con.setRequestProperty("Accept-Language", "es");
            StringBuilder sb = new StringBuilder();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(con.getInputStream(), StandardCharsets.UTF_8))) {
                char[] buf = new char[8192];
                int n;
                while ((n = r.read(buf)) > 0 && sb.length() < 1_500_000) {
                    sb.append(buf, 0, n);
                    Matcher m = VIDEO_ID.matcher(sb);
                    if (m.find()) {
                        String id = m.group(1);
                        SharedPreferences.Editor e = p.edit();
                        if (p.getAll().size() > 200) e.clear();
                        e.putString(key, id).apply();
                        return id;
                    }
                }
            }
        } catch (Exception ignored) {
        } finally {
            if (con != null) con.disconnect();
        }
        return null;
    }

    // ------------------------------------------------------------ toque en pantalla (apps sin enlaces)

    /**
     * Lo llama el servicio de automatizaciones al leer la pantalla. Si se acaba de abrir una app
     * desde «Continuar viendo», toca el título guardado. Devuelve true si tocó.
     */
    static boolean onScreen(AccessibilityService svc, String pkg, List<AccessibilityNodeInfo> nodes) {
        String want = targetTitle;
        if (want == null || !pkg.equals(targetPkg)) return false;
        if (SystemClock.uptimeMillis() > targetUntil) {
            targetTitle = null;
            return false;
        }
        String full = Macros.normalize(want);
        String serie = Macros.normalize(ContinueWatch.series(want));
        AccessibilityNodeInfo best = null;
        int bestScore = 0;
        for (AccessibilityNodeInfo n : nodes) {
            CharSequence cs = n.getText();
            if (cs == null || cs.length() == 0) cs = n.getContentDescription();
            if (cs == null) continue;
            String t = Macros.normalize(cs.toString());
            if (t.isEmpty()) continue;
            String id = n.getViewIdResourceName();
            // Ya está en el reproductor con ese contenido: no tocar nada.
            if (id != null && ContinueWatch.isPlayerTitleId(id) && (t.equals(full) || t.equals(serie))) {
                targetTitle = null;
                return false;
            }
            int score = 0;
            if (t.equals(full)) score = 3;
            else if (!serie.isEmpty() && t.equals(serie)) score = 2;
            else if (serie.length() >= 4 && t.contains(serie) && t.length() <= serie.length() + 30) score = 1;
            if (score == 0) continue;
            // Las tarjetas de «Seguir viendo» de la app, primero.
            if (id != null && (id.contains("episodio") || id.contains("continu") || id.contains("history"))) score += 3;
            if (score > bestScore) {
                bestScore = score;
                best = n;
            }
        }
        if (best == null) return false;
        AccessibilityNodeInfo n = best;
        for (int i = 0; i < 6 && n != null; i++) {
            if (n.isClickable()) {
                if (n.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                    targetTitle = null;
                    return true;
                }
            }
            n = n.getParent();
        }
        return false;
    }
}
