/*
 * SG Alfa Home — la libreta de Alfi: anuncios y pop-ups que ha visto en la tele.
 *
 * - Pop-ups / pantallas de anuncio: en qué app, qué texto y qué botones tenía.
 * - Dominios con pinta de anuncio que el filtro DNS dejó pasar.
 *
 * Se guarda en la tele y se copia a Android/data/tv.sgalfa.home/files/alfi-anuncios.json
 * para revisarlo desde el PC (por ADB) y bloquearlo. No se envía a ningún sitio.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public final class AdLog {

    private static final String PREFS = "alfi_adlog";
    private static final String KEY = "entries";
    private static final String KEY_USER_BLOCK = "user_block";
    private static final int MAX = 300;
    private static final long SAME_WINDOW_MS = 10 * 60 * 1000;

    /** Palabras que delatan un dominio de publicidad o rastreo. */
    private static final String[] AD_DOMAIN_WORDS = {
            "ads", "adserv", "adsrv", "adnxs", "doubleclick", "banner", "popup", "popads", "propeller",
            "track", "analytics", "metrics", "telemetry", "pixel", "promo", "affiliate", "click", "vast",
            "ima3", "imasdk", "adcolony", "unityads", "applovin", "mopub", "inmobi", "vungle", "chartboost",
    };

    /** Palabras que delatan un anuncio en pantalla. */
    static final String[] AD_SCREEN_WORDS = {
            "anuncio", "publicidad", "patrocinado", "patrocinada", "advertisement", "sponsored",
            "saltar anuncio", "omitir anuncio", "skip ad", "close ad", "cerrar anuncio", "ad will end",
            "el anuncio termina", "visit advertiser", "visitar anunciante", "promoción", "oferta especial",
            "suscríbete ahora", "hazte premium",
    };

    private AdLog() {
    }

    private static SharedPreferences prefs(Context c) {
        return c.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static String now() {
        return new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.ROOT).format(new Date());
    }

    static synchronized JSONArray entries(Context c) {
        try {
            return new JSONArray(prefs(c).getString(KEY, "[]"));
        } catch (Exception e) {
            return new JSONArray();
        }
    }

    private static synchronized void save(Context c, JSONArray arr) {
        // Guarda solo los últimos MAX.
        JSONArray out = arr;
        if (arr.length() > MAX) {
            out = new JSONArray();
            for (int i = arr.length() - MAX; i < arr.length(); i++) out.put(arr.opt(i));
        }
        prefs(c).edit().putString(KEY, out.toString()).apply();
        export(c, out);
    }

    /** Copia legible desde el PC: adb pull /sdcard/Android/data/tv.sgalfa.home/files/alfi-anuncios.json */
    private static void export(Context c, JSONArray arr) {
        try {
            File dir = c.getExternalFilesDir(null);
            if (dir == null) return;
            JSONObject root = new JSONObject();
            root.put("generado", now());
            root.put("dispositivo", android.os.Build.BRAND + " " + android.os.Build.MODEL);
            root.put("anuncios", arr);
            root.put("dominios_bloqueados_por_ti", new JSONArray(userBlocklist(c)));
            try (FileOutputStream f = new FileOutputStream(new File(dir, "alfi-anuncios.json"))) {
                f.write(root.toString(2).getBytes(StandardCharsets.UTF_8));
            }
        } catch (Exception ignored) {
        }
    }

    /** ¿Tiene pinta de dominio de anuncios? */
    static boolean adLikeDomain(String host) {
        String h = host.toLowerCase(Locale.ROOT);
        for (String w : AD_DOMAIN_WORDS) {
            if (h.contains(w)) return true;
        }
        return false;
    }

    /** Un dominio con pinta de anuncio que se coló (no lo bloqueó nadie). Una vez por día y dominio. */
    static synchronized void dnsPassed(Context c, String host) {
        try {
            dnsPassedInner(c, host);
        } catch (Exception ignored) {
        }
    }

    private static void dnsPassedInner(Context c, String host) throws Exception {
        JSONArray arr = entries(c);
        String day = now().substring(0, 10);
        for (int i = arr.length() - 1; i >= 0 && i >= arr.length() - 120; i--) {
            JSONObject o = arr.optJSONObject(i);
            if (o != null && "dominio".equals(o.optString("tipo")) && host.equals(o.optString("dominio"))
                    && o.optString("cuando").startsWith(day)) {
                o.put("veces", o.optInt("veces", 1) + 1);
                save(c, arr);
                return;
            }
        }
        try {
            JSONObject o = new JSONObject();
            o.put("tipo", "dominio");
            o.put("cuando", now());
            o.put("dominio", host);
            o.put("veces", 1);
            arr.put(o);
            save(c, arr);
        } catch (Exception ignored) {
        }
    }

    /** Un pop-up o pantalla de anuncio dentro de una app. Agrupa repeticiones de 10 minutos. */
    static synchronized void popup(Context c, String pkg, String appName, String text, List<String> buttons) {
        try {
            popupInner(c, pkg, appName, text, buttons);
        } catch (Exception ignored) {
        }
    }

    private static void popupInner(Context c, String pkg, String appName, String text, List<String> buttons)
            throws Exception {
        JSONArray arr = entries(c);
        long t = System.currentTimeMillis();
        for (int i = arr.length() - 1; i >= 0 && i >= arr.length() - 60; i--) {
            JSONObject o = arr.optJSONObject(i);
            if (o == null || !"popup".equals(o.optString("tipo")) || !pkg.equals(o.optString("app"))) continue;
            if (t - o.optLong("ms", 0) < SAME_WINDOW_MS && text.equals(o.optString("texto"))) {
                o.put("veces", o.optInt("veces", 1) + 1);
                o.put("ms", t);
                save(c, arr);
                return;
            }
        }
        try {
            JSONObject o = new JSONObject();
            o.put("tipo", "popup");
            o.put("cuando", now());
            o.put("ms", t);
            o.put("app", pkg);
            o.put("nombre", appName);
            o.put("texto", text);
            o.put("botones", new JSONArray(buttons));
            o.put("veces", 1);
            arr.put(o);
            save(c, arr);
        } catch (Exception ignored) {
        }
    }

    static synchronized void clear(Context c) {
        save(c, new JSONArray());
    }

    // ---------- Dominios que bloqueas tú desde la tele ----------

    static Set<String> userBlocklist(Context c) {
        return new HashSet<>(prefs(c).getStringSet(KEY_USER_BLOCK, new HashSet<>()));
    }

    static synchronized void blockDomain(Context c, String host) {
        Set<String> s = userBlocklist(c);
        s.add(host.toLowerCase(Locale.ROOT));
        prefs(c).edit().putStringSet(KEY_USER_BLOCK, s).apply();
        // Quita ese dominio de la libreta: ya está resuelto.
        JSONArray arr = entries(c), out = new JSONArray();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.optJSONObject(i);
            if (o != null && host.equalsIgnoreCase(o.optString("dominio"))) continue;
            out.put(o);
        }
        save(c, out);
        DnsBlockVpnService.reloadBlocklist();
    }

    /** Lista para la interfaz (más reciente primero). */
    static List<java.util.Map<String, Object>> forUi(Context c) {
        JSONArray arr = entries(c);
        List<java.util.Map<String, Object>> out = new ArrayList<>();
        for (int i = arr.length() - 1; i >= 0; i--) {
            JSONObject o = arr.optJSONObject(i);
            if (o == null) continue;
            java.util.Map<String, Object> m = new java.util.HashMap<>();
            m.put("tipo", o.optString("tipo"));
            m.put("cuando", o.optString("cuando"));
            m.put("veces", o.optInt("veces", 1));
            m.put("app", o.optString("app"));
            m.put("nombre", o.optString("nombre"));
            m.put("texto", o.optString("texto"));
            m.put("dominio", o.optString("dominio"));
            List<String> b = new ArrayList<>();
            JSONArray ba = o.optJSONArray("botones");
            if (ba != null) for (int j = 0; j < ba.length(); j++) b.add(ba.optString(j));
            m.put("botones", b);
            out.add(m);
        }
        return out;
    }
}
