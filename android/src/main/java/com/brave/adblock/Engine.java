package com.brave.adblock;

import androidx.annotation.Nullable;

/**
 * adblock-rust engine (libadblock.so, built from gu-corp/adblock-rust-jni).
 *
 * Matching and the cosmetic lookups only read the engine and may run on several threads at
 * once. {@link #useResources} changes it; the native side holds a read/write lock, so it waits
 * for the lookups in progress.
 */
public class Engine {
    static {
        System.loadLibrary("adblock");
    }

    private final long engine;

    private static native long engineCreate(String rules);
    private static native void engineDestroy(long engine);
    private static native BlockerResult engineMatch(long engine, String url, String host,
                                                    String tabHost, boolean thirdParty,
                                                    String resourceType);
    private static native boolean engineUseResources(long engine, String resources);
    private static native String engineUrlCosmeticResources(long engine, String url);
    private static native String engineHiddenClassIdSelectors(long engine, String[] classes,
                                                              String[] ids, String[] exceptions);

    /** Parses {@code rules} (ABP / uBlock Origin syntax). Bad rules are skipped. */
    public Engine(String rules) {
        engine = engineCreate(rules);
    }

    @Override
    protected void finalize() {
        engineDestroy(engine);
    }

    /**
     * Checks a network request. {@code matched} in the result means the request should be
     * blocked. Never returns null; if the arguments cannot be read, nothing matches.
     */
    public BlockerResult match(String url, String host, String tabHost, boolean thirdParty,
                               String resourceType) {
        BlockerResult result = engineMatch(engine, url, host, tabHost, thirdParty, resourceType);
        return result != null ? result : new BlockerResult();
    }

    /**
     * Loads redirect and scriptlet resources ({@code $redirect}, {@code +js(...)}) from a JSON
     * array in the format of Brave's adblock-resources. Returns false if the JSON is invalid.
     */
    public boolean useResources(String resourcesJson) {
        return engineUseResources(engine, resourcesJson);
    }

    /**
     * Returns the cosmetic resources for a page as JSON: {@code hide_selectors},
     * {@code procedural_actions}, {@code exceptions}, {@code injected_script} and
     * {@code generichide}. Null on failure.
     */
    @Nullable
    public String urlCosmeticResources(String url) {
        return engineUrlCosmeticResources(engine, url);
    }

    /**
     * Returns, as a JSON array, the generic hide selectors for the given classes and ids
     * (without the leading "." or "#"), leaving out {@code exceptions} from
     * {@link #urlCosmeticResources}. Null on failure.
     */
    @Nullable
    public String hiddenClassIdSelectors(String[] classes, String[] ids, String[] exceptions) {
        return engineHiddenClassIdSelectors(engine, classes, ids, exceptions);
    }
}
