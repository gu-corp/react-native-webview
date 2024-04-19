package com.brave.adblock;

public class Engine {
    static {
        System.loadLibrary("adblock");
    }

    private long engine;

    private static native long engineCreate(String rules);
    private static native void engineDestroy(long engine);
    private static native BlockerResult engineMatch(long engine, String url, String sourceUrl, String resourceType);

    public Engine(String rules) {
        engine = engineCreate(rules);
    }

    @Override
    protected void finalize() {
        engineDestroy(engine);
    }

    public BlockerResult match(String url, String sourceUrl, String resourceType) {
        return engineMatch(engine, url, sourceUrl, resourceType);
    }
}
