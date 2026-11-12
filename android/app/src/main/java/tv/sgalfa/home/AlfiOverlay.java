/*
 * SG Alfa Home — Alfi flotante: aparece un momento en una esquina, encima de la app que
 * estés viendo, cada vez que una automatización actúa («factor sorpresa»).
 * Usa la capa de accesibilidad (no necesita permisos extra). Personaje original de SG Alfa.
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.LinearLayout;
import android.widget.TextView;

public final class AlfiOverlay {

    private static final String[] SPRITE = {
            "......kkkk......",
            ".....kyyyyk.....",
            "....kyyyyyyk....",
            "...kkrrrrrrkk...",
            "..krrrrrrrrrrk..",
            ".krwrrrrrrrrrrk.",
            ".krrrrrrrrrrrrk.",
            ".krkkkkkkkkkkrk.",
            ".krkcccccccckrk.",
            ".krkcekcckeckrk.",
            ".krkcccccccckrk.",
            ".krrkcckkcckrrk.",
            "..krrkkkkkkrrk..",
            "...kddrrrrddk...",
            "....kkk..kkk....",
            "....kbbk.kbbk...",
    };

    private static int color(char c) {
        switch (c) {
            case 'k': return 0xFF000000;
            case 'y': return 0xFFFFEC27;
            case 'r': return 0xFFFF004D;
            case 'd': return 0xFF7E2553;
            case 'w': case 'e': return 0xFFFFF1E8;
            case 'c': return 0xFFFFCCAA;
            case 'b': return 0xFF29366F;
            default: return 0;
        }
    }

    /** Dibuja a Alfi píxel a píxel. */
    static final class SpriteView extends View {
        private final Paint p = new Paint();

        SpriteView(Context c) {
            super(c);
            p.setAntiAlias(false);
        }

        @Override
        protected void onDraw(Canvas canvas) {
            float px = getWidth() / 16f;
            for (int y = 0; y < SPRITE.length; y++) {
                for (int x = 0; x < SPRITE[y].length(); x++) {
                    int col = color(SPRITE[y].charAt(x));
                    if (col == 0) continue;
                    p.setColor(col);
                    canvas.drawRect(x * px, y * px, (x + 1) * px + 0.5f, (y + 1) * px + 0.5f, p);
                }
            }
        }
    }

    /** Barra de progreso pixelada (contorno negro, relleno verde 8-bit). */
    static final class ProgressBarView extends View {
        private final Paint p = new Paint();
        private float f = 0;

        ProgressBarView(Context c) {
            super(c);
            p.setAntiAlias(false);
        }

        void set(float fraction) {
            f = Math.max(0, Math.min(1, fraction));
            invalidate();
        }

        @Override
        protected void onDraw(Canvas c) {
            float w = getWidth(), h = getHeight(), b = Math.max(2, h / 5);
            p.setColor(Color.BLACK);
            c.drawRect(0, 0, w, h, p);
            p.setColor(0xFF1D2B53);
            c.drawRect(b, b, w - b, h - b, p);
            p.setColor(0xFF00E436);
            // Relleno a «bloques», como en los juegos de 8 bits.
            float inner = w - 2 * b, block = h;
            int blocks = (int) (inner * f / block);
            for (int i = 0; i < blocks; i++) c.drawRect(b + i * block, b, b + (i + 1) * block - 2, h - b, p);
        }
    }

    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static View current;
    private static TextView currentText;
    private static ProgressBarView currentBar;
    private static Runnable hideLater;

    /** ¿Quiere el usuario que Alfi salga al actuar? (Ajustes → Protección). */
    static boolean enabled(Context c) {
        SharedPreferences p = c.getSharedPreferences("alfi", Context.MODE_PRIVATE);
        return p.getBoolean("toasts", true);
    }

    static void setEnabled(Context c, boolean on) {
        c.getSharedPreferences("alfi", Context.MODE_PRIVATE).edit().putBoolean("toasts", on).apply();
    }

    private static int dp(Context c, float v) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, c.getResources().getDisplayMetrics());
    }

    /** Muestra a Alfi con un mensaje. ms = 0 lo deja fijo hasta hide() (p. ej. durante la limpieza). */
    static void say(AccessibilityService svc, String text, long ms) {
        progress(svc, text, -1, ms);
    }

    /** Como say(), con barra de progreso (fraction 0..1; -1 = sin barra). */
    static void progress(AccessibilityService svc, String text, float fraction, long ms) {
        MAIN.post(() -> {
            try {
                if (current != null && currentText != null) {
                    currentText.setText(text);
                } else {
                    show(svc, text);
                }
                if (currentBar != null) {
                    currentBar.setVisibility(fraction >= 0 ? View.VISIBLE : View.GONE);
                    currentBar.set(fraction);
                }
                if (hideLater != null) MAIN.removeCallbacks(hideLater);
                if (ms > 0) {
                    hideLater = () -> hide(svc);
                    MAIN.postDelayed(hideLater, ms);
                }
            } catch (Exception ignored) {
            }
        });
    }

    private static void show(AccessibilityService svc, String text) {
        WindowManager wm = (WindowManager) svc.getSystemService(Context.WINDOW_SERVICE);
        LinearLayout row = new LinearLayout(svc);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.BOTTOM);

        SpriteView sprite = new SpriteView(svc);
        row.addView(sprite, new LinearLayout.LayoutParams(dp(svc, 56), dp(svc, 56)));

        LinearLayout box = new LinearLayout(svc);
        box.setOrientation(LinearLayout.VERTICAL);
        TextView bubble = new TextView(svc);
        bubble.setText(text);
        bubble.setTextColor(0xFF15120F);
        bubble.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        bubble.setTypeface(Typeface.DEFAULT_BOLD);
        bubble.setMinLines(2);
        bubble.setMaxLines(3);
        bubble.setEllipsize(android.text.TextUtils.TruncateAt.END);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0xFFFFF1D0);
        bg.setStroke(dp(svc, 3), Color.BLACK);
        bg.setCornerRadius(dp(svc, 4));
        box.setBackground(bg);
        box.setPadding(dp(svc, 12), dp(svc, 8), dp(svc, 12), dp(svc, 9));
        box.addView(bubble, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));
        ProgressBarView bar = new ProgressBarView(svc);
        bar.setVisibility(View.GONE);
        LinearLayout.LayoutParams barLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(svc, 12));
        barLp.topMargin = dp(svc, 6);
        box.addView(bar, barLp);
        LinearLayout.LayoutParams bl = new LinearLayout.LayoutParams(dp(svc, 340), LinearLayout.LayoutParams.WRAP_CONTENT);
        bl.setMargins(dp(svc, 6), 0, 0, dp(svc, 22));
        row.addView(box, bl);

        WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.BOTTOM | Gravity.END;
        lp.x = dp(svc, 28);
        lp.y = dp(svc, 28);
        wm.addView(row, lp);
        row.setTranslationY(dp(svc, 120));
        row.animate().translationY(0).setDuration(260).start();
        current = row;
        currentText = bubble;
        currentBar = bar;
    }

    static void hide(AccessibilityService svc) {
        MAIN.post(() -> {
            View v = current;
            current = null;
            currentText = null;
            currentBar = null;
            if (v == null) return;
            v.animate().translationY(v.getHeight() + 200).setDuration(220).withEndAction(() -> {
                try {
                    ((WindowManager) svc.getSystemService(Context.WINDOW_SERVICE)).removeView(v);
                } catch (Exception ignored) {
                }
            }).start();
        });
    }
}
