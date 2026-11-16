/*
 * SG Alfa Home — «Continuar viendo»: mientras algo se reproduce dentro de una app, guarda una imagen
 * del momento y el título que se ve en pantalla (o el que da la propia app), para mostrarlo en el inicio.
 * Todo se queda en el deco; nada sale a internet.
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
import java.util.regex.Pattern;

final class ContinueWatch {
    private static final String PREFS = "sgalfa_continue";
    private static final String KEY = "items";
    private static final int MAX = 8;
    private static final long EVERY_MS = 60_000;

    private static final Map<String, Long> lastShot = new HashMap<>();
    private static final Executor worker = Executors.newSingleThreadExecutor();
    private static final Pattern TIME = Pattern.compile("^[-\\d:\\s/]+$");
    private static final Pattern EPISODE = Pattern.compile(
            "(episodio|cap[ií]tulo|\\bep\\.?\\s*\\d|temporada|season|episode|\\bt\\d+\\s*e\\d+)", Pattern.CASE_INSENSITIVE);

    private ContinueWatch() {
    }

    /** Lo llama el servicio de automatizaciones al leer la pantalla de una app. */
    static void onScreen(AccessibilityService svc, String pkg, List<AccessibilityNodeInfo> nodes) {
        if (pkg == null) return;
        AudioManager am = (AudioManager) svc.getSystemService(Context.AUDIO_SERVICE);
        if (am == null || !am.isMusicActive()) return; // solo si se está reproduciendo algo
        long now = SystemClock.uptimeMillis();
        Long last = lastShot.get(pkg);
        if (last != null && now - last < EVERY_MS) return;
        lastShot.put(pkg, now);

        // Título: el que da la app (si deja verlo) o el que se lee en pantalla.
        String title = null, sub = null;
        long pos = -1, dur = -1;
        MediaController c = session(svc, pkg);
        if (c != null) {
            MediaMetadata md = c.getMetadata();
            if (md != null) {
                title = md.getString(MediaMetadata.METADATA_KEY_TITLE);
                if (title == null) title = md.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE);
                sub = md.getString(MediaMetadata.METADATA_KEY_ARTIST);
                if (sub == null) sub = md.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE);
                dur = md.getLong(MediaMetadata.METADATA_KEY_DURATION);
            }
            PlaybackState st = c.getPlaybackState();
            if (st != null) pos = st.getPosition();
        }
        if (title == null || title.trim().isEmpty()) title = titleFromScreen(nodes);
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
            // sin permiso de «Mostrar lo que suena»: se usa lo que se lee en pantalla
        }
        return null;
    }

    /** El texto que más parece un título: mejor si habla de episodio o capítulo. */
    static String titleFromScreen(List<AccessibilityNodeInfo> nodes) {
        String first = null;
        for (AccessibilityNodeInfo n : nodes) {
            CharSequence t = n.getText();
            if (t == null) continue;
            String s = t.toString().trim().replaceAll("\\s+", " ");
            if (s.length() < 3 || s.length() > 90 || TIME.matcher(s).matches()) continue;
            if (n.isClickable() || n.isEditable()) continue;
            if (EPISODE.matcher(s).find()) return s;
            if (first == null && Character.isLetter(s.charAt(0))) first = s;
        }
        return first;
    }

    /** ¿Imagen casi negra? (apps con contenido protegido): no sirve como portada. */
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

    private static synchronized void save(Context c, String pkg, String title, String sub, long pos, long dur, Bitmap frame) {
        try {
            SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            JSONArray old = new JSONArray(p.getString(KEY, "[]"));
            JSONObject prev = null;
            JSONArray out = new JSONArray();
            for (int i = 0; i < old.length(); i++) {
                JSONObject o = old.getJSONObject(i);
                if (pkg.equals(o.optString("pkg"))) prev = o;
            }
            JSONObject item = new JSONObject();
            item.put("pkg", pkg);
            // No perder un buen título por uno peor (p. ej. cuando el reproductor oculta los textos).
            String keep = prev != null ? prev.optString("title", null) : null;
            item.put("title", title != null ? title : (keep != null ? keep : ""));
            item.put("sub", sub != null ? sub : "");
            item.put("pos", pos);
            item.put("dur", dur);
            item.put("time", System.currentTimeMillis());
            File dir = new File(c.getFilesDir(), "continue");
            if (!dir.exists()) dir.mkdirs();
            File img = new File(dir, pkg + ".jpg");
            if (frame != null && !black(frame)) {
                try (FileOutputStream f = new FileOutputStream(img)) {
                    frame.compress(Bitmap.CompressFormat.JPEG, 82, f);
                }
            }
            item.put("image", img.exists() ? img.getAbsolutePath() : "");
            out.put(item);
            for (int i = 0; i < old.length() && out.length() < MAX; i++) {
                JSONObject o = old.getJSONObject(i);
                if (!pkg.equals(o.optString("pkg"))) out.put(o);
            }
            p.edit().putString(KEY, out.toString()).apply();
        } catch (Exception ignored) {
        }
    }

    /** Para el inicio: lo último visto primero. */
    static List<Map<String, Object>> list(Context c) {
        List<Map<String, Object>> out = new ArrayList<>();
        try {
            JSONArray a = new JSONArray(c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"));
            for (int i = 0; i < a.length(); i++) {
                JSONObject o = a.getJSONObject(i);
                String pkg = o.getString("pkg");
                String name = pkg;
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
            }
        } catch (Exception ignored) {
        }
        return out;
    }

    static String lower(String s) {
        return s == null ? "" : s.toLowerCase(Locale.ROOT);
    }
}
