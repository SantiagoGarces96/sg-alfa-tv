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

    /** Dibuja a Alfi, el espartano (casco corintio con visera en T, cresta, capa, escudo y lanza), igual que en la app. */
    static final class SpriteView extends View {
        private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final android.graphics.Path path = new android.graphics.Path();

        SpriteView(Context c) {
            super(c);
        }

        private void outlined(Canvas c, android.graphics.Path path, int color) {
            p.setStyle(Paint.Style.FILL);
            p.setColor(color);
            c.drawPath(path, p);
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(2.2f);
            p.setStrokeJoin(Paint.Join.ROUND);
            p.setColor(0xFF24150C);
            c.drawPath(path, p);
            p.setStyle(Paint.Style.FILL);
        }

        @Override
        protected void onDraw(Canvas canvas) {
            canvas.save();
            canvas.scale(getWidth() / 100f, getHeight() / 100f);
            android.graphics.Path q = new android.graphics.Path();
            // Lanza.
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeCap(Paint.Cap.ROUND);
            p.setStrokeWidth(4.2f);
            p.setColor(0xFF24150C);
            canvas.drawLine(86, 100, 93, 44, p);
            p.setStrokeWidth(2);
            p.setColor(0xFF8A5A2B);
            canvas.drawLine(86, 100, 93, 44, p);
            q.reset();
            q.moveTo(93.6f, 30);
            q.quadTo(98, 40, 93.2f, 47);
            q.quadTo(88.6f, 40, 93.6f, 30);
            q.close();
            outlined(canvas, q, 0xFFC9973B);
            // Capa.
            q.reset();
            q.moveTo(22, 68);
            q.quadTo(8, 84, 4, 100);
            q.lineTo(98, 100);
            q.quadTo(92, 82, 80, 68);
            q.close();
            outlined(canvas, q, 0xFFCB2F27);
            // Torso.
            q.reset();
            q.moveTo(26, 70);
            q.quadTo(50, 60, 76, 70);
            q.lineTo(78, 100);
            q.lineTo(24, 100);
            q.close();
            outlined(canvas, q, 0xFFE2A272);
            // Cuello.
            q.reset();
            q.addRect(50, 56, 64, 68, android.graphics.Path.Direction.CW);
            outlined(canvas, q, 0xFFB06C42);
            // Hombreras.
            for (float[] c : new float[][]{{27, 70}, {76, 70}}) {
                q.reset();
                q.addCircle(c[0], c[1], 5.2f, android.graphics.Path.Direction.CW);
                outlined(canvas, q, 0xFFC9973B);
                p.setColor(0xFF7A5418);
                canvas.drawCircle(c[0], c[1], 2.2f, p);
            }
            // Cresta.
            q.reset();
            q.moveTo(33, 24);
            q.cubicTo(32, -10, 82, -12, 98, 32);
            q.cubicTo(92, 27, 84, 25, 77, 27);
            q.cubicTo(70, 13, 50, 9, 39, 25);
            q.close();
            outlined(canvas, q, 0xFFCB2F27);
            // Casco.
            q.reset();
            q.moveTo(34, 32);
            q.cubicTo(35, 15, 64, 11, 74, 25);
            q.cubicTo(81, 35, 81, 49, 75, 58);
            q.lineTo(63, 60);
            q.lineTo(57, 67);
            q.lineTo(44, 67);
            q.cubicTo(38, 61, 34, 53, 34, 45);
            q.close();
            outlined(canvas, q, 0xFFC9973B);
            // Visera en T.
            q.reset();
            q.moveTo(35, 37);
            q.lineTo(64, 34.5f);
            q.quadTo(65, 38, 63, 41);
            q.lineTo(51.5f, 42.5f);
            q.lineTo(52.5f, 67);
            q.lineTo(44.5f, 67);
            q.lineTo(44.5f, 43.5f);
            q.lineTo(36, 44);
            q.quadTo(34.5f, 40.5f, 35, 37);
            q.close();
            p.setColor(0xFF1A0F09);
            canvas.drawPath(q, p);
            // Protector nasal y mirada.
            q.reset();
            q.moveTo(46.5f, 31);
            q.lineTo(50.5f, 30.6f);
            q.lineTo(50, 49);
            q.lineTo(47, 49);
            q.close();
            outlined(canvas, q, 0xFFC9973B);
            p.setColor(0xFFFFE9B0);
            canvas.drawOval(38.5f, 39.1f, 43.5f, 41.5f, p);
            canvas.drawOval(55, 37.6f, 60, 40, p);
            // Escudo con la lambda.
            q.reset();
            q.moveTo(10, 70);
            q.cubicTo(20, 63, 38, 63, 47, 70);
            q.lineTo(45, 88);
            q.cubicTo(41, 96, 33, 100, 28, 101);
            q.cubicTo(21, 99, 13, 93, 11, 87);
            q.close();
            outlined(canvas, q, 0xFFD9AA4E);
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(3.4f);
            p.setStrokeJoin(Paint.Join.ROUND);
            p.setColor(0xFFCB2F27);
            q.reset();
            q.moveTo(21, 91);
            q.lineTo(28.5f, 73);
            q.lineTo(36, 91);
            canvas.drawPath(q, p);
            p.setStyle(Paint.Style.FILL);
            canvas.restore();
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
