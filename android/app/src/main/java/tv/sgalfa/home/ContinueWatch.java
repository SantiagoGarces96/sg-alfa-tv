/*
 * SG Alfa Home — «Continuar viendo»: lo que se ve dentro de las apps (Anime Cast, WiwyXuper,
 * XuperHydra…). Una tarjeta por cada serie o película, con el nombre (p. ej. «Magical★Explorer
 * - Episodio 8»), una imagen del momento y el progreso si la app lo da. Todo se queda en el deco.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.accessibilityservice.AccessibilityService;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.media.AudioManager;
import android.media.MediaMetadata;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.media.session.PlaybackState;
import android.os.Build;
import android.os.SystemClock;
import android.view.Display;
import android.view.accessibility.AccessibilityNodeInfo;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class ContinueWatch {
    private static final String PREFS = "sgalfa_continue";
    private static final String KEY = "items2";
    private static final int MAX = 12;
    private static final long SHOT_EVERY_MS = 60_000;
    private static final long REMEMBER_MS = 20 * 60_000; // un título visto hace poco vale para lo que se reproduzca

    private static final Map<String, Long> lastShot = new HashMap<>();
    /** Último buen título visto en cada app (aunque no hubiera nada sonando). */
    private static final Map<String, String> lastTitle = new HashMap<>();
    private static final Map<String, Long> lastTitleAt = new HashMap<>();
    private static final Executor worker = Executors.newSingleThreadExecutor();

    private static final Pattern TIME = Pattern.compile("^[-\\d:\\s/.]+$");
    private static final Pattern EPISODE = Pattern.compile(
            "(episodio|cap[ií]tulo|\\bep\\.?\\s*\\d|temporada|season|episode|\\bt\\d+\\s*e\\d+)", Pattern.CASE_INSENSITIVE);
    /** «Nombre - Episodio 8», «Nombre · Cap. 3», «Nombre T1 E4»: nombre de la serie + episodio. */
    private static final Pattern NAMED = Pattern.compile(
            "^(.{2,60}?)\\s*[-–—·:|]\\s*((episodio|cap[ií]tulo|ep\\.?|temporada|season|episode|t\\d+).*)$", Pattern.CASE_INSENSITIVE);
    private static final Pattern NOISE = Pattern.compile(
            "(pulsa|presiona|mant[eé]n|cargando|espere|proveedor|comentario|recomi[eé]ndanos|instagram|whatsapp|"
                    + "anuncio|publicidad|siguiente|anterior|reproducir|pausa|ajustes|configuraci|buscar|men[uú]|salir)",
            Pattern.CASE_INSENSITIVE);

    private ContinueWatch() {
    }

    // ------------------------------------------------------------ títulos

    /** 3 = nombre + episodio; 2 = texto que habla de episodio; 0 = no sirve. */
    private static int score(String s) {
        if (s == null) return 0;
        if (NAMED.matcher(s).matches()) return 3;
        if (EPISODE.matcher(s).find()) return 2;
        return 0;
    }

    /** El mejor título de la pantalla: el que trae nombre de serie y episodio. */
    static String titleFromScreen(List<AccessibilityNodeInfo> nodes) {
        String best = null;
        int bestScore = 0;
        for (AccessibilityNodeInfo n : nodes) {
            CharSequence t = n.getText();
            if (t == null) continue;
            String s = t.toString().trim().replaceAll("\\s+", " ");
            if (s.length() < 3 || s.length() > 90 || TIME.matcher(s).matches() || NOISE.matcher(s).find()) continue;
            if (n.isEditable()) continue;
            int sc = score(s);
            if (sc > bestScore) {
                best = s;
                bestScore = sc;
                if (sc == 3) break;
            }
        }
        return best;
    }

    /** Nombre de la serie (para que cada anime tenga su propia tarjeta). */
    static String series(String title) {
        if (title == null || title.isEmpty()) return "";
        Matcher m = NAMED.matcher(title);
        if (m.matches()) return m.group(1).trim();
        String s = title.replaceAll("(?i)\\s*[-–—·:|]?\\s*(episodio|cap[ií]tulo|ep\\.?|episode)\\s*\\d+.*$", "").trim();
        return s.isEmpty() ? title : s;
    }

    // ------------------------------------------------------------ entrada desde el servicio

    /** Lo llama el servicio de automatizaciones cada vez que lee la pantalla de una app. */
    static void onScreen(AccessibilityService svc, String pkg, List<AccessibilityNodeInfo> nodes) {
        if (pkg == null) return;
        long now = SystemClock.uptimeMillis();

        // 1) Recordar el mejor título que se vea, haya sonido o no (el nombre suele salir con el vídeo en pausa).
        String seen = titleFromScreen(nodes);
        if (seen != null) {
            String prev = lastTitle.get(pkg);
            Long prevAt = lastTitleAt.get(pkg);
            boolean fresh = prevAt == null || now - prevAt > REMEMBER_MS;
            if (fresh || score(seen) >= score(prev)) {
                lastTitle.put(pkg, seen);
                lastTitleAt.put(pkg, now);
            }
            // Si ya hay tarjeta de esta app y este título es mejor, se corrige al momento.
            if (score(seen) == 3) {
                final String t = seen;
                worker.execute(() -> improveTitle(svc, pkg, t));
            }
        }

        // 2) Solo con algo reproduciéndose: imagen del momento (como mucho una por minuto y app).
        AudioManager am = (AudioManager) svc.getSystemService(Context.AUDIO_SERVICE);
        if (am == null || !am.isMusicActive()) return;
        Long last = lastShot.get(pkg);
        if (last != null && now - last < SHOT_EVERY_MS) return;
        lastShot.put(pkg, now);

        String title = null, sub = null;
        long pos = -1, dur = -1;
        MediaController c = session(svc, pkg);
        if (c != null) {
            MediaMetadata md = c.getMetadata();
            if (md != null) {
                title = md.getString(MediaMetadata.METADATA_KEY_TITLE);
                if (title == null) title = md.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE);
                sub = md.getString(MediaMetadata.METADATA_KEY_ARTIST);
                dur = md.getLong(MediaMetadata.METADATA_KEY_DURATION);
            }
            PlaybackState st = c.getPlaybackState();
            if (st != null) pos = st.getPosition();
        }
        Long tAt = lastTitleAt.get(pkg);
        String remembered = tAt != null && now - tAt < REMEMBER_MS ? lastTitle.get(pkg) : null;
        if (score(remembered) > score(title)) title = remembered;
        final String fTitle = title, fSub = sub;
        final long fPos = pos, fDur = dur;

        if (Build.VERSION.SDK_INT >= 30) {
            try {
                svc.takeScreenshot(Display.DEFAULT_DISPLAY, worker, new AccessibilityService.TakeScreenshotCallback() {
                    @Override
                    public void onSuccess(AccessibilityService.ScreenshotResult r) {
                        Bitmap frame = null;
                        try {
                            Bitmap hw = Bitmap.wrapHardwareBuffer(r.getHardwareBuffer(), r.getColorSpace());
                            if (hw != null) {
                                Bitmap sw = hw.copy(Bitmap.Config.ARGB_8888, false);
                                frame = Bitmap.createScaledBitmap(sw, 480, 270, true);
                            }
                            r.getHardwareBuffer().close();
                        } catch (Exception ignored) {
                        }
                        save(svc, pkg, fTitle, fSub, fPos, fDur, frame);
                    }

                    @Override
                    public void onFailure(int errorCode) {
                        save(svc, pkg, fTitle, fSub, fPos, fDur, null);
                    }
                });
                return;
            } catch (Exception ignored) {
            }
        }
        worker.execute(() -> save(svc, pkg, fTitle, fSub, fPos, fDur, null));
    }

    private static MediaController session(Context c, String pkg) {
        try {
            MediaSessionManager msm = (MediaSessionManager) c.getSystemService(Context.MEDIA_SESSION_SERVICE);
            for (MediaController mc : msm.getActiveSessions(new ComponentName(c, MediaListener.class))) {
                if (pkg.equals(mc.getPackageName())) return mc;
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    // ------------------------------------------------------------ guardar

    private static boolean black(Bitmap b) {
        long sum = 0;
        int n = 0;
        for (int y = 10; y < b.getHeight(); y += 27) {
            for (int x = 10; x < b.getWidth(); x += 48) {
                int p = b.getPixel(x, y);
                sum += ((p >> 16) & 0xFF) + ((p >> 8) & 0xFF) + (p & 0xFF);
                n++;
            }
        }
        return n == 0 || sum / (n * 3) < 10;
    }

    private static String keyOf(String pkg, String title) {
        return pkg + "|" + series(title).toLowerCase(Locale.ROOT);
    }

    private static JSONArray load(Context c) {
        try {
            SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            if (!p.contains(KEY) && p.contains("items")) {
                // Versión anterior (una tarjeta por app): se conservan, con su clave nueva.
                JSONArray old = new JSONArray(p.getString("items", "[]"));
                for (int i = 0; i < old.length(); i++) {
                    JSONObject o = old.getJSONObject(i);
                    o.put("key", keyOf(o.optString("pkg"), o.optString("title", "")));
                }
                p.edit().putString(KEY, old.toString()).remove("items").apply();
                return old;
            }
            return new JSONArray(p.getString(KEY, "[]"));
        } catch (Exception e) {
            return new JSONArray();
        }
    }

    private static void store(Context c, JSONArray a) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, a.toString()).apply();
    }

    private static synchronized void save(Context c, String pkg, String title, String sub, long pos, long dur, Bitmap frame) {
        try {
            JSONArray old = load(c);
            String key = keyOf(pkg, title);
            JSONObject prev = null;
            for (int i = 0; i < old.length(); i++) {
                JSONObject o = old.getJSONObject(i);
                if (key.equals(o.optString("key"))) prev = o;
            }
            // Sin título nuevo: seguir con la última tarjeta de esa app (mismo anime que se estaba viendo).
            if (title == null) {
                for (int i = 0; i < old.length(); i++) {
                    JSONObject o = old.getJSONObject(i);
                    if (pkg.equals(o.optString("pkg"))) {
                        prev = o;
                        key = o.optString("key");
                        title = o.optString("title", "");
                        break;
                    }
                }
            }
            JSONObject item = new JSONObject();
            item.put("key", key);
            item.put("pkg", pkg);
            item.put("title", title != null ? title : "");
            item.put("sub", sub != null ? sub : "");
            item.put("pos", pos);
            item.put("dur", dur);
            item.put("time", System.currentTimeMillis());
            File dir = new File(c.getFilesDir(), "continue");
            if (!dir.exists()) dir.mkdirs();
            File img = new File(dir, Integer.toHexString(key.hashCode()) + ".jpg");
            if (frame != null && !black(frame)) {
                try (FileOutputStream f = new FileOutputStream(img)) {
                    frame.compress(Bitmap.CompressFormat.JPEG, 82, f);
                }
            }
            String path = img.exists() ? img.getAbsolutePath() : (prev != null ? prev.optString("image", "") : "");
            item.put("image", path);
            JSONArray out = new JSONArray();
            out.put(item);
            for (int i = 0; i < old.length() && out.length() < MAX; i++) {
                JSONObject o = old.getJSONObject(i);
                if (!key.equals(o.optString("key"))) out.put(o);
            }
            store(c, out);
        } catch (Exception ignored) {
        }
    }

    /**
     * Llega un título con nombre de serie: si la tarjeta más reciente de esa app no tenía nombre
     * (o era de esa misma serie con otro episodio), se le pone este.
     */
    private static synchronized void improveTitle(Context c, String pkg, String title) {
        try {
            JSONArray a = load(c);
            String key = keyOf(pkg, title);
            for (int i = 0; i < a.length(); i++) {
                JSONObject o = a.getJSONObject(i);
                if (!pkg.equals(o.optString("pkg"))) continue;
                boolean sameSeries = key.equals(o.optString("key"));
                boolean unnamed = score(o.optString("title", "")) < 3;
                long age = System.currentTimeMillis() - o.optLong("time", 0);
                if ((sameSeries || (unnamed && age < REMEMBER_MS)) && !title.equals(o.optString("title"))) {
                    o.put("title", title);
                    o.put("key", key);
                    // Si ya había otra tarjeta de esa serie, se queda solo esta.
                    JSONArray out = new JSONArray();
                    for (int j = 0; j < a.length(); j++) {
                        JSONObject x = a.getJSONObject(j);
                        if (j == i || !key.equals(x.optString("key"))) out.put(x);
                    }
                    store(c, out);
                }
                return; // solo la más reciente de esa app
            }
        } catch (Exception ignored) {
        }
    }

    // ------------------------------------------------------------ para el inicio

    static List<Map<String, Object>> list(Context c) {
        List<Map<String, Object>> out = new ArrayList<>();
        JSONArray a = load(c);
        for (int i = 0; i < a.length(); i++) {
            try {
                JSONObject o = a.getJSONObject(i);
                String pkg = o.getString("pkg");
                String name;
                try {
                    name = String.valueOf(c.getPackageManager().getApplicationLabel(
                            c.getPackageManager().getApplicationInfo(pkg, 0)));
                } catch (Exception e) {
                    continue; // desinstalada
                }
                Map<String, Object> m = new HashMap<>();
                m.put("package", pkg);
                m.put("app", name);
                m.put("title", o.optString("title", ""));
                m.put("sub", o.optString("sub", ""));
                m.put("pos", o.optLong("pos", -1));
                m.put("dur", o.optLong("dur", -1));
                m.put("time", o.optLong("time", 0));
                String path = o.optString("image", "");
                if (!path.isEmpty() && new File(path).exists()) m.put("image", path);
                out.add(m);
            } catch (Exception ignored) {
            }
        }
        return out;
    }
}
