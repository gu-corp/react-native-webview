package com.brave.adblock;

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

    public Engine(String rules) {
        engine = engineCreate(rules);
    }

    @Override
    protected void finalize() {
        engineDestroy(engine);
    }

    public BlockerResult match(String url, String host, String tabHost, boolean thirdParty,
                               String resourceType) {
        return engineMatch(engine, url, host, tabHost, thirdParty, resourceType);
    }
}
