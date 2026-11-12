/*
 * SG Alfa Home — bloqueo de anuncios por DNS.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.VpnService;
import android.os.ParcelFileDescriptor;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/**
 * Bloqueo de anuncios SIN root: una VPN local que NO saca tu tráfico fuera de la tele.
 * Solo pasan por ella las consultas DNS, que se reenvían a AdGuard DNS (filtra anuncios,
 * pop-ups y rastreadores). Además, una lista local responde 0.0.0.0 a dominios conocidos.
 * El resto del tráfico va directo, así que no se rompe nada por error.
 */
public class DnsBlockVpnService extends VpnService {

    public static final String ACTION_START = "tv.sgalfa.home.ADBLOCK_START";
    public static final String ACTION_STOP = "tv.sgalfa.home.ADBLOCK_STOP";
    static final String UPSTREAM = "94.140.14.14";   // AdGuard DNS
    static final String UPSTREAM2 = "94.140.15.15";

    private static final String PREFS = "sgalfa_protection";
    private static final String KEY_WANTED = "adblock_wanted";

    private static volatile boolean running = false;
    private ParcelFileDescriptor vpn;
    private Thread worker;
    private volatile Set<String> blocklist = new HashSet<>();

    public static boolean isRunning() {
        return running;
    }

    /** ¿El usuario lo dejó encendido? (para volver a arrancarlo tras reiniciar). */
    public static boolean isWanted(Context c) {
        return c.getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(KEY_WANTED, false);
    }

    static void setWanted(Context c, boolean wanted) {
        c.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(KEY_WANTED, wanted).apply();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            setWanted(this, false);
            stopBlocking();
            stopSelf();
            return START_NOT_STICKY;
        }
        setWanted(this, true);
        startBlocking();
        return START_STICKY;
    }

    private Set<String> loadBlocklist() {
        Set<String> set = new HashSet<>();
        try (BufferedReader r = new BufferedReader(
                new InputStreamReader(getAssets().open("blocklist.txt"), StandardCharsets.UTF_8))) {
            String line;
            while ((line = r.readLine()) != null) {
                line = line.trim().toLowerCase(Locale.ROOT);
                if (!line.isEmpty() && !line.startsWith("#")) set.add(line);
            }
        } catch (Exception ignored) {
        }
        return set;
    }

    private synchronized void startBlocking() {
        if (running) return;
        if (blocklist.isEmpty()) blocklist = loadBlocklist();
        ParcelFileDescriptor pfd;
        try {
            pfd = new Builder()
                    .setSession("SG Alfa — bloqueo de anuncios")
                    .addAddress("10.111.222.2", 32)
                    .addDnsServer(UPSTREAM)
                    .addDnsServer(UPSTREAM2)
                    .addRoute(UPSTREAM, 32)
                    .addRoute(UPSTREAM2, 32)
                    .setBlocking(true)
                    .establish();
        } catch (Exception e) {
            pfd = null;
        }
        if (pfd == null) return;
        vpn = pfd;
        running = true;
        final ParcelFileDescriptor tunnel = pfd;
        worker = new Thread(() -> pump(tunnel), "sgalfa-dns");
        worker.start();
    }

    private synchronized void stopBlocking() {
        running = false;
        if (worker != null) worker.interrupt();
        try {
            if (vpn != null) vpn.close();
        } catch (Exception ignored) {
        }
        vpn = null;
    }

    @Override
    public void onRevoke() {
        // Otra VPN (p. ej. AdGuard o Blokada) tomó el control.
        setWanted(this, false);
        stopBlocking();
        super.onRevoke();
    }

    @Override
    public void onDestroy() {
        stopBlocking();
        super.onDestroy();
    }

    private void pump(ParcelFileDescriptor pfd) {
        FileInputStream input = new FileInputStream(pfd.getFileDescriptor());
        FileOutputStream output = new FileOutputStream(pfd.getFileDescriptor());
        DatagramSocket socket = null;
        byte[] packet = new byte[32767];
        try {
            socket = new DatagramSocket();
            protect(socket);
            socket.setSoTimeout(4000);
            while (running) {
                int len = input.read(packet);
                if (len <= 20) continue;
                if ((packet[0] & 0xF0) != 0x40) continue; // solo IPv4
                int ihl = (packet[0] & 0x0F) * 4;
                if ((packet[9] & 0xFF) != 17) continue; // solo UDP
                if (len < ihl + 8) continue;
                byte[] srcIp = slice(packet, 12, 16);
                byte[] dstIp = slice(packet, 16, 20);
                int srcPort = ((packet[ihl] & 0xFF) << 8) | (packet[ihl + 1] & 0xFF);
                int dstPort = ((packet[ihl + 2] & 0xFF) << 8) | (packet[ihl + 3] & 0xFF);
                if (dstPort != 53) continue;
                byte[] query = slice(packet, ihl + 8, len);

                String host = qname(query);
                byte[] answer;
                if (host != null && isBlocked(host)) {
                    answer = buildBlockedDns(query);
                    Stats.add(this, Stats.ADS);
                } else {
                    answer = forward(socket, dstIp, query);
                    if (answer != null && isNullAnswer(answer)) Stats.add(this, Stats.ADS); // filtrado por AdGuard
                }
                if (answer != null) {
                    output.write(buildUdpIpv4(dstIp, srcIp, dstPort, srcPort, answer));
                }
            }
        } catch (Exception ignored) {
            // túnel cerrado
        } finally {
            if (socket != null) socket.close();
        }
    }

    private static byte[] slice(byte[] a, int from, int to) {
        byte[] out = new byte[to - from];
        System.arraycopy(a, from, out, 0, out.length);
        return out;
    }

    private static byte[] forward(DatagramSocket socket, byte[] dnsIp, byte[] query) {
        try {
            InetAddress addr = InetAddress.getByAddress(dnsIp);
            socket.send(new DatagramPacket(query, query.length, addr, 53));
            byte[] buf = new byte[1500];
            DatagramPacket resp = new DatagramPacket(buf, buf.length);
            socket.receive(resp);
            return slice(buf, 0, resp.getLength());
        } catch (Exception e) {
            return null;
        }
    }

    static byte[] buildUdpIpv4(byte[] srcIp, byte[] dstIp, int srcPort, int dstPort, byte[] payload) {
        int udpLen = 8 + payload.length;
        int totalLen = 20 + udpLen;
        byte[] p = new byte[totalLen];
        p[0] = 0x45;
        p[2] = (byte) (totalLen >> 8);
        p[3] = (byte) totalLen;
        p[6] = 0x40; // no fragmentar
        p[8] = 64;   // TTL
        p[9] = 17;   // UDP
        System.arraycopy(srcIp, 0, p, 12, 4);
        System.arraycopy(dstIp, 0, p, 16, 4);
        int ipChecksum = checksum(p, 0, 20);
        p[10] = (byte) (ipChecksum >> 8);
        p[11] = (byte) ipChecksum;
        int u = 20;
        p[u] = (byte) (srcPort >> 8);
        p[u + 1] = (byte) srcPort;
        p[u + 2] = (byte) (dstPort >> 8);
        p[u + 3] = (byte) dstPort;
        p[u + 4] = (byte) (udpLen >> 8);
        p[u + 5] = (byte) udpLen;
        System.arraycopy(payload, 0, p, u + 8, payload.length);
        return p;
    }

    static int checksum(byte[] data, int offset, int length) {
        long sum = 0;
        int i = offset;
        int end = offset + length;
        while (i + 1 < end) {
            sum += ((data[i] & 0xFF) << 8) | (data[i + 1] & 0xFF);
            i += 2;
        }
        if (i < end) sum += (data[i] & 0xFF) << 8;
        while ((sum >> 16) != 0) sum = (sum & 0xFFFF) + (sum >> 16);
        return (int) (~sum & 0xFFFF);
    }

    static String qname(byte[] dns) {
        if (dns.length < 13) return null;
        int i = 12;
        StringBuilder sb = new StringBuilder();
        while (i < dns.length) {
            int len = dns[i] & 0xFF;
            if (len == 0) break;
            if ((len & 0xC0) != 0) return null;
            i++;
            if (i + len > dns.length) return null;
            if (sb.length() > 0) sb.append('.');
            for (int j = 0; j < len; j++) sb.append((char) (dns[i + j] & 0xFF));
            i += len;
        }
        String host = sb.toString().toLowerCase(Locale.ROOT);
        return host.isEmpty() ? null : host;
    }

    private boolean isBlocked(String host) {
        Set<String> list = blocklist;
        if (list.contains(host)) return true;
        int dot = host.indexOf('.');
        while (dot >= 0 && dot + 1 < host.length()) {
            if (list.contains(host.substring(dot + 1))) return true;
            dot = host.indexOf('.', dot + 1);
        }
        return false;
    }

    /** ¿La respuesta apunta a 0.0.0.0? (así responde AdGuard DNS cuando bloquea). */
    static boolean isNullAnswer(byte[] dns) {
        if (dns.length < 12) return false;
        int ancount = ((dns[6] & 0xFF) << 8) | (dns[7] & 0xFF);
        if (ancount == 0) return false;
        int i = questionEnd(dns);
        if (i < 0) return false;
        for (int a = 0; a < ancount && i < dns.length; a++) {
            // nombre: puntero (2 bytes) o etiquetas
            if ((dns[i] & 0xC0) == 0xC0) {
                i += 2;
            } else {
                while (i < dns.length && dns[i] != 0) i += (dns[i] & 0xFF) + 1;
                i++;
            }
            if (i + 10 > dns.length) return false;
            int type = ((dns[i] & 0xFF) << 8) | (dns[i + 1] & 0xFF);
            int rdlen = ((dns[i + 8] & 0xFF) << 8) | (dns[i + 9] & 0xFF);
            i += 10;
            if (i + rdlen > dns.length) return false;
            if (type == 1 && rdlen == 4) {
                return dns[i] == 0 && dns[i + 1] == 0 && dns[i + 2] == 0 && dns[i + 3] == 0;
            }
            i += rdlen;
        }
        return false;
    }

    private static int questionEnd(byte[] dns) {
        int i = 12;
        while (i < dns.length) {
            int len = dns[i] & 0xFF;
            if (len == 0) {
                i++;
                break;
            }
            i += 1 + len;
            if (i > dns.length) return -1;
        }
        i += 4;
        return i <= dns.length ? i : -1;
    }

    /** Respuesta DNS que apunta el dominio a 0.0.0.0 (bloqueado). */
    static byte[] buildBlockedDns(byte[] query) {
        int qEnd = questionEnd(query);
        if (qEnd < 0) return null;
        int qtype = ((query[qEnd - 4] & 0xFF) << 8) | (query[qEnd - 3] & 0xFF);
        boolean isA = qtype == 1;
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(query, 0, 2);
        out.write(0x81);
        out.write(0x80);
        out.write(0x00);
        out.write(0x01);
        out.write(0x00);
        out.write(isA ? 0x01 : 0x00);
        out.write(0x00);
        out.write(0x00);
        out.write(0x00);
        out.write(0x00);
        out.write(query, 12, qEnd - 12);
        if (isA) {
            int[] tail = {0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x01, 0x2C, 0x00, 0x04, 0, 0, 0, 0};
            for (int b : tail) out.write(b);
        }
        return out.toByteArray();
    }
}
