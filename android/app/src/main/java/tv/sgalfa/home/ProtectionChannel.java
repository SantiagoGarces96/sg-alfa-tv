/*
 * SG Alfa Home — puente entre Flutter (pantalla «Protección SG Alfa») y lo nativo.
 */
package tv.sgalfa.home;

import android.app.Activity;
import android.content.Intent;
import android.net.VpnService;
import android.provider.Settings;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

public final class ProtectionChannel {

    public static final String CHANNEL = "tv.sgalfa.home/protection";
    private static final int REQ_VPN = 4711;

    private final Activity activity;
    private MethodChannel.Result pendingVpn;

    public ProtectionChannel(Activity activity) {
        this.activity = activity;
    }

    public void register(BinaryMessenger messenger) {
        new MethodChannel(messenger, CHANNEL).setMethodCallHandler((call, result) -> {
            try {
                switch (call.method) {
                    case "getState":
                        result.success(state());
                        break;
                    case "setAdblock":
                        setAdblock(Boolean.TRUE.equals(call.arguments), result);
                        break;
                    case "openAccessibilitySettings":
                        activity.startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                        result.success(true);
                        break;
                    case "getToday": {
                        // En otro hilo: leer el historial de uso puede tardar un poco.
                        new Thread(() -> {
                            Map<String, Object> t = new HashMap<>();
                            t.put("ads", Stats.get(activity, Stats.ADS));
                            t.put("actions", Stats.get(activity, Stats.ACTIONS));
                            t.put("adblock", DnsBlockVpnService.isRunning());
                            t.put("automation", AutoClickService.isEnabled(activity));
                            Map<String, Object> s = null;
                            try {
                                s = Habits.suggestion(activity);
                            } catch (Exception ignored) {
                            }
                            t.put("suggestion", s);
                            activity.runOnUiThread(() -> result.success(t));
                        }, "sgalfa-today").start();
                        break;
                    }
                    case "getMacrosFull":
                        result.success(macrosFull(AutoClickService.load(activity)));
                        break;
                    case "getTemplates":
                        result.success(macrosFull(Macros.templates()));
                        break;
                    case "describe":
                        result.success(Macros.describe(fromMap(call.arguments())));
                        break;
                    case "validate":
                        result.success(Macros.validate(fromMap(call.arguments())));
                        break;
                    case "saveMacro": {
                        Macros.Macro m = fromMap(call.arguments());
                        String error = Macros.validate(m);
                        if (error != null) {
                            result.error("invalid", error, null);
                            break;
                        }
                        List<Macros.Macro> list = new ArrayList<>(AutoClickService.load(activity));
                        boolean replaced = false;
                        for (int i = 0; i < list.size(); i++) {
                            if (list.get(i).id.equals(m.id)) {
                                list.set(i, m);
                                replaced = true;
                            }
                        }
                        if (!replaced) list.add(m);
                        AutoClickService.save(activity, list);
                        result.success(macrosFull(list));
                        break;
                    }
                    case "deleteMacro": {
                        String id = call.arguments();
                        List<Macros.Macro> list = new ArrayList<>(AutoClickService.load(activity));
                        for (int i = list.size() - 1; i >= 0; i--) {
                            if (list.get(i).id.equals(id)) list.remove(i);
                        }
                        AutoClickService.save(activity, list);
                        result.success(macrosFull(list));
                        break;
                    }
                    case "setMacroEnabled": {
                        String id = call.argument("id");
                        Boolean on = call.argument("enabled");
                        setMacroEnabled(id, Boolean.TRUE.equals(on));
                        result.success(state());
                        break;
                    }
                    default:
                        result.notImplemented();
                }
            } catch (Exception e) {
                result.error("sgalfa", e.getMessage(), null);
            }
        });
    }

    /** Al abrir el launcher (p. ej. tras reiniciar la tele) vuelve a encender el bloqueo si estaba puesto. */
    public static void resumeIfWanted(Activity a) {
        if (DnsBlockVpnService.isWanted(a) && !DnsBlockVpnService.isRunning() && VpnService.prepare(a) == null) {
            a.startService(new Intent(a, DnsBlockVpnService.class).setAction(DnsBlockVpnService.ACTION_START));
        }
    }

    private Map<String, Object> state() {
        Map<String, Object> m = new HashMap<>();
        m.put("adblock", DnsBlockVpnService.isRunning());
        m.put("automation", AutoClickService.isEnabled(activity));
        List<Map<String, Object>> list = new ArrayList<>();
        for (Macros.Macro macro : AutoClickService.load(activity)) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", macro.id);
            item.put("name", macro.name);
            item.put("enabled", macro.enabled);
            item.put("description", Macros.describe(macro));
            list.add(item);
        }
        m.put("macros", list);
        return m;
    }

    /** Automatizaciones completas para el editor de la tele. */
    private static List<Map<String, Object>> macrosFull(List<Macros.Macro> macros) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (Macros.Macro m : macros) {
            Map<String, Object> o = new HashMap<>();
            o.put("id", m.id);
            o.put("name", m.name);
            o.put("enabled", m.enabled);
            o.put("trigger", m.trigger);
            o.put("text", m.text);
            o.put("context", new ArrayList<>(m.context));
            o.put("action", m.action);
            o.put("app", m.app);
            o.put("delaySeconds", m.delaySeconds);
            o.put("description", Macros.describe(m));
            out.add(o);
        }
        return out;
    }

    @SuppressWarnings("unchecked")
    private static Macros.Macro fromMap(Object raw) {
        Map<String, Object> o = raw instanceof Map ? (Map<String, Object>) raw : new HashMap<>();
        List<String> ctx = new ArrayList<>();
        Object c = o.get("context");
        if (c instanceof List) {
            for (Object x : (List<Object>) c) {
                if (x != null && !x.toString().trim().isEmpty()) ctx.add(x.toString().trim());
            }
        }
        Object delay = o.get("delaySeconds");
        String id = str(o.get("id"));
        return new Macros.Macro(
                id.isEmpty() ? java.util.UUID.randomUUID().toString().substring(0, 8) : id,
                str(o.get("name")).trim(),
                !Boolean.FALSE.equals(o.get("enabled")),
                "TEXT".equals(o.get("trigger")) ? "TEXT" : "BUTTON",
                str(o.get("text")).trim(),
                ctx,
                "BACK".equals(o.get("action")) ? "BACK" : "HOME".equals(o.get("action")) ? "HOME" : "CLICK",
                str(o.get("app")).trim(),
                delay instanceof Number ? ((Number) delay).intValue() : 0);
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }

    private void setMacroEnabled(String id, boolean on) {
        List<Macros.Macro> list = new ArrayList<>(AutoClickService.load(activity));
        for (int i = 0; i < list.size(); i++) {
            if (list.get(i).id.equals(id)) list.set(i, list.get(i).withEnabled(on));
        }
        AutoClickService.save(activity, list);
    }

    private void setAdblock(boolean on, MethodChannel.Result result) {
        if (!on) {
            activity.startService(new Intent(activity, DnsBlockVpnService.class).setAction(DnsBlockVpnService.ACTION_STOP));
            result.success(false);
            return;
        }
        Intent prepare = VpnService.prepare(activity);
        if (prepare == null) {
            startVpn();
            result.success(true);
        } else {
            // La tele pide permiso una vez («¿Permitir conexión VPN?»).
            pendingVpn = result;
            activity.startActivityForResult(prepare, REQ_VPN);
        }
    }

    private void startVpn() {
        activity.startService(new Intent(activity, DnsBlockVpnService.class).setAction(DnsBlockVpnService.ACTION_START));
    }

    /** Llamar desde MainActivity.onActivityResult. Devuelve true si era nuestro. */
    public boolean onActivityResult(int requestCode, int resultCode) {
        if (requestCode != REQ_VPN) return false;
        boolean ok = resultCode == Activity.RESULT_OK;
        if (ok) startVpn();
        if (pendingVpn != null) {
            pendingVpn.success(ok);
            pendingVpn = null;
        }
        return true;
    }
}
