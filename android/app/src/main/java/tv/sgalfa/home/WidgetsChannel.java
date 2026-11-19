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
                    if (c != null) {
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
        if (c == null) return m;
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
        return m;
    }
}
