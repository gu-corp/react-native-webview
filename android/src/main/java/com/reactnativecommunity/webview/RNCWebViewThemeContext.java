package com.reactnativecommunity.webview;

import android.content.ComponentCallbacks;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.res.Configuration;
import android.content.res.Resources;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Context a {@link RNCWebView} lives in, so its appearance can be changed on its own.
 *
 * <p>Chromium decides the `prefers-color-scheme` it reports from `android.R.attr.isLightTheme`
 * on the WebView's context, reads it while the WebView comes up, and refreshes it only when
 * that context reports a configuration change. Owning the context gives two things the shared
 * React Native one cannot: resources whose night-mode qualifier can be overridden without
 * disturbing the rest of the view tree, and a handle on the callback Chromium registers, so a
 * change made after the page has loaded still reaches it.
 */
public class RNCWebViewThemeContext extends ContextWrapper {
    private final List<ComponentCallbacks> componentCallbacks = new CopyOnWriteArrayList<>();
    private Context appearanceContext;
    private int nightMode = 0;

    public RNCWebViewThemeContext(Context base) {
        super(base);
    }

    @Override
    public Resources getResources() {
        return appearanceContext != null ? appearanceContext.getResources() : super.getResources();
    }

    @Override
    public Resources.Theme getTheme() {
        return appearanceContext != null ? appearanceContext.getTheme() : super.getTheme();
    }

    @Override
    public void registerComponentCallbacks(ComponentCallbacks callback) {
        componentCallbacks.add(callback);
        super.registerComponentCallbacks(callback);
    }

    @Override
    public void unregisterComponentCallbacks(ComponentCallbacks callback) {
        componentCallbacks.remove(callback);
        super.unregisterComponentCallbacks(callback);
    }

    /**
     * @param uiModeNight {@link Configuration#UI_MODE_NIGHT_YES},
     *                    {@link Configuration#UI_MODE_NIGHT_NO},
     *                    or 0 to follow the OS.
     */
    public void setNightMode(int uiModeNight) {
        if (uiModeNight == nightMode) {
            return;
        }
        nightMode = uiModeNight;
        if (nightMode == 0) {
            appearanceContext = null;
        } else {
            Configuration configuration = new Configuration(super.getResources().getConfiguration());
            configuration.uiMode =
                    (configuration.uiMode & ~Configuration.UI_MODE_NIGHT_MASK) | nightMode;
            appearanceContext = getBaseContext().createConfigurationContext(configuration);
        }
        // Nothing else observes this context, so this only wakes the WebView's own listener.
        // Chromium reads the appearance while the WebView starts up and caches it, so this
        // reaches WebViews created from here on rather than one already showing a page.
        Configuration current = getResources().getConfiguration();
        for (ComponentCallbacks callback : componentCallbacks) {
            callback.onConfigurationChanged(current);
        }
    }
}
