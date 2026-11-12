/*
 * SG Alfa Home — recibe automatizaciones desde la app del teléfono (por ADB).
 */
package tv.sgalfa.home;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * Protegido con el permiso DUMP en el manifiesto: solo ADB puede enviarlo, ninguna otra app de la tele.
 * Uso: am broadcast -n tv.sgalfa.home/tv.sgalfa.home.RulesReceiver --es macros '<json en base64>'
 */
public class RulesReceiver extends BroadcastReceiver {

    public static final String ACTION = "tv.sgalfa.home.SET_AUTOMATIONS";
    public static final String EXTRA_MACROS = "macros";
    private static final int MAX_CHARS = 100_000;

    @Override
    public void onReceive(Context context, Intent intent) {
        String encoded = intent.getStringExtra(EXTRA_MACROS);
        if (encoded == null) return;
        String json;
        try {
            json = new String(Base64.decode(encoded, Base64.DEFAULT), StandardCharsets.UTF_8);
        } catch (Exception e) {
            return;
        }
        if (json.length() > MAX_CHARS) return;
        List<Macros.Macro> list = Macros.decodeOrNull(json);
        if (list == null) return;
        AutoClickService.save(context, list);
        try {
            setResultCode(Activity.RESULT_OK);
            setResultData("ok " + list.size());
        } catch (Exception ignored) {
        }
    }
}
