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
import android.graphics.Rect;
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
    private static final int MAX = 8;
    static final int SHOW = 6; // en el inicio, como mucho 6 tarjetas
    private static final long SHOT_EVERY_MS = 60_000;
    private static final long REMEMBER_MS = 20 * 60_000; // un título visto hace poco vale para lo que se reproduzca

    private static final Map<String, Long> lastShot = new HashMap<>();
    /** Último buen título visto en cada app (aunque no hubiera nada sonando). */
    private static final Map<String, String> lastTitle = new HashMap<>();
    private static final Map<String, Long> lastTitleAt = new HashMap<>();
    private static final Map<String, String> strong = new HashMap<>();
    private static final Executor worker = Executors.newSingleThreadExecutor();

    private static final Pattern TIME = Pattern.compile("^[-\\d:\\s/.]+$");
    private static final Pattern EPISODE = Pattern.compile(
            "(episodio|cap[ií]tulo|\\bep\\.?\\s*\\d|temporada|season|episode|\\bt\\d+\\s*e\\d+)", Pattern.CASE_INSENSITIVE);
    /** «Nombre - Episodio 8», «Nombre · Cap. 3», «Nombre T1 E4»: nombre de la serie + episodio. */
    private static final Pattern NAMED = Pattern.compile(
            "^(.{2,60}?)\\s*[-–—·:|]\\s*((episodio|cap[ií]tulo|ep\\.?|temporada|season|episode|t\\d+).*)$", Pattern.CASE_INSENSITIVE);
    private static final Pattern NOISE = Pattern.compile(
            "(pulsa|presiona|mant[eé]n|cargando|espere|proveedor|comentario|recomi[eé]ndanos|instagram|whatsapp|"
                    + "anuncio|publicidad|siguiente|anterior|reproducir|pausa|ajustes|configuraci|buscar|men[uú]|salir|mir[oó] hasta|ya viste|visto hasta|watched up|actualizaci|notificaci|instalar|update|install|descargar|ver gratis|ver ahora|ver trailer|ver tr[aá]iler|m[aá]s informaci|iniciar sesi|temporadas?\\s*\\||\\|\\s*\\d{4}|alquiler|suscr[ií]b|favorito|mi lista|g[eé]nero)",
            Pattern.CASE_INSENSITIVE);

    private ContinueWatch() {
    }

    // ------------------------------------------------------------ títulos

    /** Pantallas que no son «algo que se ve» (el propio inicio, ajustes, teclado…). */
    private static final java.util.Set<String> SKIP = new java.util.HashSet<>(java.util.Arrays.asList(
            "com.android.systemui", "com.android.tv.settings", "com.android.settings", "com.google.android.inputmethod.latin",
            "com.google.android.tvlauncher", "com.google.android.apps.tv.launcherx", "com.spocky.projengmenu",
            "com.android.packageinstaller", "com.google.android.packageinstaller", "com.google.android.permissioncontroller",
            "com.android.vending", "com.google.android.katniss", "com.google.android.leanbacklauncher",
            // Solo TV en vivo / deportes: no hay películas ni series que continuar.
            "com.rblive.tv", "app.aksports.live", "com.sportzx.live", "com.lite.fczx", "com.kick.mobile",
            "com.apps.livetv", "com.asfmapps.firetv_volume", "org.blokada.origin.alarm"));

    /** Títulos que son canales o transmisiones en vivo (no películas ni series). */
    private static final Pattern LIVE_WORDS = Pattern.compile(
            "(?i)(\\ben vivo\\b|\\blive\\b|\\bhd\\s*\\d*$|\\bfhd\\b|\\b(canal|channel)\\b|\\b24/7\\b|\\bnoticias\\b)");

    /** Apps solo de música: ya salen arriba en «lo que suena», no en «Continuar viendo». */
    static boolean musicOnly(String pkg) {
        return pkg != null && (pkg.startsWith("com.spotify") || pkg.equals("com.google.android.youtube.tvmusic")
                || pkg.startsWith("io.gh.reisxd.tizentube") // TizenTube se usa para música: va en «lo que suena»
                || pkg.equals("com.google.android.apps.youtube.music") || pkg.startsWith("deezer.android")
                || pkg.startsWith("com.amazon.mp3") || pkg.startsWith("com.aspiro.tidal")
                || pkg.startsWith("com.soundcloud") || pkg.startsWith("com.pandora")
                || pkg.startsWith("com.apple.android.music") || pkg.startsWith("tunein.player")
                || pkg.startsWith("radiotime.player") || pkg.startsWith("com.audiomack")
                || pkg.startsWith("com.anghami") || pkg.startsWith("com.iheartradio")
                || pkg.startsWith("com.qobuz") || pkg.startsWith("com.napster"));
    }

    private static final Map<String, Boolean> audioCache = new HashMap<>();

    /** Cualquier reproductor de música: Android lo marca con la categoría «Audio». */
    static boolean audioApp(Context c, String pkg) {
        if (pkg == null || android.os.Build.VERSION.SDK_INT < 26) return false;
        Boolean v = audioCache.get(pkg);
        if (v != null) return v;
        boolean audio = false;
        try {
            audio = c.getPackageManager().getApplicationInfo(pkg, 0).category
                    == android.content.pm.ApplicationInfo.CATEGORY_AUDIO;
        } catch (Exception ignored) {
        }
        audioCache.put(pkg, audio);
        return audio;
    }

    static boolean skip(Context c, String pkg) {
        return pkg == null || pkg.equals(c.getPackageName()) || SKIP.contains(pkg) || musicOnly(pkg)
                || audioApp(c, pkg);
    }

    /**
     * Campos donde los reproductores suelen poner lo que suena: el canal actual de WiwyXuper/XuperHydra
     * (mTvChannel), el título del vídeo, etc. Por orden de preferencia.
     */
    private static final String[] TITLE_IDS = {
            "mTvChannel", "mTvVideoTitle", "mTvVideoName", "mTvMovieName", "mTvMovieTitle", "mTvPlayTitle", "mTvName",
            "video_title", "videoTitle", "movie_title", "player_title", "exo_title", "tv_title", "tvTitle", "title_text"};

    /** ¿Es uno de los campos donde el reproductor pone el título (ya se está viendo)? */
    static boolean isPlayerTitleId(String id) {
        int slash = id.indexOf(":id/");
        String name = slash >= 0 ? id.substring(slash + 4) : id;
        for (String t : TITLE_IDS) if (name.equalsIgnoreCase(t)) return true;
        return false;
    }

    /** Título leído de los campos del reproductor (lo más fiable cuando la app no dice «Episodio»). */
    static String titleFromIds(List<AccessibilityNodeInfo> nodes) {
        String best = null;
        int bestRank = Integer.MAX_VALUE;
        for (AccessibilityNodeInfo n : nodes) {
            String id = n.getViewIdResourceName();
            CharSequence t = n.getText();
            if (id == null || t == null) continue;
            int slash = id.indexOf(":id/");
            String name = slash >= 0 ? id.substring(slash + 4) : id;
            for (int i = 0; i < TITLE_IDS.length && i < bestRank; i++) {
                if (!name.equalsIgnoreCase(TITLE_IDS[i])) continue;
                String s = t.toString().trim().replaceAll("\s+", " ");
                if (s.length() >= 2 && s.length() <= 90 && !TIME.matcher(s).matches()) {
                    best = s;
                    bestRank = i;
                }
            }
        }
        return best;
    }

    /** Lo último que se eligió (pulsó) dentro de cada app: la película, serie o canal que se abrió. */
    private static final Map<String, String> picked = new HashMap<>();
    private static final Map<String, Long> pickedAt = new HashMap<>();

    // ------------------------------------------------------------ Anime Cast al momento

    private static final String ANIMECAST = "csc.app.anime.cast";
    private static volatile String acAnime;      // anime elegido (de su tarjeta)
    private static volatile String acSaved;      // último «Anime - Episodio N» guardado
    private static final Pattern AC_EP = Pattern.compile("(?i)^episodio\\s*(\\d+)$");

    private static String textById(AccessibilityNodeInfo n, String idSuffix, int depth) {
        if (n == null || depth > 12) return null;
        String id = n.getViewIdResourceName();
        if (id != null && id.endsWith(idSuffix) && n.getText() != null) return n.getText().toString().trim();
        for (int i = 0; i < n.getChildCount(); i++) {
            String r = textById(n.getChild(i), idSuffix, depth + 1);
            if (r != null) return r;
        }
        return null;
    }

    /**
     * Anime Cast: al entrar a un episodio se guarda la tarjeta en el acto (antes solo al volver al inicio
     * de la app). El nombre del anime sale de la tarjeta que se tocó; el episodio, de la barra de arriba.
     */
    private static boolean animeCastNow(AccessibilityService svc, String pkg, List<AccessibilityNodeInfo> nodes) {
        if (!ANIMECAST.equals(pkg) || acAnime == null) return false;
        for (AccessibilityNodeInfo n : nodes) {
            CharSequence t = n.getText();
            if (t == null || n.getViewIdResourceName() != null) continue; // el título de la barra no tiene id
            Matcher m = AC_EP.matcher(t.toString().trim());
            if (!m.matches()) continue;
            String title = acAnime + " - Episodio " + m.group(1);
            if (title.equals(acSaved)) return false;
            acSaved = title;
            capture(svc, pkg, title);
            return true;
        }
        return false;
    }

    static void onClick(Context c, String pkg, AccessibilityNodeInfo source, List<CharSequence> eventText) {
        try {
            if (ANIMECAST.equals(pkg) && source != null) {
                String name = textById(source, ":id/episodio_anime", 0);
                if (name == null) name = textById(source, ":id/anime_nombre", 0);
                if (name == null) name = textById(source, ":id/anime_titulo", 0);
                if (name != null && name.length() > 1) acAnime = name;
            }
        } catch (Exception ignored) {
        }
        try {
            if (xuper(pkg) && source != null) {
                String id = source.getViewIdResourceName();
                CharSequence t = source.getText();
                if (t == null && eventText != null && !eventText.isEmpty()) t = eventText.get(0);
                boolean episodeButton = (id != null && id.endsWith(":id/mTextTitle") && t != null && t.toString().trim().matches("\\d{1,4}"))
                        || (t != null && t.toString().trim().matches("\\d{1,4}"));
                if (episodeButton) restartEpisode(pkg);
            }
        } catch (Exception ignored) {
        }
        if (skip(c, pkg)) return;
        String t = null;
        if (source != null) t = firstText(source, 0);
        if (t == null && eventText != null) {
            for (CharSequence x : eventText) {
                if (x != null && good(x.toString())) {
                    t = x.toString().trim();
                    break;
                }
            }
        }
        if (t == null || xuper(pkg)) return;
        picked.put(pkg, t);
        pickedAt.put(pkg, SystemClock.uptimeMillis());
    }

    /** El texto de letra más grande (alto del recuadro) que parezca un título. */
    static String bigTitle(List<AccessibilityNodeInfo> nodes) {
        String best = null;
        int bestH = 0;
        android.graphics.Rect r = new android.graphics.Rect();
        for (AccessibilityNodeInfo n : nodes) {
            CharSequence t = n.getText();
            if (t == null || n.isEditable() || n.isClickable()) continue;
            String s = t.toString().trim().replaceAll("\\s+", " ");
            if (s.length() < 3 || s.length() > 60 || !good(s) || s.split(" ").length > 9) continue;
            n.getBoundsInScreen(r);
            int lines = Math.max(1, n.getMaxTextLength() > 0 ? 1 : 1);
            int h = r.height() / lines;
            if (h > bestH) {
                bestH = h;
                best = s;
            }
        }
        return bestH >= 50 ? best : null; // letra grande de verdad (en 1080p)
    }

    private static boolean good(String s) {
        s = s.trim();
        return s.length() >= 2 && s.length() <= 80 && s.indexOf('|') < 0 && !TIME.matcher(s).matches() && !NOISE.matcher(s).find()
                && Character.isLetterOrDigit(s.codePointAt(0)) && s.chars().anyMatch(Character::isLetter);
    }

    private static String firstText(AccessibilityNodeInfo n, int depth) {
        if (n == null || depth > 5) return null;
        CharSequence t = n.getText();
        if (t != null && good(t.toString())) return t.toString().trim().replaceAll("\s+", " ");
        CharSequence d = n.getContentDescription();
        if (d != null && good(d.toString())) return d.toString().trim();
        for (int i = 0; i < n.getChildCount(); i++) {
            String r = firstText(n.getChild(i), depth + 1);
            if (r != null) return r;
        }
        return null;
    }

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
        // «Serie T7» y «Serie · T7 E2» son la misma serie (una sola tarjeta).
        s = s.replaceAll("(?i)\\s*[-–—·:|]?\\s*T\\d+(\\s*E\\d+)?\\s*$", "").trim();
        return s.isEmpty() ? title : s;
    }

    // ------------------------------------------------------------ entrada desde el servicio

    /** Lo llama el servicio de automatizaciones cada vez que lee la pantalla de una app. */
    // ------------------------------------------------------------ canales en vivo (no van a la lista)

    private static final String LIVE_PREFS = "sgalfa_live_titles";

    /** Canal en vivo del reproductor de WiwyXuper / Xuper Hydra (campo mTvChannel). */
    private static String liveChannel(List<AccessibilityNodeInfo> nodes) {
        for (AccessibilityNodeInfo n : nodes) {
            String id = n.getViewIdResourceName();
            CharSequence t = n.getText();
            if (id != null && t != null && id.endsWith(":id/mTvChannel") && t.toString().trim().length() > 1) {
                return t.toString().trim();
            }
        }
        return null;
    }

    private static final Pattern RANGE = Pattern.compile("^(\\d+)\\s*-\\s*(\\d+)$");

    /**
     * Ficha de serie de WiwyXuper: «Historias corrientes» (mTextTitle) + «Temporada 7» (tvSeanson) +
     * el episodio que se reproduce (su botón muestra ▶ en vez del número). → «Historias corrientes · T7 E1».
     */
    static String xuperEpisode(List<AccessibilityNodeInfo> nodes) {
        String name = null, season = null;
        java.util.TreeSet<Integer> nums = new java.util.TreeSet<>();
        List<int[]> ranges = new ArrayList<>();
        for (AccessibilityNodeInfo n : nodes) {
            String id = n.getViewIdResourceName();
            CharSequence cs = n.getText();
            if (id == null || cs == null) continue;
            String t = cs.toString().trim();
            if (id.endsWith(":id/tvSeanson")) {
                Matcher m = Pattern.compile("(\\d+)").matcher(t);
                if (m.find()) season = m.group(1);
            } else if (id.endsWith(":id/mTextTitle")) {
                Matcher r = RANGE.matcher(t);
                if (r.matches()) {
                    ranges.add(new int[]{Integer.parseInt(r.group(1)), Integer.parseInt(r.group(2))});
                } else if (t.matches("\\d{1,4}")) {
                    nums.add(Integer.parseInt(t));
                } else if (name == null && t.length() > 1) {
                    name = t;
                }
            }
        }
        if (name == null || season == null) return null;
        String ep = null;
        if (!nums.isEmpty()) {
            // El que suena muestra ▶ en vez de su número: es el hueco entre los números que se ven
            // (p. ej. 61 62 63 64 ▶ 66 → 65). Solo dentro de lo visible; los bloques 1-20, 61-80…
            // sirven para el caso en que el ▶ es el primero o el último del bloque.
            int first = nums.first(), last = nums.last();
            for (int i = first + 1; i < last; i++) {
                if (!nums.contains(i)) {
                    ep = String.valueOf(i);
                    break;
                }
            }
            if (ep == null) {
                for (int[] r : ranges) {
                    if (first == r[0] + 1 && first <= r[1]) {
                        ep = String.valueOf(r[0]);
                        break;
                    }
                    if (last == r[1] - 1 && last >= r[0] && last - first + 2 == r[1] - r[0] + 1) {
                        ep = String.valueOf(r[1]); // bloque entero a la vista y el ▶ es el último
                        break;
                    }
                }
            }
        }
        return name + " · T" + season + (ep != null ? " E" + ep : "");
    }

    // ------------------------------------------------------------ minuto aproximado (WiwyXuper / Hydra)

    private static final String WATCH_PREFS = "sgalfa_watch_ms";

    private static boolean xuper(String pkg) {
        return pkg != null && (pkg.startsWith("com.xuper.") || pkg.equals("com.android.mgstv") || pkg.contains("hydra") || pkg.contains("xuper"));
    }

    /**
     * Su reproductor no dice por dónde va. Se cuenta el tiempo que el capítulo lleva sonando
     * (mientras la app está delante y hay sonido) para mostrar «Ibas por el min ~12».
     */
    private static final java.util.Set<String> restart = java.util.Collections.synchronizedSet(new java.util.HashSet<>());

    /** El capítulo vuelve a empezar (se tocó su número o se abrió desde la tarjeta): el minuto vuelve a 0. */
    static void restartEpisode(String pkg) {
        if (xuper(pkg)) restart.add(pkg);
    }

    static void tick(Context c, String pkg, long ms) {
        if (!xuper(pkg)) return;
        String title = strong.get(pkg);
        if (title == null || !EP_IN_TITLE.matcher(title).find()) return;
        android.os.PowerManager pm = (android.os.PowerManager) c.getSystemService(Context.POWER_SERVICE);
        if (pm != null && !pm.isInteractive()) return; // pantalla apagada: no cuenta
        android.content.SharedPreferences p = c.getSharedPreferences(WATCH_PREFS, Context.MODE_PRIVATE);
        String k = pkg + "|" + title;
        android.content.SharedPreferences.Editor e = p.edit();
        if (p.getAll().size() > 300) e.clear();
        // Cuenta desde que empieza cada capítulo: si cambió de capítulo o se volvió a empezar, desde 0.
        boolean fresh = !title.equals(p.getString("last|" + pkg, null)) || restart.remove(pkg);
        long base = fresh ? 0 : p.getLong(k, 0);
        e.putString("last|" + pkg, title).putLong(k, base + ms).apply();
    }

    private static final Pattern EP_IN_TITLE = Pattern.compile("(?i)\\bT\\d+\\s*E\\d+");

    static long watchedMs(Context c, String pkg, String title) {
        if (!xuper(pkg) || title == null) return 0;
        return c.getSharedPreferences(WATCH_PREFS, Context.MODE_PRIVATE).getLong(pkg + "|" + title, 0);
    }

    static boolean isLive(Context c, String title) {
        if (title == null) return false;
        return c.getSharedPreferences(LIVE_PREFS, Context.MODE_PRIVATE).contains(Macros.normalize(title));
    }

    private static void markLive(Context c, String title) {
        android.content.SharedPreferences p = c.getSharedPreferences(LIVE_PREFS, Context.MODE_PRIVATE);
        String k = Macros.normalize(title);
        if (k.isEmpty() || p.contains(k)) return;
        android.content.SharedPreferences.Editor e = p.edit();
        if (p.getAll().size() > 300) e.clear();
        e.putBoolean(k, true).apply();
    }

    private static final Map<String, String> xuperSaved = new HashMap<>();
    private static final Map<String, Long> soundAt = new HashMap<>();

    /**
     * Se salió de una app (se abrió otra o el inicio). Si en ella sonaba algo hace poco, se guarda
     * ya lo que se estaba viendo: la tarjeta aparece al instante en el inicio.
     */
    static void onLeave(AccessibilityService svc, String pkg) {
        if (pkg == null || skip(svc, pkg) || xuper(pkg) || ANIMECAST.equals(pkg)) return;
        Long at = soundAt.get(pkg);
        long now = SystemClock.uptimeMillis();
        if (at == null || now - at > 3 * 60_000) return;
        Long tAt = lastTitleAt.get(pkg);
        String title = tAt != null && now - tAt < REMEMBER_MS ? lastTitle.get(pkg) : null;
        if (title == null) title = strong.get(pkg);
        if (title == null) {
            Long pAt = pickedAt.get(pkg);
            if (pAt != null && now - pAt < 30 * 60_000) title = picked.get(pkg);
        }
        if (title == null || LIVE_WORDS.matcher(title).find() || isLive(svc, title)) return;
        final String t = title;
        lastShot.remove(pkg);
        worker.execute(() -> save(svc, pkg, t, null, -1, -1, null));
    }

    /** Guarda la tarjeta con una imagen del momento (si se puede). */
    private static void capture(AccessibilityService svc, String pkg, String title) {
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
                        save(svc, pkg, title, null, -1, -1, frame);
                    }

                    @Override
                    public void onFailure(int errorCode) {
                        save(svc, pkg, title, null, -1, -1, null);
                    }
                });
                return;
            } catch (Exception ignored) {
            }
        }
        worker.execute(() -> save(svc, pkg, title, null, -1, -1, null));
    }

    static void onScreen(AccessibilityService svc, String pkg, List<AccessibilityNodeInfo> nodes) {
        if (skip(svc, pkg)) return;
        // Viendo un canal en vivo: no es «continuar viendo» (solo series y películas). Se recuerda el
        // nombre del canal para no guardarlo tampoco por otras vías (sesión multimedia, otra app Xuper).
        String live = liveChannel(nodes);
        if (live != null) {
            markLive(svc, live);
            lastTitle.remove(pkg);
            strong.remove(pkg);
            return;
        }
        // Anime Cast dentro de un episodio: guardar ya, sin esperar a volver a su inicio.
        if (animeCastNow(svc, pkg, nodes)) return;
        // La propia app tiene su lista de «Continuar viendo» (Anime Cast): se lee tal cual.
        if (importList(svc, pkg, nodes)) return;
        long now = SystemClock.uptimeMillis();

        // WiwyXuper / Xuper Hydra: solo vale la ficha de la serie con temporada y episodio.
        // Avisos, notificaciones, historial y menús de la app se ignoran (eran los títulos raros).
        if (xuper(pkg)) {
            String ep = xuperEpisode(nodes);
            if (ep != null && !EP_IN_TITLE.matcher(ep).find()) {
                String prev = strong.get(pkg);
                ep = prev != null && prev.startsWith(ep + " E") ? prev : null; // mismo capítulo de antes
            }
            if (ep == null) return;
            strong.put(pkg, ep);
            lastTitle.put(pkg, ep);
            lastTitleAt.put(pkg, now);
            Long lastX = lastShot.get(pkg);
            if (lastX != null && now - lastX < SHOT_EVERY_MS && ep.equals(xuperSaved.get(pkg))) return;
            lastShot.put(pkg, now);
            xuperSaved.put(pkg, ep);
            capture(svc, pkg, ep);
            return;
        }

        // 0) Título de los campos del reproductor (canal o vídeo actual): el más fiable.
        //    En WiwyXuper/Hydra la ficha de la serie da nombre, temporada y episodio por separado.
        String fromIds = xuperEpisode(nodes);
        if (fromIds != null && !EP_IN_TITLE.matcher(fromIds).find()) {
            String prev = strong.get(pkg);
            if (prev != null && prev.startsWith(fromIds + " E")) fromIds = prev; // mismo capítulo de antes
        }
        if (fromIds == null) fromIds = titleFromIds(nodes);
        if (fromIds != null) {
            lastTitle.put(pkg, fromIds);
            lastTitleAt.put(pkg, now);
            strong.put(pkg, fromIds);
            final String t0 = fromIds;
            worker.execute(() -> nameUnnamed(svc, pkg, t0));
        }
        // 1) Recordar el mejor título que se vea, haya sonido o no (el nombre suele salir con el vídeo en pausa).
        String seen = titleFromScreen(nodes);
        // Sin «Episodio» en pantalla: el texto más grande (el nombre de la película o serie en su ficha).
        if (seen == null) {
            String big = bigTitle(nodes);
            if (big != null) {
                lastTitle.put(pkg, big);
                lastTitleAt.put(pkg, now);
            }
        }
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
        soundAt.put(pkg, now);
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
        // Si la app dice qué suena (TizenTube, YouTube…), eso manda: lo leído en pantalla puede ser
        // el vídeo anterior. Lo de pantalla solo se usa si la sesión no trae un título útil.
        if (!sessionTitle(svc, pkg, title) && score(remembered) > score(title)) title = remembered;
        // Sin «Episodio»: el canal o vídeo del reproductor, o lo que se eligió en la app hace poco.
        if (title == null || title.trim().isEmpty()) {
            String s = tAt != null && now - tAt < REMEMBER_MS ? strong.get(pkg) : null;
            if (s == null) {
                Long pAt = pickedAt.get(pkg);
                if (pAt != null && now - pAt < 30 * 60_000) s = picked.get(pkg);
            }
            title = s;
        }
        if (title == null) title = remembered; // el título grande de la ficha
        if (title != null && LIVE_WORDS.matcher(title).find()) return; // canal en vivo: no
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

    /** ¿Es un título de verdad (no vacío ni el nombre de la app)? */
    static boolean sessionTitle(Context c, String pkg, String title) {
        if (title == null || !good(title)) return false;
        try {
            android.content.pm.PackageManager pm = c.getPackageManager();
            String label = String.valueOf(pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0))).trim();
            if (title.trim().equalsIgnoreCase(label)) return false;
        } catch (Exception ignored) {
        }
        return true;
    }

    /**
     * Lo llama MediaListener cuando una app cambia de canción o vídeo, aunque no haya eventos en
     * pantalla: la tarjeta pasa al momento al vídeo nuevo (la imagen llega con la siguiente captura).
     */
    static void onMedia(Context c, String pkg, String title, String sub, long pos, long dur) {
        if (skip(c, pkg) || !sessionTitle(c, pkg, title) || isLive(c, title)) return;
        worker.execute(() -> save(c, pkg, title, sub, pos, dur, null));
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

    /** Como mucho las 2 últimas de cada app (la lista ya viene de más reciente a más antigua). */
    static final int PER_APP = 2;

    /** Quitar una tarjeta (mantener OK en el inicio). */
    static synchronized void remove(Context c, String pkg, String title) {
        try {
            JSONArray old = load(c), out = new JSONArray();
            String t = title == null ? "" : title.trim();
            for (int i = 0; i < old.length(); i++) {
                JSONObject o = old.getJSONObject(i);
                if (pkg.equals(o.optString("pkg")) && t.equals(o.optString("title", "").trim())) continue;
                out.put(o);
            }
            store(c, out);
        } catch (Exception ignored) {
        }
    }

    private static void store(Context c, JSONArray a) {
        JSONArray out = new JSONArray();
        Map<String, Integer> count = new HashMap<>();
        for (int i = 0; i < a.length(); i++) {
            JSONObject o = a.optJSONObject(i);
            if (o == null) continue;
            String pkg = o.optString("pkg");
            int n = count.containsKey(pkg) ? count.get(pkg) : 0;
            if (n >= PER_APP) continue;
            count.put(pkg, n + 1);
            out.put(o);
        }
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, out.toString()).apply();
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
            // Misma serie pero sin episodio (p. ej. «Serie T7»): conservar el episodio que ya se sabía.
            if (prev != null && title != null && !EP_IN_TITLE.matcher(title).find()
                    && EP_IN_TITLE.matcher(prev.optString("title", "")).find()) {
                title = prev.optString("title");
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

    private static synchronized void nameUnnamed(Context c, String pkg, String title) {
        try {
            JSONArray a = load(c);
            for (int i = 0; i < a.length(); i++) {
                JSONObject o = a.getJSONObject(i);
                if (!pkg.equals(o.optString("pkg"))) continue;
                if (o.optString("title", "").trim().isEmpty()
                        && System.currentTimeMillis() - o.optLong("time", 0) < REMEMBER_MS) {
                    o.put("title", title);
                    o.put("key", keyOf(pkg, title));
                    store(c, a);
                }
                return;
            }
        } catch (Exception ignored) {
        }
    }

    // ------------------------------------------------------------ lista propia de la app

    private static final Map<String, Long> lastImport = new HashMap<>();
    private static final Pattern CLOCK = Pattern.compile("^(\\d{1,2}):(\\d{2})(?::(\\d{2}))?$");

    private static final class Card {
        String series, episode;
        long pos = -1, dur = -1;
        final Rect r = new Rect();
    }

    private static long ms(CharSequence t) {
        if (t == null) return -1;
        Matcher m = CLOCK.matcher(t.toString().trim());
        if (!m.matches()) return -1;
        long a = Long.parseLong(m.group(1)), b = Long.parseLong(m.group(2));
        long secs = m.group(3) == null ? a * 60 + b : a * 3600 + b * 60 + Long.parseLong(m.group(3));
        return secs * 1000;
    }

    private static boolean idIs(AccessibilityNodeInfo n, String id) {
        String v = n.getViewIdResourceName();
        return v != null && v.endsWith(":id/" + id);
    }

    /**
     * Lee las tarjetas de «Continuar viendo» que la app enseña en su inicio (nombre del anime,
     * episodio y tiempo visto) y recorta de la pantalla la imagen de cada una.
     */
    static boolean importList(AccessibilityService svc, String pkg, List<AccessibilityNodeInfo> nodes) {
        List<AccessibilityNodeInfo> names = new ArrayList<>(), eps = new ArrayList<>(),
                seen = new ArrayList<>(), total = new ArrayList<>();
        for (AccessibilityNodeInfo n : nodes) {
            if (idIs(n, "episodio_anime")) names.add(n);
            else if (idIs(n, "episodio_nombre")) eps.add(n);
            else if (idIs(n, "episodio_tiempo_visto")) seen.add(n);
            else if (idIs(n, "episodio_tiempo_total")) total.add(n);
        }
        if (names.isEmpty()) return false;
        final List<Card> cards = new ArrayList<>();
        java.util.Set<String> done = new java.util.HashSet<>();
        Rect b = new Rect();
        for (AccessibilityNodeInfo nm : names) {
            CharSequence t = nm.getText();
            if (t == null) continue;
            Card c = new Card();
            c.series = t.toString().trim();
            nm.getBoundsInScreen(c.r);
            int bottom = c.r.bottom;
            for (int g = 0; g < 3; g++) {
                List<AccessibilityNodeInfo> group = g == 0 ? eps : (g == 1 ? seen : total);
                for (AccessibilityNodeInfo x : group) {
                    x.getBoundsInScreen(b);
                    if (b.centerX() < c.r.left || b.centerX() > c.r.right || b.top < c.r.top) continue;
                    if (g == 0) c.episode = x.getText() == null ? null : x.getText().toString().trim();
                    else if (g == 1) c.pos = ms(x.getText());
                    else c.dur = ms(x.getText());
                    bottom = Math.max(bottom, b.bottom);
                    break;
                }
            }
            c.r.bottom = bottom + 26; // incluye la barrita de progreso
            if (c.series.isEmpty() || !done.add(c.series.toLowerCase(Locale.ROOT))) continue; // una por anime
            cards.add(c);
        }
        if (cards.isEmpty()) return true;
        long now = SystemClock.uptimeMillis();
        Long li = lastImport.get(pkg);
        boolean shot = li == null || now - li > 5 * 60_000;
        if (shot && Build.VERSION.SDK_INT >= 30) {
            lastImport.put(pkg, now);
            try {
                svc.takeScreenshot(Display.DEFAULT_DISPLAY, worker, new AccessibilityService.TakeScreenshotCallback() {
                    @Override
                    public void onSuccess(AccessibilityService.ScreenshotResult res) {
                        Bitmap full = null;
                        try {
                            Bitmap hw = Bitmap.wrapHardwareBuffer(res.getHardwareBuffer(), res.getColorSpace());
                            if (hw != null) full = hw.copy(Bitmap.Config.ARGB_8888, false);
                            res.getHardwareBuffer().close();
                        } catch (Exception ignored) {
                        }
                        saveImported(svc, pkg, cards, full);
                    }

                    @Override
                    public void onFailure(int errorCode) {
                        saveImported(svc, pkg, cards, null);
                    }
                });
                return true;
            } catch (Exception ignored) {
            }
        }
        worker.execute(() -> saveImported(svc, pkg, cards, null));
        return true;
    }

    private static synchronized void saveImported(Context ctx, String pkg, List<Card> cards, Bitmap full) {
        try {
            JSONArray old = load(ctx);
            Map<String, JSONObject> byKey = new HashMap<>();
            for (int i = 0; i < old.length(); i++) {
                JSONObject o = old.getJSONObject(i);
                byKey.put(o.optString("key"), o);
            }
            File dir = new File(ctx.getFilesDir(), "continue");
            if (!dir.exists()) dir.mkdirs();
            JSONArray out = new JSONArray();
            java.util.Set<String> keys = new java.util.HashSet<>();
            long t0 = System.currentTimeMillis();
            boolean changed = false;
            for (int i = 0; i < cards.size(); i++) {
                Card c = cards.get(i);
                String title = c.episode == null || c.episode.isEmpty() ? c.series : c.series + " - " + c.episode;
                String key = pkg + "|" + c.series.toLowerCase(Locale.ROOT);
                keys.add(key);
                JSONObject prev = byKey.get(key);
                JSONObject item = new JSONObject();
                item.put("key", key);
                item.put("pkg", pkg);
                item.put("title", title);
                item.put("sub", "");
                item.put("pos", c.pos);
                item.put("dur", c.dur);
                item.put("time", t0 - i);
                File img = new File(dir, Integer.toHexString(key.hashCode()) + ".jpg");
                if (full != null) {
                    Rect r = new Rect(c.r);
                    if (r.intersect(0, 0, full.getWidth(), full.getHeight()) && r.width() > 40 && r.height() > 40) {
                        Bitmap crop = Bitmap.createBitmap(full, r.left, r.top, r.width(), r.height());
                        Bitmap small = Bitmap.createScaledBitmap(crop, 480, Math.max(1, 480 * r.height() / r.width()), true);
                        try (FileOutputStream f = new FileOutputStream(img)) {
                            small.compress(Bitmap.CompressFormat.JPEG, 85, f);
                        }
                        changed = true;
                    }
                }
                item.put("image", img.exists() ? img.getAbsolutePath() : (prev != null ? prev.optString("image", "") : ""));
                if (prev == null || !title.equals(prev.optString("title")) || c.pos != prev.optLong("pos", -2)) changed = true;
                out.put(item);
            }
            // Las tarjetas sin nombre de esta app (capturadas antes) sobran: ya están las de su lista.
            for (int i = 0; i < old.length() && out.length() < MAX; i++) {
                JSONObject o = old.getJSONObject(i);
                if (keys.contains(o.optString("key"))) continue;
                if (pkg.equals(o.optString("pkg")) && score(o.optString("title", "")) < 3) {
                    changed = true;
                    continue;
                }
                out.put(o);
            }
            if (changed) store(ctx, out);
        } catch (Exception ignored) {
        }
    }

    // ------------------------------------------------------------ para el inicio

    static List<Map<String, Object>> list(Context c) {
        List<Map<String, Object>> out = new ArrayList<>();
        Map<String, Integer> perApp = new HashMap<>();
        java.util.Set<String> seenSeries = new java.util.HashSet<>();
        JSONArray a = load(c);
        for (int i = 0; i < a.length() && out.size() < SHOW; i++) {
            try {
                JSONObject o = a.getJSONObject(i);
                String pkg = o.getString("pkg");
                if (skip(c, pkg) || o.optString("title", "").trim().isEmpty()) continue;
                if (isLive(c, o.optString("title", ""))) continue; // canal en vivo: fuera
                if (NOISE.matcher(o.optString("title", "")).find()) continue; // texto de la app, no un título
                if (xuper(pkg) && !EP_IN_TITLE.matcher(o.optString("title", "")).find()) continue; // sin episodio: dudosa
                // Una sola tarjeta por serie (la más reciente).
                if (!seenSeries.add(pkg + "|" + series(o.optString("title", "")).toLowerCase(Locale.ROOT))) continue;
                int n = perApp.containsKey(pkg) ? perApp.get(pkg) : 0;
                if (n >= PER_APP) continue;
                perApp.put(pkg, n + 1);
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
                String shown = o.optString("title", "");
                // Si esta (la más reciente) no trae episodio y otra más vieja de la misma serie sí, usar esa.
                if (!EP_IN_TITLE.matcher(shown).find()) {
                    String ser = series(shown).toLowerCase(Locale.ROOT);
                    for (int j = i + 1; j < a.length(); j++) {
                        JSONObject x = a.optJSONObject(j);
                        if (x == null || !pkg.equals(x.optString("pkg"))) continue;
                        String t2 = x.optString("title", "");
                        if (EP_IN_TITLE.matcher(t2).find() && series(t2).toLowerCase(Locale.ROOT).equals(ser)) {
                            shown = t2;
                            break;
                        }
                    }
                }
                m.put("title", shown);
                m.put("sub", o.optString("sub", ""));
                m.put("pos", o.optLong("pos", -1));
                long approx = watchedMs(c, pkg, String.valueOf(m.get("title")));
                if (approx >= 60_000) m.put("approxMin", (int) (approx / 60_000));
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
