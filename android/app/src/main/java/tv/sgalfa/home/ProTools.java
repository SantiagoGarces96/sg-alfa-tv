/*
 * SG Alfa Home — herramientas «pro»: temporizador para dormir, diagnóstico, copia de la
 * configuración, búsqueda en las apps y permiso para instalar actualizaciones.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Build;
import android.os.SystemClock;
import android.provider.MediaStore;
import android.provider.Settings;
import android.view.KeyEvent;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

final class ProTools {
    private ProTools() {
    }

    // ================================================================ temporizador para dormir

    private static final String SLEEP_PREFS = "sgalfa_sleep";

    /** Programa (o quita, con 0) el apagado dentro de {@code minutes} minutos. */
    static void setSleepTimer(Context c, int minutes) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        PendingIntent pi = PendingIntent.getBroadcast(c, 4711, new Intent(c, SleepReceiver.class),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        am.cancel(pi);
        SharedPreferences p = c.getSharedPreferences(SLEEP_PREFS, Context.MODE_PRIVATE);
        if (minutes <= 0) {
            p.edit().remove("at").apply();
            return;
        }
        long at = System.currentTimeMillis() + minutes * 60_000L;
        p.edit().putLong("at", at).apply();
        long trigger = SystemClock.elapsedRealtime() + minutes * 60_000L;
        if (Build.VERSION.SDK_INT >= 23) {
            am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, trigger, pi);
        } else {
            am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, trigger, pi);
        }
    }

    /** Milisegundos que faltan para dormir (0 = sin temporizador). */
    static long sleepRemaining(Context c) {
        long at = c.getSharedPreferences(SLEEP_PREFS, Context.MODE_PRIVATE).getLong("at", 0);
        long left = at - System.currentTimeMillis();
        return left > 0 ? left : 0;
    }

    /** Llega la hora: pausar lo que suena y apagar la pantalla (reposo). */
    public static class SleepReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context c, Intent intent) {
            c.getSharedPreferences(SLEEP_PREFS, Context.MODE_PRIVATE).edit().remove("at").apply();
            try {
                AudioManager am = (AudioManager) c.getSystemService(Context.AUDIO_SERVICE);
                am.dispatchMediaKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE));
                am.dispatchMediaKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE));
            } catch (Exception ignored) {
            }
            AutoClickService s = AutoClickService.instance;
            if (s != null && Build.VERSION.SDK_INT >= 28) {
                new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(
                        () -> s.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN),
                        1500);
            }
        }
    }

    // ================================================================ fallos y diagnóstico

    private static volatile boolean handlerInstalled = false;

    /** Guarda el último cierre inesperado para el diagnóstico. */
    static void installCrashLog(Context ctx) {
        if (handlerInstalled) return;
        handlerInstalled = true;
        Context c = ctx.getApplicationContext();
        Thread.UncaughtExceptionHandler prev = Thread.getDefaultUncaughtExceptionHandler();
        Thread.setDefaultUncaughtExceptionHandler((t, e) -> {
            try {
                StringWriter sw = new StringWriter();
                e.printStackTrace(new PrintWriter(sw));
                logError(c, "Cierre inesperado en " + t.getName() + "\n" + sw);
            } catch (Exception ignored) {
            }
            if (prev != null) prev.uncaughtException(t, e);
        });
    }

    /** Añade un error al registro (como mucho ~40 KB). */
    static synchronized void logError(Context c, String text) {
        try {
            File f = new File(c.getFilesDir(), "errores.txt");
            if (f.length() > 40_000) f.delete();
            try (FileOutputStream o = new FileOutputStream(f, true)) {
                o.write(("[" + now() + "] " + text + "\n\n").getBytes(StandardCharsets.UTF_8));
            }
        } catch (Exception ignored) {
        }
    }

    private static String now() {
        return new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ROOT).format(new Date());
    }

    private static String readFile(File f) {
        if (f == null || !f.exists()) return "";
        try (InputStream in = new FileInputStream(f)) {
            return readAll(in);
        } catch (Exception e) {
            return "";
        }
    }

    private static String readAll(InputStream in) throws Exception {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader r = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            String line;
            while ((line = r.readLine()) != null) sb.append(line).append('\n');
        }
        return sb.toString();
    }

    /** Crea el informe de diagnóstico. Devuelve dónde quedó guardado. */
    static String diagnostics(Context c) {
        StringBuilder sb = new StringBuilder();
        sb.append("SG Alfa Home — diagnóstico\n").append(now()).append("\n\n");
        try {
            sb.append("Versión: ").append(c.getPackageManager().getPackageInfo(c.getPackageName(), 0).versionName).append('\n');
        } catch (Exception ignored) {
        }
        sb.append("Equipo: ").append(Build.BRAND).append(' ').append(Build.MODEL)
                .append(" · Android ").append(Build.VERSION.RELEASE).append(" (API ").append(Build.VERSION.SDK_INT).append(")\n");
        sb.append("Bloqueo de anuncios: ").append(DnsBlockVpnService.isProtecting(c) ? "activo" : "apagado")
                .append(DnsBlockVpnService.privateDnsHost(c) != null ? " (DNS privado " + DnsBlockVpnService.privateDnsHost(c) + ")" : "")
                .append('\n');
        sb.append("Automatizaciones: ").append(AutoClickService.isEnabled(c) ? "activas" : "apagadas").append('\n');
        String nl = Settings.Secure.getString(c.getContentResolver(), "enabled_notification_listeners");
        sb.append("Lo que suena: ").append(nl != null && nl.contains(c.getPackageName()) ? "permitido" : "sin permiso").append('\n');
        sb.append("Instalar actualizaciones: ").append(canInstall(c) ? "permitido" : "sin permiso").append('\n');
        sb.append("Internet: ").append(NetGate.online(c) ? "conectado" : "sin conexión").append('\n');
        try {
            android.app.ActivityManager am = (android.app.ActivityManager) c.getSystemService(Context.ACTIVITY_SERVICE);
            android.app.ActivityManager.MemoryInfo mi = new android.app.ActivityManager.MemoryInfo();
            am.getMemoryInfo(mi);
            sb.append("Memoria libre: ").append(mi.availMem / 1048576).append(" MB de ").append(mi.totalMem / 1048576).append(" MB\n");
        } catch (Exception ignored) {
        }
        sb.append("Anuncios bloqueados hoy: ").append(Stats.get(c, Stats.ADS)).append('\n');
        sb.append("\n--- Errores guardados ---\n").append(readFile(new File(c.getFilesDir(), "errores.txt")));
        sb.append("\n--- Registro reciente ---\n");
        try {
            Process p = Runtime.getRuntime().exec(new String[]{"logcat", "-d", "-t", "400", "--pid", String.valueOf(android.os.Process.myPid())});
            sb.append(readAll(p.getInputStream()));
        } catch (Exception e) {
            sb.append("(no disponible)\n");
        }
        return save(c, "sgalfa-diagnostico.txt", sb.toString(), "text/plain");
    }

    /** Guarda en la app y, si se puede, también en Descargas. Devuelve la ruta más útil. */
    private static String save(Context c, String name, String text, String mime) {
        String where = null;
        try {
            File dir = c.getExternalFilesDir(null);
            if (dir != null) {
                File f = new File(dir, name);
                try (FileOutputStream o = new FileOutputStream(f)) {
                    o.write(text.getBytes(StandardCharsets.UTF_8));
                }
                where = f.getAbsolutePath();
            }
        } catch (Exception ignored) {
        }
        if (Build.VERSION.SDK_INT >= 29) {
            try {
                Uri col = MediaStore.Downloads.EXTERNAL_CONTENT_URI;
                c.getContentResolver().delete(col, MediaStore.MediaColumns.DISPLAY_NAME + "=?", new String[]{name});
                ContentValues v = new ContentValues();
                v.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
                v.put(MediaStore.MediaColumns.MIME_TYPE, mime);
                Uri u = c.getContentResolver().insert(col, v);
                if (u != null) {
                    try (OutputStream o = c.getContentResolver().openOutputStream(u)) {
                        if (o != null) o.write(text.getBytes(StandardCharsets.UTF_8));
                    }
                    where = "Descargas/" + name;
                }
            } catch (Exception ignored) {
            }
        }
        return where != null ? where : "";
    }

    // ================================================================ copia de la configuración

    /** Archivos de ajustes que se copian (tema, fondo, números, favoritas, automatizaciones…). */
    private static final String[] BACKUP_PREFS = {"FlutterSharedPreferences", AutoClickService.PREFS, "alfi_adlog", "alfi_clean"};
    static final String BACKUP_NAME = "sgalfa-config.json";

    static String exportConfig(Context c) {
        try {
            JSONObject root = new JSONObject();
            root.put("app", "SG Alfa Home");
            root.put("fecha", now());
            for (String name : BACKUP_PREFS) {
                JSONObject file = new JSONObject();
                for (Map.Entry<String, ?> e : c.getSharedPreferences(name, Context.MODE_PRIVATE).getAll().entrySet()) {
                    Object v = e.getValue();
                    if (e.getKey().equals("flutter.onboarded")) continue;
                    JSONObject item = new JSONObject();
                    if (v instanceof Boolean) item.put("t", "b");
                    else if (v instanceof Integer) item.put("t", "i");
                    else if (v instanceof Long) item.put("t", "l");
                    else if (v instanceof Float) item.put("t", "f");
                    else if (v instanceof Set) {
                        item.put("t", "s");
                        v = new JSONArray(new ArrayList<>((Set<?>) v));
                    } else item.put("t", "str");
                    item.put("v", v);
                    file.put(e.getKey(), item);
                }
                root.put(name, file);
            }
            return save(c, BACKUP_NAME, root.toString(2), "application/json");
        } catch (Exception e) {
            return "";
        }
    }

    /** Lee la copia: de Descargas o de la carpeta de la app. Devuelve true si la aplicó. */
    static boolean importConfig(Context c) {
        String text = null;
        List<File> places = new ArrayList<>();
        places.add(new File(android.os.Environment.getExternalStoragePublicDirectory(
                android.os.Environment.DIRECTORY_DOWNLOADS), BACKUP_NAME));
        File dir = c.getExternalFilesDir(null);
        if (dir != null) places.add(new File(dir, BACKUP_NAME));
        for (File f : places) {
            String t = readFile(f);
            if (!t.isEmpty()) {
                text = t;
                break;
            }
        }
        if (text == null && Build.VERSION.SDK_INT >= 29) {
            try (android.database.Cursor cur = c.getContentResolver().query(MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    new String[]{MediaStore.MediaColumns._ID}, MediaStore.MediaColumns.DISPLAY_NAME + "=?",
                    new String[]{BACKUP_NAME}, null)) {
                if (cur != null && cur.moveToFirst()) {
                    Uri u = android.content.ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cur.getLong(0));
                    try (InputStream in = c.getContentResolver().openInputStream(u)) {
                        if (in != null) text = readAll(in);
                    }
                }
            } catch (Exception ignored) {
            }
        }
        if (text == null) return false;
        try {
            JSONObject root = new JSONObject(text);
            for (String name : BACKUP_PREFS) {
                JSONObject file = root.optJSONObject(name);
                if (file == null) continue;
                SharedPreferences.Editor ed = c.getSharedPreferences(name, Context.MODE_PRIVATE).edit();
                Iterator<String> keys = file.keys();
                while (keys.hasNext()) {
                    String k = keys.next();
                    JSONObject item = file.getJSONObject(k);
                    switch (item.optString("t")) {
                        case "b": ed.putBoolean(k, item.getBoolean("v")); break;
                        case "i": ed.putInt(k, item.getInt("v")); break;
                        case "l": ed.putLong(k, item.getLong("v")); break;
                        case "f": ed.putFloat(k, (float) item.getDouble("v")); break;
                        case "s": {
                            JSONArray arr = item.getJSONArray("v");
                            java.util.HashSet<String> set = new java.util.HashSet<>();
                            for (int i = 0; i < arr.length(); i++) set.add(arr.getString(i));
                            ed.putStringSet(k, set);
                            break;
                        }
                        default: ed.putString(k, item.optString("v"));
                    }
                }
                ed.commit();
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // ================================================================ buscar en las apps

    private static final String[][] SEARCHABLE = {
            {"io.gh.reisxd.tizentube.cobalt", "TizenTube"},
            {"com.google.android.youtube.tv", "YouTube"},
            {"com.teamsmart.videomanager.tv", "SmartTube"},
            {"com.spotify.tv.android", "Spotify"},
            {"com.xuper.wiwyxuper", "WiwyXuper"},
            {"com.android.mgstv", "Xuper Hydra"},
            {"csc.app.anime.cast", "Anime Cast"},
            {"aplicaciones.paleta.legionanimefull", "Legion Anime"},
    };

    /** Apps instaladas donde se puede buscar. */
    static List<Map<String, Object>> searchApps(Context c) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (String[] a : SEARCHABLE) {
            try {
                c.getPackageManager().getApplicationInfo(a[0], 0);
                Map<String, Object> m = new HashMap<>();
                m.put("package", a[0]);
                m.put("name", a[1]);
                out.add(m);
            } catch (Exception ignored) {
            }
        }
        return out;
    }

    /** Busca {@code query} dentro de la app: enlace directo si la app lo admite; si no, usa su buscador. */
    static boolean searchIn(Context c, String pkg, String query) {
        try {
            String q = URLEncoder.encode(query, "UTF-8");
            Intent i = null;
            if (pkg.startsWith("com.spotify")) {
                i = new Intent(Intent.ACTION_VIEW, Uri.parse("spotify:search:" + query)).setPackage(pkg);
            } else if (!c.getPackageManager().queryIntentActivities(new Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://www.youtube.com/results?search_query=x")).setPackage(pkg), 0).isEmpty()) {
                i = new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=" + q)).setPackage(pkg);
            }
            if (i != null) {
                c.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                return true;
            }
        } catch (Exception ignored) {
        }
        return ContinueOpen.openSearch(c, pkg, query);
    }

    // ================================================================ permiso para instalar actualizaciones

    static boolean canInstall(Context c) {
        return Build.VERSION.SDK_INT < 26 || c.getPackageManager().canRequestPackageInstalls();
    }

    static boolean openInstallPermission(Context c) {
        try {
            c.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:" + c.getPackageName())).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            return true;
        } catch (Exception e) {
            try {
                c.startActivity(new Intent(Settings.ACTION_SECURITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            } catch (Exception ignored) {
            }
            android.widget.Toast.makeText(c, "Busca «Instalar apps desconocidas» y permite SG Alfa Home",
                    android.widget.Toast.LENGTH_LONG).show();
            return false;
        }
    }

    static boolean openDreamSettings(Context c) {
        try {
            c.startActivity(new Intent(Settings.ACTION_DREAM_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            return true;
        } catch (Exception e) {
            try {
                c.startActivity(new Intent(Settings.ACTION_DISPLAY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            } catch (Exception ignored) {
            }
            android.widget.Toast.makeText(c, "Busca «Salvapantallas» y elige «SG Alfa»", android.widget.Toast.LENGTH_LONG).show();
            return false;
        }
    }
}
