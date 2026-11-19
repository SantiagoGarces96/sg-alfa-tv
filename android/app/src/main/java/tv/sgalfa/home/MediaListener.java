/*
 * SG Alfa Home — necesario para que Android deje ver qué música o vídeo está sonando
 * (widget «Sonando ahora»). No lee ni guarda notificaciones.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.content.ComponentName;
import android.content.Context;
import android.graphics.Bitmap;
import android.media.MediaMetadata;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.media.session.PlaybackState;
import android.os.Handler;
import android.os.Looper;
import android.service.notification.NotificationListenerService;

import java.io.ByteArrayOutputStream;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Además de dar permiso, sigue lo que suena aunque el launcher no esté a la vista: cuando
 * TizenTube (u otra app) cambia de canción se guarda al momento. Así, al volver al inicio,
 * la tarjeta muestra la última canción de verdad y no una vieja.
 */
public class MediaListener extends NotificationListenerService {

    private static final String LAST = "sgalfa_last_media";
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Map<MediaSession_Token, MediaController.Callback> callbacks = new HashMap<>();
    private MediaSessionManager msm;
    private final MediaSessionManager.OnActiveSessionsChangedListener changed = this::track;

    /** Envoltura para usar el token de sesión como clave. */
    private static final class MediaSession_Token {
        final Object token;
        final MediaController controller;

        MediaSession_Token(MediaController c) {
            controller = c;
            token = c.getSessionToken();
        }

        @Override
        public boolean equals(Object o) {
            return o instanceof MediaSession_Token && ((MediaSession_Token) o).token.equals(token);
        }

        @Override
        public int hashCode() {
            return token.hashCode();
        }
    }

    @Override
    public void onListenerConnected() {
        try {
            msm = (MediaSessionManager) getSystemService(Context.MEDIA_SESSION_SERVICE);
            ComponentName me = new ComponentName(this, MediaListener.class);
            msm.addOnActiveSessionsChangedListener(changed, me, main);
            track(msm.getActiveSessions(me));
        } catch (Exception ignored) {
        }
    }

    @Override
    public void onListenerDisconnected() {
        try {
            if (msm != null) msm.removeOnActiveSessionsChangedListener(changed);
        } catch (Exception ignored) {
        }
        for (Map.Entry<MediaSession_Token, MediaController.Callback> e : callbacks.entrySet()) {
            try {
                e.getKey().controller.unregisterCallback(e.getValue());
            } catch (Exception ignored) {
            }
        }
        callbacks.clear();
    }

    private void track(List<MediaController> list) {
        if (list == null) return;
        // Quitar las que ya no están.
        Map<MediaSession_Token, MediaController.Callback> keep = new HashMap<>();
        for (MediaController c : list) {
            if (skip(c.getPackageName())) continue;
            MediaSession_Token k = new MediaSession_Token(c);
            MediaController.Callback cb = callbacks.remove(k);
            if (cb == null) {
                cb = new MediaController.Callback() {
                    @Override
                    public void onMetadataChanged(MediaMetadata metadata) {
                        save(c);
                    }

                    @Override
                    public void onPlaybackStateChanged(PlaybackState state) {
                        if (state != null && state.getState() == PlaybackState.STATE_PLAYING) save(c);
                    }
                };
                try {
                    c.registerCallback(cb, main);
                } catch (Exception ignored) {
                }
            }
            keep.put(k, cb);
            save(c);
        }
        for (Map.Entry<MediaSession_Token, MediaController.Callback> e : callbacks.entrySet()) {
            try {
                e.getKey().controller.unregisterCallback(e.getValue());
            } catch (Exception ignored) {
            }
        }
        callbacks.clear();
        callbacks.putAll(keep);
    }

    static boolean skip(String pkg) {
        return pkg == null || "com.apps.livetv".equals(pkg) || "com.android.bluetooth".equals(pkg)
                || "com.android.tv".equals(pkg) || "com.google.android.tv".equals(pkg);
    }

    /** Guarda la canción actual en el mismo formato que usa la tarjeta (WidgetsChannel). */
    private void save(MediaController c) {
        try {
            MediaMetadata md = c.getMetadata();
            if (md == null) return;
            String title = md.getString(MediaMetadata.METADATA_KEY_TITLE);
            if (title == null) title = md.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE);
            if (title == null || title.isEmpty()) return;
            String artist = md.getString(MediaMetadata.METADATA_KEY_ARTIST);
            if (artist == null) artist = md.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE);
            if (artist == null) artist = md.getString(MediaMetadata.METADATA_KEY_ALBUM);
            PlaybackState st = c.getPlaybackState();
            long pos = st != null ? st.getPosition() : 0;
            String pkg = c.getPackageName();
            android.content.SharedPreferences p = getSharedPreferences(LAST, MODE_PRIVATE);
            android.content.SharedPreferences.Editor e = p.edit()
                    .putString("package", pkg)
                    .putString("title", title)
                    .putString("artist", artist)
                    .putLong("duration", md.getLong(MediaMetadata.METADATA_KEY_DURATION))
                    .putLong("position", Math.max(0, pos))
                    .putLong("at", System.currentTimeMillis());
            String key = pkg + "|" + title;
            if (!key.equals(p.getString("key", null))) {
                e.putString("key", key);
                Bitmap art = md.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART);
                if (art == null) art = md.getBitmap(MediaMetadata.METADATA_KEY_ART);
                if (art == null) art = md.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON);
                String b64 = null;
                if (art != null) {
                    Bitmap s = Bitmap.createScaledBitmap(art, 96,
                            Math.max(1, 96 * art.getHeight() / Math.max(1, art.getWidth())), true);
                    ByteArrayOutputStream bos = new ByteArrayOutputStream();
                    s.compress(Bitmap.CompressFormat.JPEG, 85, bos);
                    b64 = android.util.Base64.encodeToString(bos.toByteArray(), android.util.Base64.NO_WRAP);
                }
                e.putString("art", b64);
            }
            e.apply();
        } catch (Exception ignored) {
        }
    }
}
