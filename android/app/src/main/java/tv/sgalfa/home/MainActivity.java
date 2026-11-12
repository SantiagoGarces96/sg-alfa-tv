/*
 * SG Alfa Home — actividad principal (pantalla de inicio).
 * Copyright (c) 2026 SG Alfa.
 */
package tv.sgalfa.home;

import android.content.Intent;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterActivity {

    private LauncherChannel launcher;
    private ProtectionChannel protection;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        launcher = new LauncherChannel(this);
        launcher.register(engine.getDartExecutor().getBinaryMessenger());
        protection = new ProtectionChannel(this);
        protection.register(engine.getDartExecutor().getBinaryMessenger());
    }

    @Override
    protected void onResume() {
        super.onResume();
        try {
            ProtectionChannel.resumeIfWanted(this);
        } catch (Exception ignored) {
        }
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        // Pulsar Inicio estando ya en el inicio: volver arriba del todo.
        if (Intent.ACTION_MAIN.equals(intent.getAction()) && intent.hasCategory(Intent.CATEGORY_HOME)
                && launcher != null) {
            launcher.homePressed();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (protection != null && protection.onActivityResult(requestCode, resultCode)) return;
        super.onActivityResult(requestCode, resultCode, data);
    }
}
