package com.reactnativecommunity.webview.lunascape;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;

import com.brave.adblock.Engine;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

/**
 * Creates adblock engines (#5580).
 *
 * Every engine gets the redirect and scriptlet resources ({@code $redirect}, {@code +js(...)})
 * from the asset {@link #RESOURCES_ASSET}.
 */
public final class AdblockEngineLoader {
    private static final String TAG = "AdblockEngineLoader";

    /** Brave adblock-resources format (Resource objects with base64 content). */
    public static final String RESOURCES_ASSET = "adblock-resources.json";

    private static final Object resourcesLock = new Object();
    private static @Nullable String resources;

    private AdblockEngineLoader() {}

    /** An engine for the filter list in the asset {@code assetPath}. */
    public static Engine fromAsset(Context context, String assetPath) throws IOException {
        return fromRules(context, readAsset(context, assetPath));
    }

    /** An engine for {@code rules}. */
    public static Engine fromRules(Context context, String rules) {
        Engine engine = new Engine(rules);
        String json = resources(context);
        if (json != null && !engine.useResources(json)) {
            Log.w(TAG, RESOURCES_ASSET + " is not valid");
        }
        return engine;
    }

    private static @Nullable String resources(Context context) {
        synchronized (resourcesLock) {
            if (resources == null) {
                try {
                    resources = readAsset(context, RESOURCES_ASSET);
                } catch (IOException e) {
                    Log.w(TAG, "No " + RESOURCES_ASSET + ": $redirect and +js() rules are not used", e);
                    resources = "";
                }
            }
            return resources.isEmpty() ? null : resources;
        }
    }

    private static String readAsset(Context context, String assetPath) throws IOException {
        try (InputStream in = context.getAssets().open(assetPath)) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buffer = new byte[64 * 1024];
            int n;
            while ((n = in.read(buffer)) != -1) {
                out.write(buffer, 0, n);
            }
            return new String(out.toByteArray(), StandardCharsets.UTF_8);
        }
    }
}
