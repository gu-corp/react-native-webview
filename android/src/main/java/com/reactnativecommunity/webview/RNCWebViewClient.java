package com.reactnativecommunity.webview;

import static java.nio.charset.StandardCharsets.UTF_8;

import android.annotation.TargetApi;
import android.graphics.Bitmap;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Build;
import android.os.SystemClock;
import android.text.TextUtils;
import android.util.Log;
import android.webkit.HttpAuthHandler;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.SslErrorHandler;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.util.Pair;

import com.facebook.common.logging.FLog;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.UIManagerHelper;
import com.facebook.react.uimanager.UIManagerModule;
import com.facebook.react.uimanager.events.Event;
import com.facebook.react.uimanager.events.EventDispatcher;
import com.reactnativecommunity.webview.events.TopHttpErrorEvent;
import com.reactnativecommunity.webview.events.TopLoadingErrorEvent;
import com.reactnativecommunity.webview.events.TopLoadingFinishEvent;
import com.reactnativecommunity.webview.events.TopLoadingStartEvent;
import com.reactnativecommunity.webview.events.TopRenderProcessGoneEvent;
import com.reactnativecommunity.webview.events.TopShouldStartLoadWithRequestEvent;
import com.reactnativecommunity.webview.lunascape.HtmlExtractor;
import com.reactnativecommunity.webview.lunascape.InputStreamWithInjectedJS;
import com.reactnativecommunity.webview.lunascape.LunascapeUtils;
import com.reactnativecommunity.webview.lunascape.RNCWebViewCookieJar;
import com.brave.adblock.BlockerResult;
import com.brave.adblock.Engine;

import android.webkit.CookieManager;
import android.webkit.CookieSyncManager;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

import okhttp3.Headers;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

public class RNCWebViewClient extends WebViewClient {
    private static String TAG = "RNCWebViewClient";
    protected static final int SHOULD_OVERRIDE_URL_LOADING_TIMEOUT = 250;

    protected boolean mLastLoadFailed = false;
    protected RNCWebView.ProgressChangedFilter progressChangedFilter = null;
    protected @Nullable String ignoreErrFailedForThisURL = null;
    protected @Nullable RNCBasicAuthCredential basicAuthCredential = null;

    public RNCWebViewClient(ReactContext reactContext) {
        mReactContext = reactContext;
        httpClient = new okhttp3.OkHttpClient.Builder()
          .followRedirects(false)
          .followSslRedirects(false)
          .cookieJar(new RNCWebViewCookieJar())
          .build();
    }

    public void setIgnoreErrFailedForThisURL(@Nullable String url) {
        ignoreErrFailedForThisURL = url;
    }

    public void setBasicAuthCredential(@Nullable RNCBasicAuthCredential credential) {
        basicAuthCredential = credential;
    }

    @Override
    public void onPageFinished(WebView webView, String url) {
        super.onPageFinished(webView, url);
        String cookies = CookieManager.getInstance().getCookie(url);
        if (cookies != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                CookieManager.getInstance().flush();
            }else {
                CookieSyncManager.getInstance().sync();
            }
        }

        if (!mLastLoadFailed) {
            RNCWebView reactWebView = (RNCWebView) webView;
            String webviewUrl = webView.getUrl();
            boolean enableYoutubeAdblock = getEnableYoutubeVideoAdblocker(webviewUrl);
            reactWebView.callInjectedJavaScript(enableYoutubeAdblock);
            reactWebView.linkWindowObject();

            emitFinishEvent(webView, url);

            reactWebView.getFaviconUrl();

            String jsNightMode = "window.NightMode.setEnabled(" + mEnableNightMode + ");";
            reactWebView.loadUrl("javascript:" + jsNightMode);
        }
    }

    @Override
    public void doUpdateVisitedHistory(WebView view, String url, boolean isReload) {
        super.doUpdateVisitedHistory(view, url, isReload);
        if (url != null && !url.equals(currentPageUrl)) {
            currentPageUrl = url;
        }
        ((RNCWebView) view).dispatchEvent(
          view,
          new TopLoadingStartEvent(
            RNCWebViewWrapper.getReactTagFromWebView(view),
            createWebViewEvent(view, currentPageUrl)
          )
        );
    }

    @Override
    public void onPageStarted(WebView webView, String url, Bitmap favicon) {
      super.onPageStarted(webView, url, favicon);
      mLastLoadFailed = false;

      RNCWebView reactWebView = (RNCWebView) webView;
      reactWebView.callInjectedJavaScriptBeforeContentLoaded();
    }

    public boolean _shouldOverrideUrlLoading(WebView view, String url, boolean isMainFrame) {
        if (view instanceof RNCWebView) {
            RNCWebView rncWebView = (RNCWebView) view;
            rncWebView.activeUrl = url;
        }

        final RNCWebView rncWebView = (RNCWebView) view;
        final boolean isJsDebugging = rncWebView.getReactApplicationContext().getJavaScriptContextHolder().get() == 0;

        if (!isJsDebugging && rncWebView.mMessagingJSModule != null) {
            final Pair<Double, AtomicReference<RNCWebViewModuleImpl.ShouldOverrideUrlLoadingLock.ShouldOverrideCallbackState>> lock = RNCWebViewModuleImpl.shouldOverrideUrlLoadingLock.getNewLock();
            final double lockIdentifier = lock.first;
            final AtomicReference<RNCWebViewModuleImpl.ShouldOverrideUrlLoadingLock.ShouldOverrideCallbackState> lockObject = lock.second;

            final WritableMap event = createWebViewEvent(view, url);
            event.putDouble("lockIdentifier", lockIdentifier);
            rncWebView.dispatchDirectShouldStartLoadWithRequest(event);

            try {
                assert lockObject != null;
                synchronized (lockObject) {
                    final long startTime = SystemClock.elapsedRealtime();
                    while (lockObject.get() == RNCWebViewModuleImpl.ShouldOverrideUrlLoadingLock.ShouldOverrideCallbackState.UNDECIDED) {
                        if (SystemClock.elapsedRealtime() - startTime > SHOULD_OVERRIDE_URL_LOADING_TIMEOUT) {
                            FLog.w(TAG, "Did not receive response to shouldOverrideUrlLoading in time, defaulting to allow loading.");
                            RNCWebViewModuleImpl.shouldOverrideUrlLoadingLock.removeLock(lockIdentifier);
                            return false;
                        }
                        lockObject.wait(SHOULD_OVERRIDE_URL_LOADING_TIMEOUT);
                    }
                }
            } catch (InterruptedException e) {
                FLog.e(TAG, "shouldOverrideUrlLoading was interrupted while waiting for result.", e);
                RNCWebViewModuleImpl.shouldOverrideUrlLoadingLock.removeLock(lockIdentifier);
                return false;
            }
            WritableMap event2 = createWebViewEvent(view, url);
            event2.putBoolean("mainFrame", isMainFrame);
            rncWebView.dispatchEvent(
              view,
              new TopShouldStartLoadWithRequestEvent(RNCWebViewWrapper.getReactTagFromWebView(view), event2)
            );

            final boolean shouldOverride = lockObject.get() == RNCWebViewModuleImpl.ShouldOverrideUrlLoadingLock.ShouldOverrideCallbackState.SHOULD_OVERRIDE;
            RNCWebViewModuleImpl.shouldOverrideUrlLoadingLock.removeLock(lockIdentifier);

            return shouldOverride;
        } else {
            FLog.w(TAG, "Couldn't use blocking synchronous call for onShouldStartLoadWithRequest due to debugging or missing Catalyst instance, falling back to old event-and-load.");
            progressChangedFilter.setWaitingForCommandLoadUrl(true);

            int reactTag = RNCWebViewWrapper.getReactTagFromWebView(view);
            UIManagerHelper.getEventDispatcherForReactTag((ReactContext) view.getContext(), reactTag).dispatchEvent(new TopShouldStartLoadWithRequestEvent(
                    reactTag,
                    createWebViewEvent(view, url)));
            return true;
        }
    }

    @TargetApi(Build.VERSION_CODES.N)
    @Override
    public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
        final String url = request.getUrl().toString();
        return this._shouldOverrideUrlLoading(view, url, request.isForMainFrame());
    }

    /**
     * fix android injection
     * https://github.com/MetaMask/metamask-mobile/pull/2070
     * https://github.com/MetaMask/metamask-mobile/blob/047e3fec96dff293051ffa8170994739f70b154d/patches/react-native-webview%2B11.13.0.patch#L415
     * * */
    @Override
    public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
        try {
            Uri url = request.getUrl();
            String urlStr = url.toString();
            String scheme = url.getScheme();

            if (!scheme.equalsIgnoreCase("http") && !scheme.equalsIgnoreCase("https")) {
                return null;
            }

            if (request.isForMainFrame()) {
              mainUrl = url;
            }

            if (adblockEngines != null && !this.isMainDocumentException) {
                BlockerResult blockerResult;

                boolean matched = false;
                boolean exception = false;
                for (Engine engine : adblockEngines) {
                    synchronized (engine) {
                        if (request.isForMainFrame()) {
                            blockerResult = engine.match(url.toString(), url.getHost(),
                              "", false, "document");
                        } else {
                            blockerResult = engine.match(url.toString(), url.getHost(),
                              mainUrl.getHost(), false, "");
                        }

                        matched |= blockerResult.matched;
                        if (blockerResult.important) {
                            break;
                        }

                        if (blockerResult.exception) {
                            exception = true;
                            break;
                        }
                    }
                }

                if (request.isForMainFrame() && exception) {
                    this.isMainDocumentException = true;
                } else {
                    if (matched && !exception) {
                        return new WebResourceResponse(
                          "text/plain",
                          "utf-8",
                          new ByteArrayInputStream("".getBytes())
                        );
                    }
                }
            }

            RNCWebView reactWebView = (RNCWebView) view;
            if(reactWebView.injectedJSBeforeContentLoaded == null
              || reactWebView.injectedJSBeforeContentLoaded.isEmpty()) {
                return null;
            }

            if (!request.isForMainFrame()) {
                return null;
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                if (request.isRedirect()) {
                  return null;
                }
            }

            if (!TextUtils.equals(request.getMethod(), "GET")) {
                return null;
            }

            Map<String, String> requestHeaders = request.getRequestHeaders();
            Request req = new Request.Builder()
              .headers(Headers.of(requestHeaders))
              .url(urlStr)
              .build();

            Response response = httpClient.newCall(req).execute();

            if (!LunascapeUtils.Companion.responseRequiresJSInjection(response)) {
                return null;
            }

            ResponseBody body = response.body();
            MediaType type = body != null ? body.contentType() : null;
            // find encoding in response headers. https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type
            Charset httpResponseCharset = type != null ? type.charset() : null;

            Charset defaultCharset = type != null ? type.charset(UTF_8) : UTF_8;
            InputStream is = body != null ? body.byteStream() : null;

            String encoding = defaultCharset.name();

            if (httpResponseCharset == null) {
                // if the response is HTML file and if the charset is not already set in the response => try to find it in the HTML headers (meta tag - charset)
                String charsetHtml = HtmlExtractor.Companion.findHtmlCharsetFromRequest(httpClient, req);
                if (charsetHtml != null && !encoding.equalsIgnoreCase(charsetHtml)) {
                  encoding = charsetHtml;
                }

                // TODO: if httpResponseCharset is null and charsetHtml is null, I can't find a way to detect the encoding value so I will use UTF_8 as a default value
            }

            if (response.code() == HttpURLConnection.HTTP_OK && is != null) {
              is = new InputStreamWithInjectedJS(is, reactWebView.injectedJSBeforeContentLoaded, defaultCharset);
            }

            return new WebResourceResponse("text/html", encoding, is);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    @Override
    public void onReceivedHttpAuthRequest(WebView view, HttpAuthHandler handler, String host, String realm) {
        if (basicAuthCredential != null) {
            handler.proceed(basicAuthCredential.username, basicAuthCredential.password);
            return;
        }
        super.onReceivedHttpAuthRequest(view, handler, host, realm);
    }

    @Override
    public void onReceivedSslError(final WebView webView, final SslErrorHandler handler, final SslError error) {
        // onReceivedSslError is called for most requests, per Android docs: https://developer.android.com/reference/android/webkit/WebViewClient#onReceivedSslError(android.webkit.WebView,%2520android.webkit.SslErrorHandler,%2520android.net.http.SslError)
        // WebView.getUrl() will return the top-level window URL.
        // If a top-level navigation triggers this error handler, the top-level URL will be the failing URL (not the URL of the currently-rendered page).
        // This is desired behavior. We later use these values to determine whether the request is a top-level navigation or a subresource request.
        String topWindowUrl = webView.getUrl();
        String failingUrl = error.getUrl();

        // Cancel request after obtaining top-level URL.
        // If request is cancelled before obtaining top-level URL, undesired behavior may occur.
        // Undesired behavior: Return value of WebView.getUrl() may be the current URL instead of the failing URL.
        handler.cancel();

        if (!topWindowUrl.equalsIgnoreCase(failingUrl)) {
            // If error is not due to top-level navigation, then do not call onReceivedError()
            Log.w(TAG, "Resource blocked from loading due to SSL error. Blocked URL: "+failingUrl);
            return;
        }

        int code = error.getPrimaryError();
        String description = "";
        String descriptionPrefix = "SSL error: ";

        // https://developer.android.com/reference/android/net/http/SslError.html
        switch (code) {
            case SslError.SSL_DATE_INVALID:
                description = "The date of the certificate is invalid";
                break;
            case SslError.SSL_EXPIRED:
                description = "The certificate has expired";
                break;
            case SslError.SSL_IDMISMATCH:
                description = "Hostname mismatch";
                break;
            case SslError.SSL_INVALID:
                description = "A generic error occurred";
                break;
            case SslError.SSL_NOTYETVALID:
                description = "The certificate is not yet valid";
                break;
            case SslError.SSL_UNTRUSTED:
                description = "The certificate authority is not trusted";
                break;
            default:
                description = "Unknown SSL Error";
                break;
        }

        description = descriptionPrefix + description;

        this.onReceivedError(
                webView,
                code,
                description,
                failingUrl
        );
    }

    @Override
    public void onReceivedError(
            WebView webView,
            int errorCode,
            String description,
            String failingUrl) {

        if (ignoreErrFailedForThisURL != null
                && failingUrl.equals(ignoreErrFailedForThisURL)
                && errorCode == -1
                && description.equals("net::ERR_FAILED")) {

            // This is a workaround for a bug in the WebView.
            // See these chromium issues for more context:
            // https://bugs.chromium.org/p/chromium/issues/detail?id=1023678
            // https://bugs.chromium.org/p/chromium/issues/detail?id=1050635
            // This entire commit should be reverted once this bug is resolved in chromium.
            setIgnoreErrFailedForThisURL(null);
            return;
        }

        super.onReceivedError(webView, errorCode, description, failingUrl);
        mLastLoadFailed = true;

        // In case of an error JS side expect to get a finish event first, and then get an error event
        // Android WebView does it in the opposite way, so we need to simulate that behavior
        emitFinishEvent(webView, failingUrl);

        WritableMap eventData = createWebViewEvent(webView, failingUrl);
        eventData.putDouble("code", errorCode);
        eventData.putString("description", description);

        int reactTag = RNCWebViewWrapper.getReactTagFromWebView(webView);
        UIManagerHelper.getEventDispatcherForReactTag((ReactContext) webView.getContext(), reactTag).dispatchEvent(new TopLoadingErrorEvent(reactTag, eventData));
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    public void onReceivedHttpError(
            WebView webView,
            WebResourceRequest request,
            WebResourceResponse errorResponse) {
        super.onReceivedHttpError(webView, request, errorResponse);

        if (request.isForMainFrame()) {
            WritableMap eventData = createWebViewEvent(webView, request.getUrl().toString());
            eventData.putInt("statusCode", errorResponse.getStatusCode());
            eventData.putString("description", errorResponse.getReasonPhrase());

            int reactTag = RNCWebViewWrapper.getReactTagFromWebView(webView);
            UIManagerHelper.getEventDispatcherForReactTag((ReactContext) webView.getContext(), reactTag).dispatchEvent(new TopHttpErrorEvent(reactTag, eventData));
        }
    }

    @TargetApi(Build.VERSION_CODES.O)
    @Override
    public boolean onRenderProcessGone(WebView webView, RenderProcessGoneDetail detail) {
        // WebViewClient.onRenderProcessGone was added in O.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false;
        }
        super.onRenderProcessGone(webView, detail);

        if(detail.didCrash()){
            Log.e(TAG, "The WebView rendering process crashed.");
        }
        else{
            Log.w(TAG, "The WebView rendering process was killed by the system.");
        }

        // if webView is null, we cannot return any event
        // since the view is already dead/disposed
        // still prevent the app crash by returning true.
        if(webView == null){
            return true;
        }

        WritableMap event = createWebViewEvent(webView, webView.getUrl());
        event.putBoolean("didCrash", detail.didCrash());
        int reactTag = RNCWebViewWrapper.getReactTagFromWebView(webView);
        UIManagerHelper.getEventDispatcherForReactTag((ReactContext) webView.getContext(), reactTag).dispatchEvent(new TopRenderProcessGoneEvent(reactTag, event));

        // returning false would crash the app.
        return true;
    }

    protected void emitFinishEvent(WebView webView, String url) {
        int reactTag = RNCWebViewWrapper.getReactTagFromWebView(webView);
        UIManagerHelper.getEventDispatcherForReactTag((ReactContext) webView.getContext(), reactTag).dispatchEvent(new TopLoadingFinishEvent(reactTag, createWebViewEvent(webView, url)));
    }

    protected WritableMap createWebViewEvent(WebView webView, String url) {
        WritableMap event = Arguments.createMap();
        event.putDouble("target", RNCWebViewWrapper.getReactTagFromWebView(webView));
        // Don't use webView.getUrl() here, the URL isn't updated to the new value yet in callbacks
        // like onPageFinished
        event.putString("url", url);
        event.putBoolean("loading", !mLastLoadFailed && webView.getProgress() != 100);
        event.putString("title", webView.getTitle());
        event.putBoolean("canGoBack", webView.canGoBack());
        event.putBoolean("canGoForward", webView.canGoForward());
        return event;
    }

    public void setProgressChangedFilter(RNCWebView.ProgressChangedFilter filter) {
        progressChangedFilter = filter;
    }

    /**
     * Lunascape logic
     * */
    protected ReactContext mReactContext;
    protected Uri mainUrl;
    protected int mLoadingProgress = 0;
    protected boolean mEnableNightMode = false;

    private final OkHttpClient httpClient;
    private ArrayList<Engine> adblockEngines;
    private boolean isMainDocumentException;
    private String currentPageUrl = null;
    private String currentPageTitle = null;

    protected void cloneSettings(RNCWebViewClient parentClient) {
        cloneAdblockRules(parentClient);
        mLastLoadFailed = parentClient.mLastLoadFailed;
        mainUrl = parentClient.mainUrl;
    }

    /**
     * Adblock
     * */
    protected ArrayList<Engine> getAdblockRules() {
        return adblockEngines;
    }

    protected void cloneAdblockRules(RNCWebViewClient parentClient) {
        if (parentClient.getAdblockRules() != null) {
            try {
                adblockEngines = (ArrayList<Engine>)parentClient.getAdblockRules().clone();
            } catch (InternalError error) {
                error.printStackTrace();
            }
        }
    }

    public void setAdblockRuleList(ReadableArray rules) {
        RNCWebViewModule rncWebViewModule = RNCWebViewModule.getRNCWebViewModule(mReactContext);
        if (rules != null) {
            adblockEngines = new ArrayList<Engine>();
            for (int i = 0; i < rules.size(); i++) {
                adblockEngines.add(
                    rncWebViewModule.getAdblockEngine(rules.getString(i))
                );
            }
        } else {
            adblockEngines = null;
        }
    }

    public boolean getEnableYoutubeVideoAdblocker(String urlString) {
        boolean enable = false;
        try {
            if(adblockEngines != null && checkYoutubeDomain(urlString)) {
                BlockerResult blockerResult;
                URL url = new URL(urlString);
                for (Engine engine : adblockEngines) {
                    synchronized (engine) {
                        blockerResult = engine.match(url.toString(), url.getHost(), "", false, "");
                        if (blockerResult.exception) {
                            enable = false;
                            break;
                        }
                    }
                }
                enable = true;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return enable;
    }

    public boolean checkYoutubeDomain(String urlString) {
        boolean result = false;
        try {
            URL url = new URL(urlString);
            String host = url.getHost();
            result = "m.youtube.com".equals(host) || "www.youtube.com".equals(host) || "music.youtube.com".equals(host);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return result;
    }

    public void setLoadingProgress(int newProgress) {
        this.mLoadingProgress = newProgress;
    }

    @Override
    public void onLoadResource(WebView view, String url) {
        super.onLoadResource(view, url);
        String newRequestURL = view.getUrl();
        String newRequestTitle = view.getTitle();
        if (newRequestURL != null && (!newRequestURL.equals((currentPageUrl)) || !newRequestTitle.equals((currentPageTitle)))) {
            currentPageUrl = newRequestURL;
            currentPageTitle = newRequestTitle;
            ((RNCWebView) view).dispatchEvent(
              view,
              new TopLoadingStartEvent(RNCWebViewWrapper.getReactTagFromWebView(view), createWebViewEvent(view, currentPageUrl))
            );
        }
    }

}
