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
    /** 0: buscar en la primera pantalla · 1: se abrió el historial · 2: se abrió el buscador · 3: se escribió. */
    private static volatile int stage;
    /** ¿La tarjeta es lo más reciente de esa app? (entonces el primero del historial es ese). */
    private static volatile boolean newest;
    private static final Pattern WATCHED = Pattern.compile("(?i).*(mir[oó] hasta|visto|watched|episodio|cap[ií]tulo|ep\\.? ?\\d).*");
    private static volatile long stageAt;
    private static final long STAGE_MS = 4500;

    /** ¿Hay una apertura en curso? (el servicio vuelve a mirar la pantalla cada poco). */
    static boolean active() {
        return targetTitle != null && SystemClock.uptimeMillis() < targetUntil;
    }

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
            stage = 0;
            stageAt = SystemClock.uptimeMillis();
            newest = isNewest(c, pkg, title);
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

    // ------------------------------------------------------------ historial y buscador de la app

    private static final Pattern HISTORY_ID = Pattern.compile("(?i).*:id/.*(record|histor|recent|watched|continu).*");
    private static final Pattern SEARCH_ID = Pattern.compile("(?i).*:id/.*(search|buscar|busca).*");

    /**
     * El título no está en la primera pantalla: se prueba el historial de la app (WiwyXuper tiene un
     * reloj arriba) y, si tampoco, su buscador escribiendo el nombre de la serie.
     */
    private static boolean nextStage(AccessibilityService svc, String query) {
        long now = SystemClock.uptimeMillis();
        AccessibilityNodeInfo root = svc.getRootInActiveWindow();
        if (root == null) return false;
        if (stage == 2) {
            AccessibilityNodeInfo edit = find(root, null, true, 0);
            if (edit != null) {
                android.os.Bundle b = new android.os.Bundle();
                b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, query);
                edit.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, b);
                stage = 3;
                stageAt = now;
                return true;
            }
        }
        if (stage == 3 && now - stageAt > 2500 && android.os.Build.VERSION.SDK_INT >= 30) {
            // Si la app no busca sola al escribir, se pulsa «Intro» del teclado.
            AccessibilityNodeInfo edit = find(root, null, true, 0);
            stage = 4;
            stageAt = now;
            if (edit != null) edit.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.getId());
            return false;
        }
        if (stage == 1 && newest && now - stageAt > 3000) {
            // En el historial el nombre puede salir distinto (traducido): el primero es lo último visto.
            AccessibilityNodeInfo first = firstWatched(root, 0);
            if (first != null && click(first)) {
                targetTitle = null;
                return true;
            }
        }
        if (now - stageAt < STAGE_MS) return false;
        if (stage == 0) {
            stage = 1;
            stageAt = now;
            AccessibilityNodeInfo h = find(root, HISTORY_ID, false, 0);
            if (h != null && click(h)) return true;
        }
        if (stage == 1) {
            stage = 2;
            stageAt = now;
            AccessibilityNodeInfo s = find(root, SEARCH_ID, false, 0);
            if (s != null && click(s)) return true;
        }
        return false;
    }

    private static boolean isNewest(Context c, String pkg, String title) {
        try {
            for (java.util.Map<String, Object> m : ContinueWatch.list(c)) {
                if (!pkg.equals(m.get("package"))) continue;
                return Macros.normalize(String.valueOf(m.get("title"))).equals(Macros.normalize(title));
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    private static AccessibilityNodeInfo firstWatched(AccessibilityNodeInfo n, int depth) {
        if (n == null || depth > 30) return null;
        CharSequence t = n.getText();
        if (n.isVisibleToUser() && t != null && WATCHED.matcher(t.toString()).matches()) return n;
        for (int i = 0; i < n.getChildCount(); i++) {
            AccessibilityNodeInfo r = firstWatched(n.getChild(i), depth + 1);
            if (r != null) return r;
        }
        return null;
    }

    private static boolean click(AccessibilityNodeInfo n) {
        for (int i = 0; i < 4 && n != null; i++) {
            if (n.isClickable() && n.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true;
            n = n.getParent();
        }
        return false;
    }

    /** Primer nodo visible cuyo id encaja (o el primer cuadro de texto editable). */
    private static AccessibilityNodeInfo find(AccessibilityNodeInfo n, Pattern id, boolean editable, int depth) {
        if (n == null || depth > 30) return null;
        if (n.isVisibleToUser()) {
            if (editable && n.isEditable()) return n;
            String vid = n.getViewIdResourceName();
            if (!editable && id != null && vid != null && id.matcher(vid).matches()) return n;
        }
        for (int i = 0; i < n.getChildCount(); i++) {
            AccessibilityNodeInfo r = find(n.getChild(i), id, editable, depth + 1);
            if (r != null) return r;
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
            if (n.isEditable()) continue; // el cuadro de búsqueda con lo que escribimos no cuenta
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
        if (best == null) {
            // Para el buscador: sin símbolos delante ni «Season 7 / Temporada 2» detrás.
            String q = ContinueWatch.series(want).replaceAll("^[^\\p{L}\\p{N}]+", "")
                    .replaceAll("(?i)\\s*(season|temporada|t)\\s*\\d+\\s*$", "").trim();
            return nextStage(svc, q.isEmpty() ? want : q);
        }
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
