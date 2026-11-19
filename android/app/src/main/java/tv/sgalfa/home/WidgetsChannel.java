/*
 * SG Alfa Home — datos de los widgets del inicio: apps vistas hace poco («Continuar viendo»),
 * lo que está sonando (música o vídeo) y sus botones.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.app.Activity;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.media.MediaMetadata;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.media.session.PlaybackState;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

public final class WidgetsChannel {
    public static final String CHANNEL = "tv.sgalfa.home/widgets";

    private final Activity activity;
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private String lastArtKey;
    private byte[] lastArt;

    public WidgetsChannel(Activity activity) {
        this.activity = activity;
    }

    public void register(BinaryMessenger messenger) {
        new MethodChannel(messenger, CHANNEL).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "recentApps":
                    io.execute(() -> {
                        List<Map<String, Object>> r = recentApps(8);
                        main.post(() -> result.success(r));
                    });
                    break;
                case "continueWatching":
                    io.execute(() -> {
                        List<Map<String, Object>> r = ContinueWatch.list(activity);
                        main.post(() -> result.success(r));
                    });
                    break;
                case "media":
                    io.execute(() -> {
                        Map<String, Object> m = media();
                        main.post(() -> result.success(m));
                    });
                    break;
                case "mediaCmd": {
                    String cmd = call.arguments();
                    MediaController c = controller();
                    if (c == null || c.getMetadata() == null) {
                        // Nada sonando: si hay una canción guardada (p. ej. TizenTube se pausó al salir),
                        // cualquier botón vuelve a abrir esa app para seguir escuchando.
                        boolean ok = resumeLast();
                        if (ok || c == null) {
                            result.success(ok);
                            break;
                        }
                    }
                    {
                        MediaController.TransportControls t = c.getTransportControls();
                        PlaybackState st = c.getPlaybackState();
                        boolean playing = st != null && st.getState() == PlaybackState.STATE_PLAYING;
                        if ("prev".equals(cmd)) t.skipToPrevious();
                        else if ("next".equals(cmd)) t.skipToNext();
                        else if (playing) t.pause();
                        else t.play();
                    }
                    result.success(c != null);
                    break;
                }
                case "tvInputs":
                    io.execute(() -> {
                        List<Map<String, Object>> r = tvInputs();
                        main.post(() -> result.success(r));
                    });
                    break;
                case "openInput":
                    result.success(openInput(call.arguments()));
                    break;
                case "openMediaAccess":
                    try {
                        activity.startActivity(new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                        result.success(true);
                    } catch (Exception e) {
                        try {
                            activity.startActivity(new Intent(Settings.ACTION_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                        } catch (Exception ignored) {
                        }
                        android.widget.Toast.makeText(activity,
                                "Ve a Aplicaciones → Acceso especial → Acceso a notificaciones → «SG Alfa · Sonando ahora»",
                                android.widget.Toast.LENGTH_LONG).show();
                        result.success(false);
                    }
                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    // ------------------------------------------------------------ entradas de la tele

    /** HDMI, AV, antena… tal como las tiene esta tele (en decos no hay ninguna). */
    private List<Map<String, Object>> tvInputs() {
        List<Map<String, Object>> out = new ArrayList<>();
        try {
            android.media.tv.TvInputManager tim =
                    (android.media.tv.TvInputManager) activity.getSystemService(Context.TV_INPUT_SERVICE);
            if (tim == null) return out;
            List<android.media.tv.TvInputInfo> list = new ArrayList<>(tim.getTvInputList());
            list.sort((a, b) -> Integer.compare(order(a.getType()), order(b.getType())) != 0
                    ? Integer.compare(order(a.getType()), order(b.getType())) : a.getId().compareTo(b.getId()));
            int hdmi = 0;
            for (android.media.tv.TvInputInfo info : list) {
                if (info.isHidden(activity)) continue;
                int type = info.getType();
                String label = String.valueOf(info.loadLabel(activity)).trim();
                String name;
                switch (type) {
                    case android.media.tv.TvInputInfo.TYPE_HDMI:
                        hdmi++;
                        name = label.toUpperCase(java.util.Locale.ROOT).startsWith("HDMI") ? label : "HDMI " + hdmi;
                        break;
                    case android.media.tv.TvInputInfo.TYPE_COMPOSITE:
                        name = "AV";
                        break;
                    case android.media.tv.TvInputInfo.TYPE_COMPONENT:
                        name = "Componente";
                        break;
                    case android.media.tv.TvInputInfo.TYPE_VGA:
                        name = "VGA (PC)";
                        break;
                    case android.media.tv.TvInputInfo.TYPE_TUNER:
                        String id = info.getId().toLowerCase(java.util.Locale.ROOT);
                        name = id.contains("atv") ? "TV analógica" : (id.contains("dtv") || id.contains("isdb") || id.contains("atsc") ? "TV digital" : (label.isEmpty() ? "TV" : label));
                        break;
                    default:
                        name = label.isEmpty() ? "Entrada" : label;
                }
                Map<String, Object> m = new HashMap<>();
                m.put("id", info.getId());
                m.put("name", name);
                m.put("type", type);
                m.put("passthrough", info.isPassthroughInput());
                int st = 0;
                try {
                    st = tim.getInputState(info.getId());
                } catch (Exception ignored) {
                }
                m.put("state", st); // 0 conectada · 1 en espera · 2 desconectada
                out.add(m);
            }
        } catch (Exception ignored) {
        }
        return out;
    }

    private static int order(int type) {
        switch (type) {
            case android.media.tv.TvInputInfo.TYPE_TUNER: return 0;
            case android.media.tv.TvInputInfo.TYPE_HDMI: return 1;
            case android.media.tv.TvInputInfo.TYPE_COMPOSITE: return 2;
            default: return 3;
        }
    }

    private boolean openInput(String id) {
        if (id == null) return false;
        try {
            android.media.tv.TvInputManager tim =
                    (android.media.tv.TvInputManager) activity.getSystemService(Context.TV_INPUT_SERVICE);
            android.media.tv.TvInputInfo info = tim != null ? tim.getTvInputInfo(id) : null;
            android.net.Uri uri = info != null && info.isPassthroughInput()
                    ? android.media.tv.TvContract.buildChannelUriForPassthroughInput(id)
                    : android.media.tv.TvContract.buildChannelsUriForInput(id);
            activity.startActivity(new Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            return true;
        } catch (Exception e) {
            // Antena sin app que acepte el enlace: abrir la app de TV de la tele.
            for (String pkg : new String[]{"com.apps.livetv", "com.google.android.tv", "com.android.tv"}) {
                Intent i = activity.getPackageManager().getLeanbackLaunchIntentForPackage(pkg);
                if (i == null) i = activity.getPackageManager().getLaunchIntentForPackage(pkg);
                if (i != null) {
                    activity.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                    return true;
                }
            }
            return false;
        }
    }

    // ------------------------------------------------------------ continuar viendo

    private Set<String> skip() {
        Set<String> out = new HashSet<>();
        Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        for (ResolveInfo r : activity.getPackageManager().queryIntentActivities(home, 0)) {
            out.add(r.activityInfo.packageName);
        }
        out.add(activity.getPackageName());
        out.add("com.android.tv.settings");
        out.add("com.android.settings");
        out.add("com.android.systemui");
        out.add("com.google.android.permissioncontroller");
        out.add("com.android.packageinstaller");
        out.add("com.google.android.packageinstaller");
        return out;
    }

    /** Últimas apps abiertas (más reciente primero), con los minutos de uso de hoy. */
    private List<Map<String, Object>> recentApps(int max) {
        List<Map<String, Object>> out = new ArrayList<>();
        UsageStatsManager usm = (UsageStatsManager) activity.getSystemService(Context.USAGE_STATS_SERVICE);
        if (usm == null) return out;
        long now = System.currentTimeMillis();
        Set<String> skip = skip();
        PackageManager pm = activity.getPackageManager();
        LinkedHashMap<String, Long> last = new LinkedHashMap<>();
        try {
            UsageEvents ev = usm.queryEvents(now - 7L * 24 * 3600 * 1000, now);
            UsageEvents.Event e = new UsageEvents.Event();
            while (ev != null && ev.hasNextEvent()) {
                ev.getNextEvent(e);
                if (e.getEventType() != UsageEvents.Event.MOVE_TO_FOREGROUND) continue;
                String p = e.getPackageName();
                if (p == null || skip.contains(p)) continue;
                last.remove(p);
                last.put(p, e.getTimeStamp());
            }
        } catch (Exception ignored) {
        }
        Map<String, Long> todayMs = new HashMap<>();
        try {
            Calendar c = Calendar.getInstance();
            c.set(Calendar.HOUR_OF_DAY, 0);
            c.set(Calendar.MINUTE, 0);
            c.set(Calendar.SECOND, 0);
            for (UsageStats s : usm.queryAndAggregateUsageStats(c.getTimeInMillis(), now).values()) {
                todayMs.put(s.getPackageName(), s.getTotalTimeInForeground());
            }
        } catch (Exception ignored) {
        }
        List<String> order = new ArrayList<>(last.keySet());
        for (int i = order.size() - 1; i >= 0 && out.size() < max; i--) {
            String p = order.get(i);
            if (pm.getLaunchIntentForPackage(p) == null && pm.getLeanbackLaunchIntentForPackage(p) == null) continue;
            String name = p;
            try {
                name = String.valueOf(pm.getApplicationLabel(pm.getApplicationInfo(p, 0)));
            } catch (Exception ignored) {
                continue; // desinstalada
            }
            Map<String, Object> m = new HashMap<>();
            m.put("package", p);
            m.put("name", name);
            m.put("lastUsed", last.get(p));
            Long t = todayMs.get(p);
            m.put("minutesToday", t == null ? 0 : (int) (t / 60000));
            out.add(m);
        }
        return out;
    }

    // ------------------------------------------------------------ lo que suena

    private MediaController controller() {
        try {
            MediaSessionManager msm = (MediaSessionManager) activity.getSystemService(Context.MEDIA_SESSION_SERVICE);
            List<MediaController> list = msm.getActiveSessions(new ComponentName(activity, MediaListener.class));
            MediaController first = null;
            for (MediaController c : list) {
                // Las entradas de la tele (HDMI, antena) y el Bluetooth dejan sesiones «reproduciendo»
                // que no son música: no deben tapar lo que suena de verdad.
                String pkg = c.getPackageName();
                if ("com.apps.livetv".equals(pkg) || "com.android.bluetooth".equals(pkg)
                        || "com.android.tv".equals(pkg) || "com.google.android.tv".equals(pkg)) continue;
                if (first == null) first = c;
                PlaybackState st = c.getPlaybackState();
                if (st != null && st.getState() == PlaybackState.STATE_PLAYING) return c;
            }
            return first;
        } catch (SecurityException e) {
            return null;
        } catch (Exception e) {
            return null;
        }
    }

    private boolean hasAccess() {
        String l = Settings.Secure.getString(activity.getContentResolver(), "enabled_notification_listeners");
        return l != null && l.contains(activity.getPackageName() + "/");
    }

    private Map<String, Object> media() {
        Map<String, Object> m = new HashMap<>();
        boolean access = hasAccess();
        m.put("access", access);
        if (!access) return m;
        MediaController c = controller();
        if (c == null || c.getMetadata() == null) return lastMedia(m);
        MediaMetadata md = c.getMetadata();
        PlaybackState st = c.getPlaybackState();
        m.put("package", c.getPackageName());
        if (md != null) {
            String title = md.getString(MediaMetadata.METADATA_KEY_TITLE);
            if (title == null) title = md.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE);
            String artist = md.getString(MediaMetadata.METADATA_KEY_ARTIST);
            if (artist == null) artist = md.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE);
            if (artist == null) artist = md.getString(MediaMetadata.METADATA_KEY_ALBUM);
            m.put("title", title);
            m.put("artist", artist);
            m.put("duration", md.getLong(MediaMetadata.METADATA_KEY_DURATION));
            Bitmap art = md.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART);
            if (art == null) art = md.getBitmap(MediaMetadata.METADATA_KEY_ART);
            if (art == null) art = md.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON);
            String key = c.getPackageName() + "|" + title;
            if (art != null) {
                if (!key.equals(lastArtKey)) {
                    lastArtKey = key;
                    Bitmap s = Bitmap.createScaledBitmap(art, 96, Math.max(1, 96 * art.getHeight() / Math.max(1, art.getWidth())), true);
                    ByteArrayOutputStream bos = new ByteArrayOutputStream();
                    s.compress(Bitmap.CompressFormat.JPEG, 85, bos);
                    lastArt = bos.toByteArray();
                }
                m.put("art", lastArt);
            }
        }
        if (st != null) {
            m.put("playing", st.getState() == PlaybackState.STATE_PLAYING);
            long pos = st.getPosition();
            if (st.getState() == PlaybackState.STATE_PLAYING && st.getLastPositionUpdateTime() > 0) {
                pos += (long) ((android.os.SystemClock.elapsedRealtime() - st.getLastPositionUpdateTime()) * st.getPlaybackSpeed());
            }
            m.put("position", pos);
        }
        saveLast(m);
        return m;
    }

    // ------------------------------------------------------------ última canción (reanudar)
    // Apps como TizenTube detienen el video al ir al inicio y su sesión desaparece. Se guarda lo
    // último que sonó para mostrarlo «en pausa» y poder volver a la app con un botón.

    private static final String LAST = "sgalfa_last_media";
    private static final long LAST_MAX_AGE = 12L * 60 * 60 * 1000; // medio día

    private void saveLast(Map<String, Object> m) {
        Object title = m.get("title");
        Object pkg = m.get("package");
        if (!(title instanceof String) || ((String) title).isEmpty() || !(pkg instanceof String)) return;
        android.content.SharedPreferences p = activity.getSharedPreferences(LAST, Context.MODE_PRIVATE);
        android.content.SharedPreferences.Editor e = p.edit()
                .putString("package", (String) pkg)
                .putString("title", (String) title)
                .putString("artist", m.get("artist") instanceof String ? (String) m.get("artist") : null)
                .putLong("duration", m.get("duration") instanceof Long ? (Long) m.get("duration") : 0)
                .putLong("position", m.get("position") instanceof Long ? (Long) m.get("position") : 0)
                .putLong("at", System.currentTimeMillis());
        String key = pkg + "|" + title;
        if (!key.equals(p.getString("key", null))) {
            e.putString("key", key);
            Object art = m.get("art");
            e.putString("art", art instanceof byte[]
                    ? android.util.Base64.encodeToString((byte[]) art, android.util.Base64.NO_WRAP) : null);
        }
        e.apply();
    }

    private Intent launchFor(String pkg) {
        android.content.pm.PackageManager pm = activity.getPackageManager();
        Intent i = pm.getLeanbackLaunchIntentForPackage(pkg);
        if (i == null) i = pm.getLaunchIntentForPackage(pkg);
        return i;
    }

    private Map<String, Object> lastMedia(Map<String, Object> m) {
        try {
            android.content.SharedPreferences p = activity.getSharedPreferences(LAST, Context.MODE_PRIVATE);
            String pkg = p.getString("package", null);
            String title = p.getString("title", null);
            if (pkg == null || title == null) return m;
            if (System.currentTimeMillis() - p.getLong("at", 0) > LAST_MAX_AGE) return m;
            if (launchFor(pkg) == null) return m;
            m.put("package", pkg);
            m.put("title", title);
            m.put("artist", p.getString("artist", null));
            m.put("duration", p.getLong("duration", 0));
            m.put("position", p.getLong("position", 0));
            String art = p.getString("art", null);
            if (art != null) m.put("art", android.util.Base64.decode(art, android.util.Base64.NO_WRAP));
            m.put("playing", false);
            m.put("resume", true);
            try {
                android.content.pm.PackageManager pm = activity.getPackageManager();
                m.put("app", pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString());
            } catch (Exception ignored) {
            }
        } catch (Exception ignored) {
        }
        return m;
    }

    private boolean resumeLast() {
        Map<String, Object> m = lastMedia(new HashMap<>());
        if (m.get("resume") == null) return false;
        Intent i = launchFor((String) m.get("package"));
        if (i == null) return false;
        try {
            activity.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
