/*
 * SG Alfa Home — contadores del día (solo en la tele, no se envían a ningún sitio).
 */
package tv.sgalfa.home;

import android.content.Context;
import android.content.SharedPreferences;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public final class Stats {

    private static final String PREFS = "sgalfa_stats";
    public static final String ADS = "ads";
    public static final String ACTIONS = "actions";

    private Stats() {
    }

    private static String today() {
        return new SimpleDateFormat("yyyyMMdd", Locale.ROOT).format(new Date());
    }

    private static SharedPreferences prefs(Context c) {
        SharedPreferences p = c.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String day = today();
        if (!day.equals(p.getString("day", ""))) {
            p.edit().clear().putString("day", day).apply();
        }
        return p;
    }

    public static synchronized void add(Context c, String key) {
        SharedPreferences p = prefs(c);
        p.edit().putInt(key, p.getInt(key, 0) + 1).apply();
    }

    public static int get(Context c, String key) {
        return prefs(c).getInt(key, 0);
    }
}
