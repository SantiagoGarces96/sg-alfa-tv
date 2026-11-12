/*
 * SG Alfa Home — automatizaciones estilo MacroDroid.
 * Mismo formato JSON y mismas reglas que el módulo :automation de la app del teléfono
 * (tv-debloater/automation/.../Macros.kt). Si cambias uno, cambia el otro.
 */
package tv.sgalfa.home;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

public final class Macros {

    private Macros() {
    }

    /** CUANDO: aparece un botón (BUTTON) o un texto (TEXT). ENTONCES: CLICK, BACK o HOME. */
    public static final class Macro {
        public final String id;
        public final String name;
        public final boolean enabled;
        public final String trigger; // BUTTON | TEXT
        public final String text;
        public final List<String> context;
        public final String action;  // CLICK | BACK | HOME
        public final String app;
        public final int delaySeconds;

        public Macro(String id, String name, boolean enabled, String trigger, String text,
                     List<String> context, String action, String app, int delaySeconds) {
            this.id = id;
            this.name = name;
            this.enabled = enabled;
            this.trigger = trigger;
            this.text = text;
            this.context = context;
            this.action = action;
            this.app = app;
            this.delaySeconds = delaySeconds;
        }

        Macro withEnabled(boolean on) {
            return new Macro(id, name, on, trigger, text, context, action, app, delaySeconds);
        }
    }

    // ---------- JSON ----------

    public static String encode(List<Macro> list) {
        JSONArray arr = new JSONArray();
        try {
            for (Macro m : list) {
                JSONObject o = new JSONObject();
                o.put("id", m.id);
                o.put("name", m.name);
                o.put("enabled", m.enabled);
                o.put("trigger", m.trigger);
                o.put("text", m.text);
                o.put("context", new JSONArray(m.context));
                o.put("action", m.action);
                o.put("app", m.app);
                o.put("delaySeconds", m.delaySeconds);
                arr.put(o);
            }
        } catch (Exception ignored) {
        }
        return arr.toString();
    }

    /** null si el texto no es una lista válida. */
    public static List<Macro> decodeOrNull(String text) {
        if (text == null) return null;
        try {
            JSONArray arr = new JSONArray(text);
            List<Macro> out = new ArrayList<>();
            for (int i = 0; i < arr.length(); i++) {
                JSONObject o = arr.getJSONObject(i);
                List<String> ctx = new ArrayList<>();
                JSONArray c = o.optJSONArray("context");
                if (c != null) for (int j = 0; j < c.length(); j++) ctx.add(c.optString(j, ""));
                String trigger = o.optString("trigger", "BUTTON");
                String action = o.optString("action", "CLICK");
                if (!trigger.equals("BUTTON") && !trigger.equals("TEXT")) return null;
                if (!action.equals("CLICK") && !action.equals("BACK") && !action.equals("HOME")) return null;
                out.add(new Macro(
                        o.getString("id"),
                        o.getString("name"),
                        o.optBoolean("enabled", true),
                        trigger,
                        o.optString("text", ""),
                        ctx,
                        action,
                        o.optString("app", ""),
                        o.optInt("delaySeconds", 0)));
            }
            return out;
        } catch (Exception e) {
            return null;
        }
    }

    // ---------- Comparación ----------

    private static final Pattern NON_WORD = Pattern.compile("[^\\p{L}\\p{N} ]");
    private static final Pattern SPACES = Pattern.compile("\\s+");

    public static String normalize(String s) {
        if (s == null) return "";
        String lower = s.toLowerCase(Locale.ROOT);
        return SPACES.matcher(NON_WORD.matcher(lower).replaceAll(" ")).replaceAll(" ").trim();
    }

    private static boolean appMatches(Macro m, String pkg) {
        return m.app == null || m.app.trim().isEmpty() || m.app.equals(pkg);
    }

    private static boolean contextMatches(Macro m, String normalizedScreen) {
        if (m.context.isEmpty()) return true;
        for (String c : m.context) {
            String n = normalize(c);
            if (!n.isEmpty() && normalizedScreen.contains(n)) return true;
        }
        return false;
    }

    public static boolean buttonMatches(Macro m, String buttonText, String screenText, String pkg) {
        if (!m.enabled || !"BUTTON".equals(m.trigger) || !appMatches(m, pkg)) return false;
        String button = normalize(buttonText);
        String wanted = normalize(m.text);
        if (wanted.isEmpty() || button.isEmpty() || button.length() > 40) return false;
        boolean hit = (m.context.isEmpty() && wanted.length() >= 6)
                ? (button.equals(wanted) || button.contains(wanted))
                : button.equals(wanted);
        return hit && contextMatches(m, normalize(screenText));
    }

    public static boolean textMatches(Macro m, String screenText, String pkg) {
        if (!m.enabled || !"TEXT".equals(m.trigger) || !appMatches(m, pkg)) return false;
        String wanted = normalize(m.text);
        if (wanted.length() < 3) return false;
        String screen = normalize(screenText);
        return screen.contains(wanted) && contextMatches(m, screen);
    }

    /** null si está bien; si no, qué hay que corregir (igual que en el teléfono). */
    public static String validate(Macro m) {
        if (m.name == null || m.name.trim().isEmpty()) return "Ponle un nombre.";
        if (normalize(m.text).length() < 2) return "Escribe el texto que tiene que aparecer.";
        if ("TEXT".equals(m.trigger) && normalize(m.text).length() < 3) return "El texto tiene que tener al menos 3 letras.";
        if ("TEXT".equals(m.trigger) && "CLICK".equals(m.action))
            return "«Pulsar ese botón» solo sirve cuando el disparador es un botón.";
        if (m.delaySeconds < 0 || m.delaySeconds > 30) return "La espera tiene que estar entre 0 y 30 segundos.";
        return null;
    }

    /** Frase que explica la automatización (igual que en el teléfono). */
    public static String describe(Macro m) {
        String trigger = "BUTTON".equals(m.trigger)
                ? "Cuando aparezca el botón «" + m.text.trim() + "»"
                : "Cuando aparezca en pantalla «" + m.text.trim() + "»";
        StringBuilder ctx = new StringBuilder();
        for (String c : m.context) {
            if (c.trim().isEmpty()) continue;
            ctx.append(ctx.length() == 0 ? " y también se vea " : " o ").append("«").append(c.trim()).append("»");
        }
        String app = (m.app != null && !m.app.trim().isEmpty()) ? " en " + m.app : "";
        String action;
        switch (m.action) {
            case "BACK": action = "pulsar Atrás"; break;
            case "HOME": action = "ir al inicio"; break;
            default: action = "pulsarlo";
        }
        String delay = m.delaySeconds > 0 ? "tras " + m.delaySeconds + " s" : "al instante";
        return trigger + ctx + app + ", " + action + " " + delay + ".";
    }

    // ---------- Plantillas ----------

    private static final List<String> AD_WORDS = Arrays.asList(
            "anuncio", "publicidad", "patrocinado", "advertisement", "sponsored", "promocion", "promoción");

    private static Macro button(String id, String name, String text, List<String> ctx) {
        return new Macro(id, name, true, "BUTTON", text, ctx, "CLICK", "", 0);
    }

    private static Macro button(String id, String name, String text) {
        return button(id, name, text, Collections.emptyList());
    }

    /** Las que vienen activadas de inicio. */
    public static List<Macro> templates() {
        return Arrays.asList(
                button("tpl-continuar", "Seguir usando la app", "Continuar usando"),
                button("tpl-seguir", "Seguir viendo", "Seguir viendo"),
                button("tpl-cont-viendo", "Continuar viendo", "Continuar viendo"),
                button("tpl-si", "¿Sigues viendo? → Sí", "Sí",
                        Arrays.asList("sigues viendo", "continuar viendo", "deseas continuar")),
                button("tpl-saltar", "Saltar anuncio", "Saltar anuncio"),
                button("tpl-omitir", "Omitir anuncio", "Omitir anuncio"),
                button("tpl-skip", "Skip ad (inglés)", "Skip ad"),
                button("tpl-keep", "Keep watching (inglés)", "Keep watching"),
                button("tpl-continue", "Continue watching (inglés)", "Continue watching"),
                button("tpl-yes", "Still watching? → Yes (inglés)", "Yes",
                        Arrays.asList("still watching", "continue watching")),
                // Ventanas emergentes (pop-ups) de anuncios
                button("tpl-pop-cerrar-anuncio", "Pop-up: Cerrar anuncio", "Cerrar anuncio"),
                button("tpl-pop-close-ad", "Pop-up: Close ad (inglés)", "Close ad"),
                button("tpl-pop-cerrar", "Pop-up de anuncio → Cerrar", "Cerrar", AD_WORDS),
                button("tpl-pop-close", "Pop-up de anuncio → Close (inglés)", "Close", AD_WORDS),
                button("tpl-pop-nogracias", "Pop-up de oferta → No, gracias", "No, gracias",
                        Arrays.asList("oferta", "premium", "suscríbete", "suscribete", "promoción", "promocion"))
        );
    }
}
