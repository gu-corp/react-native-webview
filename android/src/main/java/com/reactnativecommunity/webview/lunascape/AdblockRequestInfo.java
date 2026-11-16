package com.reactnativecommunity.webview.lunascape;

import android.net.Uri;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;

import androidx.annotation.Nullable;

import java.io.ByteArrayInputStream;
import java.util.Locale;
import java.util.Map;

import okhttp3.HttpUrl;

/**
 * What the adblock engine needs to know about a request besides its URL (Lunascape #5578).
 *
 * Until now every request was matched as first-party with an empty resource type, so filter
 * options such as {@code $third-party}, {@code $script}, {@code $image} or {@code $xhr} never
 * matched: a large part of EasyList / uBlock filters (including the Ad-Shield rules) did nothing
 * on Android. WebView does not tell us the request destination, so the type is guessed from the
 * Accept header and the file extension, the same way Brave's Android WebView builds did.
 */
public final class AdblockRequestInfo {
    private AdblockRequestInfo() {}

    /** True when the request goes to another site (registrable domain) than the page. */
    public static boolean isThirdParty(Uri url, @Nullable Uri pageUrl) {
        if (pageUrl == null) {
            return false;
        }
        String a = registrableDomain(url);
        String b = registrableDomain(pageUrl);
        if (a == null || b == null) {
            return false;
        }
        return !a.equalsIgnoreCase(b);
    }

    @Nullable
    static String registrableDomain(Uri uri) {
        String host = uri.getHost();
        if (host == null || host.isEmpty()) {
            return null;
        }
        try {
            HttpUrl parsed = HttpUrl.parse(uri.toString());
            String top = parsed != null ? parsed.topPrivateDomain() : null;
            if (top != null) {
                return top;
            }
        } catch (RuntimeException e) {
            // Fall through to the host itself (IP addresses, unknown suffixes).
        }
        return host;
    }

    /** adblock-rust request type names: document, sub_frame, script, stylesheet, image, font, media, xhr, other. */
    public static String resourceType(WebResourceRequest request) {
        if (request.isForMainFrame()) {
            return "document";
        }
        String accept = header(request.getRequestHeaders(), "Accept");
        if (accept != null) {
            String a = accept.toLowerCase(Locale.ROOT);
            if (a.startsWith("text/html")) {
                return "sub_frame";
            }
            if (a.startsWith("text/css")) {
                return "stylesheet";
            }
            if (a.startsWith("image/")) {
                return "image";
            }
            if (a.startsWith("video/") || a.startsWith("audio/")) {
                return "media";
            }
        }
        String path = request.getUrl().getPath();
        String ext = "";
        if (path != null) {
            int dot = path.lastIndexOf('.');
            int slash = path.lastIndexOf('/');
            if (dot > slash) {
                ext = path.substring(dot + 1).toLowerCase(Locale.ROOT);
            }
        }
        switch (ext) {
            case "js":
            case "mjs":
                return "script";
            case "css":
                return "stylesheet";
            case "gif":
            case "png":
            case "jpg":
            case "jpeg":
            case "webp":
            case "svg":
            case "ico":
            case "avif":
                return "image";
            case "woff":
            case "woff2":
            case "ttf":
            case "otf":
                return "font";
            case "mp4":
            case "webm":
            case "m3u8":
            case "mp3":
                return "media";
            case "html":
            case "htm":
                return "sub_frame";
            default:
                break;
        }
        // fetch()/XMLHttpRequest send "*/*" (or a JSON type) and no extension.
        if (accept == null || accept.startsWith("*/*") || accept.contains("json")) {
            return "xhr";
        }
        return "other";
    }

    // A 1x1 transparent GIF. A blocked image must still load: anti-adblock scripts (Ad-Shield's
    // ad-delivery.net/px.gif and similar "bait" images) treat an image error as proof of an
    // ad blocker and start re-inserting ads.
    private static final byte[] TRANSPARENT_GIF = {
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, (byte) 0x80, 0x00, 0x00,
        0x00, 0x00, 0x00, (byte) 0xff, (byte) 0xff, (byte) 0xff, 0x21, (byte) 0xf9, 0x04, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
        0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
    };

    /** The empty answer for a blocked request, shaped like what the page asked for. */
    public static WebResourceResponse blockedResponse(String resourceType) {
        if ("image".equals(resourceType)) {
            return new WebResourceResponse("image/gif", null, new ByteArrayInputStream(TRANSPARENT_GIF));
        }
        if ("script".equals(resourceType)) {
            return new WebResourceResponse("application/javascript", "utf-8", new ByteArrayInputStream(new byte[0]));
        }
        if ("stylesheet".equals(resourceType)) {
            return new WebResourceResponse("text/css", "utf-8", new ByteArrayInputStream(new byte[0]));
        }
        return new WebResourceResponse("text/plain", "utf-8", new ByteArrayInputStream(new byte[0]));
    }

    @Nullable
    private static String header(@Nullable Map<String, String> headers, String name) {
        if (headers == null) {
            return null;
        }
        for (Map.Entry<String, String> e : headers.entrySet()) {
            if (e.getKey() != null && e.getKey().equalsIgnoreCase(name)) {
                return e.getValue();
            }
        }
        return null;
    }
}
