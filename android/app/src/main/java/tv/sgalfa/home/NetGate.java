/*
 * SG Alfa Home — abrir apps cuando ya hay internet.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.app.Activity;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

/**
 * Al encender la tele, el wifi tarda unos segundos en conectar. Si se abre una app en ese momento
 * (TizenTube, WiwyXuper…) sale «Can't connect» y se queda ahí. Aquí se espera a que haya internet
 * (como mucho 25 s) y la app se abre sola en cuanto conecta.
 */
final class NetGate {
    private NetGate() {
    }

    private static final long MAX_WAIT_MS = 25_000;
    private static final Handler main = new Handler(Looper.getMainLooper());
    private static ConnectivityManager.NetworkCallback pending;
    private static Runnable pendingTimeout;

    /** Apps que funcionan sin internet: se abren al momento. */
    private static boolean offlineApp(String pkg) {
        if (pkg == null) return true;
        String p = pkg.toLowerCase(java.util.Locale.ROOT);
        return p.contains("settings") || p.contains("filemanager") || p.contains("livetv")
                || p.contains("usbmediaplayer") || p.contains("passthrough") || p.equals("tv.sgalfa.home")
                || p.contains("documentsui") || p.contains("files");
    }

    static boolean online(Context c) {
        try {
            ConnectivityManager cm = (ConnectivityManager) c.getSystemService(Context.CONNECTIVITY_SERVICE);
            Network n = cm.getActiveNetwork();
            if (n == null) return false;
            NetworkCapabilities nc = cm.getNetworkCapabilities(n);
            if (nc == null || !nc.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return false;
            return nc.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                    || nc.hasTransport(NetworkCapabilities.TRANSPORT_VPN);
        } catch (Exception e) {
            return true; // ante la duda, no bloquear
        }
    }

    /** Ejecuta {@code open} ya, o en cuanto haya internet. Devuelve true si se ejecutó al momento. */
    static boolean whenOnline(Activity a, String pkg, Runnable open) {
        cancel(a);
        if (offlineApp(pkg) || online(a)) {
            open.run();
            return true;
        }
        Toast.makeText(a, "Conectando a internet… la app se abrirá sola en cuanto haya conexión",
                Toast.LENGTH_LONG).show();
        final boolean[] done = {false};
        Runnable once = () -> {
            if (done[0]) return;
            done[0] = true;
            cancel(a);
            open.run();
        };
        try {
            ConnectivityManager cm = (ConnectivityManager) a.getSystemService(Context.CONNECTIVITY_SERVICE);
            pending = new ConnectivityManager.NetworkCallback() {
                @Override
                public void onCapabilitiesChanged(Network network, NetworkCapabilities nc) {
                    if (online(a)) main.post(once);
                }

                @Override
                public void onAvailable(Network network) {
                    main.postDelayed(() -> {
                        if (online(a)) once.run();
                    }, 1500);
                }
            };
            cm.registerDefaultNetworkCallback(pending);
        } catch (Exception e) {
            main.post(once);
            return false;
        }
        pendingTimeout = once; // pasado el tiempo, se abre igual
        main.postDelayed(pendingTimeout, MAX_WAIT_MS);
        return false;
    }

    private static void cancel(Context c) {
        if (pendingTimeout != null) {
            main.removeCallbacks(pendingTimeout);
            pendingTimeout = null;
        }
        if (pending != null) {
            try {
                ((ConnectivityManager) c.getSystemService(Context.CONNECTIVITY_SERVICE)).unregisterNetworkCallback(pending);
            } catch (Exception ignored) {
            }
            pending = null;
        }
    }
}
