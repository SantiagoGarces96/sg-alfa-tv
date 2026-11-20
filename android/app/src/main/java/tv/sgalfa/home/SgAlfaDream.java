/*
 * SG Alfa Home — salvapantallas: hora, fecha, clima y lo que suena, moviéndose despacio para no
 * marcar la pantalla.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.service.dreams.DreamService;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextClock;
import android.widget.TextView;

import java.util.Random;

public class SgAlfaDream extends DreamService {
    private final Handler h = new Handler(Looper.getMainLooper());
    private final Random rnd = new Random();
    private LinearLayout box;
    private TextView playing;

    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();
        setInteractive(false);
        setFullscreen(true);
        setScreenBright(false); // brillo bajo: cuida la pantalla de noche

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setGravity(Gravity.CENTER_HORIZONTAL);

        TextClock clock = new TextClock(this);
        clock.setFormat12Hour("h:mm");
        clock.setFormat24Hour("h:mm");
        clock.setTextColor(Color.WHITE);
        clock.setTextSize(TypedValue.COMPLEX_UNIT_SP, 96);
        clock.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        box.addView(clock);

        TextClock date = new TextClock(this);
        date.setFormat12Hour("EEEE d 'de' MMMM · a");
        date.setFormat24Hour("EEEE d 'de' MMMM");
        date.setTextColor(0xCCFFFFFF);
        date.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        box.addView(date);

        playing = new TextView(this);
        playing.setTextColor(0xFF4DD0C8);
        playing.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        playing.setPadding(0, 28, 0, 0);
        playing.setGravity(Gravity.CENTER);
        box.addView(playing);

        TextView brand = new TextView(this);
        brand.setText("SG Alfa");
        brand.setTextColor(0x66FFFFFF);
        brand.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        brand.setPadding(0, 24, 0, 0);
        box.addView(brand);

        root.addView(box, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT));
        setContentView(root);
        h.post(tick);
    }

    /** Cada 20 s: actualiza lo que suena y mueve el bloque a otro sitio. */
    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            try {
                android.content.SharedPreferences p = getSharedPreferences("sgalfa_last_media", MODE_PRIVATE);
                String title = p.getString("title", null);
                String artist = p.getString("artist", null);
                boolean recent = System.currentTimeMillis() - p.getLong("at", 0) < 15 * 60_000L;
                playing.setText(title != null && recent ? "♪ " + title + (artist != null ? " · " + artist : "") : "");
                android.view.View parent = (android.view.View) box.getParent();
                if (parent != null && parent.getWidth() > 0) {
                    int maxX = Math.max(0, parent.getWidth() - box.getWidth());
                    int maxY = Math.max(0, parent.getHeight() - box.getHeight());
                    box.animate().x(rnd.nextInt(maxX + 1)).y(rnd.nextInt(maxY + 1)).setDuration(4000).start();
                }
            } catch (Exception ignored) {
            }
            h.postDelayed(this, 20_000);
        }
    };

    @Override
    public void onDetachedFromWindow() {
        h.removeCallbacksAndMessages(null);
        super.onDetachedFromWindow();
    }
}
