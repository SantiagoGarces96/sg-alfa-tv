/*
 * SG Alfa Home — actualizaciones: mira en GitHub si hay versión nueva, la descarga y
 * abre el instalador de Android para instalarla encima (se conservan tus ajustes).
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import androidx.core.content.FileProvider;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;

public final class Updater {

    /** Repositorio donde se publican las versiones. */
    static final String REPO = "SantiagoGarces96/sg-alfa-tv";
    private static final String UA = "SG-Alfa-Home-Updater";

    // Progreso de la descarga (lo lee la pantalla cada medio segundo).
    static volatile long downloaded = 0;
    static volatile long size = 0;
    static volatile String state = "idle"; // idle | downloading | ready | error
    static volatile String error = "";

    private Updater() {
    }

    static String currentVersion(Context c) {
        try {
            return c.getPackageManager().getPackageInfo(c.getPackageName(), 0).versionName;
        } catch (Exception e) {
            return "0";
        }
    }

    /** 2.10.0 > 2.9.3 (compara número a número). */
    static boolean newer(String latest, String current) {
        String[] a = latest.replaceAll("[^0-9.]", "").split("\\.");
        String[] b = current.replaceAll("[^0-9.]", "").split("\\.");
        for (int i = 0; i < Math.max(a.length, b.length); i++) {
            int x = i < a.length && !a[i].isEmpty() ? Integer.parseInt(a[i]) : 0;
            int y = i < b.length && !b[i].isEmpty() ? Integer.parseInt(b[i]) : 0;
            if (x != y) return x > y;
        }
        return false;
    }

    /**
     * Última versión publicada, SIN la API de GitHub (que limita a 60 consultas por hora y casa):
     * la página /releases/latest redirige a /releases/tag/<versión>.
     */
    private static String latestTag() throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL("https://github.com/" + REPO + "/releases/latest").openConnection();
        c.setInstanceFollowRedirects(false);
        c.setRequestProperty("User-Agent", UA);
        c.setConnectTimeout(10_000);
        c.setReadTimeout(15_000);
        try {
            String loc = c.getHeaderField("Location");
            if (loc == null) throw new Exception("sin redirección (" + c.getResponseCode() + ")");
            return loc.substring(loc.lastIndexOf('/') + 1);
        } finally {
            c.disconnect();
        }
    }

    /** Descarga un archivo de texto pequeño siguiendo redirecciones. */
    private static String getText(String url) throws Exception {
        String u = url;
        for (int hop = 0; hop < 6; hop++) {
            HttpURLConnection c = (HttpURLConnection) new URL(u).openConnection();
            c.setInstanceFollowRedirects(false);
            c.setRequestProperty("User-Agent", UA);
            c.setConnectTimeout(10_000);
            c.setReadTimeout(15_000);
            int code = c.getResponseCode();
            if (code >= 300 && code < 400) {
                u = new URL(new URL(u), c.getHeaderField("Location")).toString();
                c.disconnect();
                continue;
            }
            if (code != 200) {
                c.disconnect();
                return "";
            }
            try (InputStream in = c.getInputStream()) {
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buf = new byte[8 * 1024];
                int n;
                while ((n = in.read(buf)) > 0 && out.size() < 64 * 1024) out.write(buf, 0, n);
                return out.toString("UTF-8");
            } finally {
                c.disconnect();
            }
        }
        return "";
    }

    /** {current, latest, available, notes, url}. Se llama desde un hilo aparte. */
    static Map<String, Object> check(Context c) {
        Map<String, Object> m = new HashMap<>();
        String current = currentVersion(c);
        m.put("current", current);
        m.put("available", false);
        try {
            String tag = latestTag();
            String base = "https://github.com/" + REPO + "/releases/download/" + tag + "/";
            m.put("latest", tag);
            m.put("url", base + "sg-alfa-home.apk");
            boolean newer = newer(tag, current);
            m.put("available", newer);
            m.put("notes", newer ? getText(base + "novedades.txt") : "");
        } catch (Exception e) {
            m.put("error", e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage());
        }
        return m;
    }

    private static File apkFile(Context c) {
        File dir = new File(c.getCacheDir(), "update");
        //noinspection ResultOfMethodCallIgnored
        dir.mkdirs();
        return new File(dir, "sg-alfa-home.apk");
    }

    /** Descarga en segundo plano (sigue redirecciones de GitHub). */
    static void download(Context c, String url) {
        if ("downloading".equals(state)) return;
        state = "downloading";
        downloaded = 0;
        size = 0;
        error = "";
        new Thread(() -> {
            try {
                String u = url;
                HttpURLConnection conn = null;
                for (int hop = 0; hop < 6; hop++) {
                    conn = (HttpURLConnection) new URL(u).openConnection();
                    conn.setInstanceFollowRedirects(false);
                    conn.setRequestProperty("User-Agent", UA);
                    conn.setConnectTimeout(15_000);
                    conn.setReadTimeout(30_000);
                    int code = conn.getResponseCode();
                    if (code >= 300 && code < 400) {
                        u = new URL(new URL(u), conn.getHeaderField("Location")).toString();
                        conn.disconnect();
                        continue;
                    }
                    break;
                }
                size = conn.getContentLengthLong();
                File f = apkFile(c);
                try (InputStream in = conn.getInputStream(); FileOutputStream out = new FileOutputStream(f)) {
                    byte[] buf = new byte[64 * 1024];
                    int n;
                    while ((n = in.read(buf)) > 0) {
                        out.write(buf, 0, n);
                        downloaded += n;
                    }
                }
                conn.disconnect();
                // Un APK es un ZIP: comprobación mínima de que no bajó una página de error.
                byte[] head = new byte[2];
                try (InputStream in = new java.io.FileInputStream(f)) {
                    if (in.read(head) != 2 || head[0] != 'P' || head[1] != 'K') throw new Exception("no es un APK");
                }
                state = "ready";
            } catch (Exception e) {
                error = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
                state = "error";
            }
        }, "sgalfa-update").start();
    }

    static Map<String, Object> progress() {
        Map<String, Object> m = new HashMap<>();
        m.put("state", state);
        m.put("downloaded", downloaded);
        m.put("size", size);
        m.put("error", error);
        return m;
    }

    /** ¿Puede esta app instalar actualizaciones? (permiso «Instalar apps desconocidas»). */
    static boolean canInstall(Context c) {
        return Build.VERSION.SDK_INT < 26 || c.getPackageManager().canRequestPackageInstalls();
    }

    /** Abre el instalador de Android con la versión descargada. */
    static boolean install(Activity a) {
        if (!canInstall(a)) {
            a.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:" + a.getPackageName())));
            return false;
        }
        File f = apkFile(a);
        if (!f.exists()) return false;
        Uri uri = FileProvider.getUriForFile(a, a.getPackageName() + ".updates", f);
        Intent i = new Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
        a.startActivity(i);
        return true;
    }
}
