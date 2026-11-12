/*
 * SG Alfa Home — lista de apps de la tele, imágenes y acciones (abrir, info, desinstalar).
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public final class LauncherChannel {

    public static final String CHANNEL = "tv.sgalfa.home/launcher";
    public static final String EVENTS = "tv.sgalfa.home/app-changes";

    private final Activity activity;
    private final ExecutorService io = Executors.newFixedThreadPool(2);
    private final Handler main = new Handler(Looper.getMainLooper());
    private MethodChannel channel;
    private BroadcastReceiver packageReceiver;

    public LauncherChannel(Activity activity) {
        this.activity = activity;
    }

    public void register(BinaryMessenger messenger) {
        channel = new MethodChannel(messenger, CHANNEL);
        channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "listApps":
                    io.execute(() -> {
                        List<Map<String, Object>> apps = listApps();
                        main.post(() -> result.success(apps));
                    });
                    break;
                case "appImage": {
                    String pkg = call.argument("package");
                    io.execute(() -> {
                        byte[] png = appImage(pkg);
                        main.post(() -> result.success(png));
                    });
                    break;
                }
                case "launch":
                    result.success(launch(call.arguments()));
                    break;
                case "appInfo":
                    result.success(start(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", (String) call.arguments(), null))));
                    break;
                case "uninstall":
                    result.success(start(new Intent(Intent.ACTION_DELETE,
                            Uri.fromParts("package", (String) call.arguments(), null))));
                    break;
                case "openSystemSettings":
                    result.success(start(new Intent(Settings.ACTION_SETTINGS)));
                    break;
                case "openWifiSettings":
                    result.success(start(new Intent(Settings.ACTION_WIFI_SETTINGS)));
                    break;
                case "network":
                    result.success(network());
                    break;
                case "isDefaultHome":
                    result.success(isDefaultHome());
                    break;
                default:
                    result.notImplemented();
            }
        });

        new EventChannel(messenger, EVENTS).setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object args, EventChannel.EventSink sink) {
                packageReceiver = new BroadcastReceiver() {
                    @Override
                    public void onReceive(Context c, Intent i) {
                        sink.success(i.getAction());
                    }
                };
                IntentFilter f = new IntentFilter();
                f.addAction(Intent.ACTION_PACKAGE_ADDED);
                f.addAction(Intent.ACTION_PACKAGE_REMOVED);
                f.addAction(Intent.ACTION_PACKAGE_CHANGED);
                f.addDataScheme("package");
                activity.registerReceiver(packageReceiver, f);
            }

            @Override
            public void onCancel(Object args) {
                if (packageReceiver != null) {
                    try {
                        activity.unregisterReceiver(packageReceiver);
                    } catch (Exception ignored) {
                    }
                    packageReceiver = null;
                }
            }
        });
    }

    /** Avisa a Flutter de que se pulsó Inicio estando ya en el inicio. */
    public void homePressed() {
        if (channel != null) channel.invokeMethod("homePressed", null);
    }

    private List<Map<String, Object>> listApps() {
        PackageManager pm = activity.getPackageManager();
        Map<String, Map<String, Object>> byPkg = new LinkedHashMap<>();
        addFrom(pm, Intent.CATEGORY_LEANBACK_LAUNCHER, true, byPkg);
        addFrom(pm, Intent.CATEGORY_LAUNCHER, false, byPkg);
        byPkg.remove(activity.getPackageName());
        return new ArrayList<>(byPkg.values());
    }

    private void addFrom(PackageManager pm, String category, boolean tv, Map<String, Map<String, Object>> out) {
        Intent i = new Intent(Intent.ACTION_MAIN).addCategory(category);
        for (ResolveInfo r : pm.queryIntentActivities(i, 0)) {
            String pkg = r.activityInfo.packageName;
            if (out.containsKey(pkg)) continue;
            ApplicationInfo ai = r.activityInfo.applicationInfo;
            Map<String, Object> m = new HashMap<>();
            m.put("package", pkg);
            m.put("label", String.valueOf(r.loadLabel(pm)));
            m.put("tv", tv);
            m.put("system", (ai.flags & ApplicationInfo.FLAG_SYSTEM) != 0);
            m.put("hasBanner", tv && (r.activityInfo.banner != 0 || ai.banner != 0));
            out.put(pkg, m);
        }
    }

    /** Banner de TV si lo tiene; si no, el icono. En PNG. */
    private byte[] appImage(String pkg) {
        try {
            PackageManager pm = activity.getPackageManager();
            Drawable d = null;
            Intent tv = pm.getLeanbackLaunchIntentForPackage(pkg);
            if (tv != null && tv.getComponent() != null) {
                try {
                    d = pm.getActivityBanner(tv.getComponent());
                } catch (Exception ignored) {
                }
            }
            if (d == null) d = pm.getApplicationBanner(pkg);
            boolean banner = d != null;
            if (d == null) d = pm.getApplicationIcon(pkg);
            return toPng(d, banner ? 320 : 192, banner ? 180 : 192);
        } catch (Exception e) {
            return null;
        }
    }

    private static byte[] toPng(Drawable d, int w, int h) {
        Bitmap bmp;
        if (d instanceof BitmapDrawable && ((BitmapDrawable) d).getBitmap() != null) {
            bmp = ((BitmapDrawable) d).getBitmap();
        } else {
            int iw = d.getIntrinsicWidth() > 0 ? d.getIntrinsicWidth() : w;
            int ih = d.getIntrinsicHeight() > 0 ? d.getIntrinsicHeight() : h;
            bmp = Bitmap.createBitmap(iw, ih, Bitmap.Config.ARGB_8888);
            Canvas c = new Canvas(bmp);
            d.setBounds(0, 0, iw, ih);
            d.draw(c);
        }
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out);
        return out.toByteArray();
    }

    private boolean launch(String pkg) {
        PackageManager pm = activity.getPackageManager();
        Intent i = pm.getLeanbackLaunchIntentForPackage(pkg);
        if (i == null) i = pm.getLaunchIntentForPackage(pkg);
        return i != null && start(i);
    }

    private boolean start(Intent i) {
        try {
            activity.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private Map<String, Object> network() {
        Map<String, Object> m = new HashMap<>();
        ConnectivityManager cm = (ConnectivityManager) activity.getSystemService(Context.CONNECTIVITY_SERVICE);
        String type = "none";
        try {
            NetworkCapabilities nc = cm.getNetworkCapabilities(cm.getActiveNetwork());
            if (nc != null) {
                if (nc.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) type = "ethernet";
                else if (nc.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) type = "wifi";
                else type = "other";
            }
        } catch (Exception ignored) {
        }
        m.put("type", type);
        return m;
    }

    private boolean isDefaultHome() {
        Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        ResolveInfo r = activity.getPackageManager().resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY);
        return r != null && r.activityInfo != null && activity.getPackageName().equals(r.activityInfo.packageName);
    }

}
