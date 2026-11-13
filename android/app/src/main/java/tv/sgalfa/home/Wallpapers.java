/*
 * SG Alfa Home — fondos con tus propias imágenes (fotos del deco, descargas o un USB).
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.Manifest;
import android.app.Activity;
import android.content.ContentUris;
import android.content.Context;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;
import android.util.Size;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class Wallpapers {

    private Wallpapers() {
    }

    private static String permission() {
        return Build.VERSION.SDK_INT >= 33 ? "android.permission.READ_MEDIA_IMAGES" : Manifest.permission.READ_EXTERNAL_STORAGE;
    }

    static boolean hasPermission(Context c) {
        return c.checkSelfPermission(permission()) == PackageManager.PERMISSION_GRANTED;
    }

    static void requestPermission(Activity a) {
        a.requestPermissions(new String[]{permission()}, 4712);
    }

    /** Imágenes del deco y de los USB conectados, las más nuevas primero. */
    static List<Map<String, Object>> list(Context c) {
        List<Map<String, Object>> out = new ArrayList<>();
        Set<String> volumes = MediaStore.getExternalVolumeNames(c);
        String[] cols = {MediaStore.Images.Media._ID, MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.DATE_MODIFIED, MediaStore.Images.Media.WIDTH, MediaStore.Images.Media.HEIGHT};
        for (String vol : volumes) {
            Uri base = MediaStore.Images.Media.getContentUri(vol);
            try (Cursor cur = c.getContentResolver().query(base, cols, null, null,
                    MediaStore.Images.Media.DATE_MODIFIED + " DESC")) {
                if (cur == null) continue;
                while (cur.moveToNext() && out.size() < 300) {
                    Map<String, Object> m = new HashMap<>();
                    m.put("uri", ContentUris.withAppendedId(base, cur.getLong(0)).toString());
                    m.put("name", cur.getString(1));
                    m.put("date", cur.getLong(2));
                    m.put("w", cur.getInt(3));
                    m.put("h", cur.getInt(4));
                    m.put("usb", !MediaStore.VOLUME_EXTERNAL_PRIMARY.equals(vol));
                    out.add(m);
                }
            } catch (Exception ignored) {
            }
        }
        out.sort((a, b) -> Long.compare((Long) b.get("date"), (Long) a.get("date")));
        return out;
    }

    /** Miniatura pequeña para la galería. */
    static byte[] thumb(Context c, String uri) {
        try {
            Bitmap b = c.getContentResolver().loadThumbnail(Uri.parse(uri), new Size(320, 180), null);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            b.compress(Bitmap.CompressFormat.JPEG, 80, out);
            return out.toByteArray();
        } catch (Exception e) {
            return null;
        }
    }

    /** Copia la imagen elegida (reducida a tamaño de tele) y devuelve la ruta del archivo. */
    static String apply(Context c, String uri) {
        try {
            Uri u = Uri.parse(uri);
            BitmapFactory.Options o = new BitmapFactory.Options();
            o.inJustDecodeBounds = true;
            try (InputStream in = c.getContentResolver().openInputStream(u)) {
                BitmapFactory.decodeStream(in, null, o);
            }
            int sample = 1;
            while (o.outWidth / (sample * 2) >= 1920 && o.outHeight / (sample * 2) >= 1080) sample *= 2;
            BitmapFactory.Options o2 = new BitmapFactory.Options();
            o2.inSampleSize = sample;
            Bitmap bmp;
            try (InputStream in = c.getContentResolver().openInputStream(u)) {
                bmp = BitmapFactory.decodeStream(in, null, o2);
            }
            if (bmp == null) return null;
            File dir = new File(c.getFilesDir(), "wallpapers");
            //noinspection ResultOfMethodCallIgnored
            dir.mkdirs();
            File[] old = dir.listFiles();
            if (old != null) for (File f : old) //noinspection ResultOfMethodCallIgnored
                f.delete();
            File f = new File(dir, "mi-fondo-" + System.currentTimeMillis() + ".jpg");
            try (FileOutputStream out = new FileOutputStream(f)) {
                bmp.compress(Bitmap.CompressFormat.JPEG, 90, out);
            }
            return f.getAbsolutePath();
        } catch (Exception e) {
            return null;
        }
    }
}
