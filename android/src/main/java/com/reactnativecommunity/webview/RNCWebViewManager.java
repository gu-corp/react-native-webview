package com.reactnativecommunity.webview;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.app.AlertDialog;
import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.Manifest;
import android.graphics.Picture;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import androidx.annotation.RequiresApi;
import androidx.core.content.ContextCompat;
import android.text.TextUtils;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewGroup.LayoutParams;
import android.view.WindowManager;
import android.webkit.ConsoleMessage;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.GeolocationPermissions;
import android.webkit.HttpAuthHandler;
import android.webkit.JavascriptInterface;
import android.webkit.PermissionRequest;
import android.webkit.URLUtil;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;

import com.facebook.react.views.scroll.ScrollEvent;
import com.facebook.react.views.scroll.ScrollEventType;
import com.facebook.react.views.scroll.OnScrollDispatchHelper;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableMapKeySetIterator;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.common.MapBuilder;
import com.facebook.react.common.build.ReactBuildConfig;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.UIManagerModule;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.uimanager.events.ContentSizeChangeEvent;
import com.facebook.react.uimanager.events.Event;
import com.facebook.react.uimanager.events.EventDispatcher;
import com.reactnativecommunity.webview.events.TopLoadingErrorEvent;
import com.reactnativecommunity.webview.events.TopHttpErrorEvent;
import com.reactnativecommunity.webview.events.TopLoadingFinishEvent;
import com.reactnativecommunity.webview.events.TopLoadingProgressEvent;
import com.reactnativecommunity.webview.events.TopLoadingStartEvent;
import com.reactnativecommunity.webview.events.TopMessageEvent;
import com.reactnativecommunity.webview.events.TopShouldStartLoadWithRequestEvent;
import com.reactnativecommunity.webview.events.TopCreateNewWindowEvent;
import com.reactnativecommunity.webview.events.TopCaptureScreenEvent;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

import javax.annotation.Nullable;

import okhttp3.Headers;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

import static okhttp3.internal.Util.UTF_8;
import android.os.Handler;
import android.webkit.WebView.HitTestResult;
import android.os.Message;
import android.widget.TextView;

import com.brave.adblock.BlockerResult;
import com.brave.adblock.Engine;
import com.reactnativecommunity.webview.events.TopWebViewClosedEvent;

/**
 * Manages instances of {@link WebView}
 * <p>
 * Can accept following commands:
 * - GO_BACK
 * - GO_FORWARD
 * - RELOAD
 * - LOAD_URL
 * <p>
 * {@link WebView} instances could emit following direct events:
 * - topLoadingFinish
 * - topLoadingStart
 * - topLoadingStart
 * - topLoadingProgress
 * - topShouldStartLoadWithRequest
 * <p>
 * Each event will carry the following properties:
 * - target - view's react tag
 * - url - url set for the webview
 * - loading - whether webview is in a loading state
 * - title - title of the current page
 * - canGoBack - boolean, whether there is anything on a history stack to go back
 * - canGoForward - boolean, whether it is possible to request GO_FORWARD command
 */
@ReactModule(name = RNCWebViewManager.REACT_CLASS)
public class RNCWebViewManager extends SimpleViewManager<WebView> {

  public static String activeUrl = null;
  public static final int COMMAND_GO_BACK = 1;
  public static final int COMMAND_GO_FORWARD = 2;
  public static final int COMMAND_RELOAD = 3;
  public static final int COMMAND_STOP_LOADING = 4;
  public static final int COMMAND_POST_MESSAGE = 5;
  public static final int COMMAND_INJECT_JAVASCRIPT = 6;
  public static final int COMMAND_LOAD_URL = 7;
  public static final int COMMAND_FOCUS = 8;
  public static final int COMMAND_CAPTURE_SCREEN = 9;
  public static final int COMMAND_SEARCH_IN_PAGE = 10;
  public static final String DOWNLOAD_DIRECTORY = Environment.getExternalStorageDirectory() + "/Android/data/jp.co.lunascape.android.ilunascape/downloads/";
  public static final String TEMP_DIRECTORY = Environment.getExternalStorageDirectory() + "/Android/data/jp.co.lunascape.android.ilunascape/temps/";

  protected static final String REACT_CLASS = "RNCWebView";
  protected static final String HTML_ENCODING = "UTF-8";
  protected static final String HTML_MIME_TYPE = "text/html";
  protected static final String JAVASCRIPT_INTERFACE = "ReactNativeWebView";
  protected static final String HTTP_METHOD_POST = "POST";
  // Use `webView.loadUrl("about:blank")` to reliably reset the view
  // state and release page resources (including any running JavaScript).
  protected static final String BLANK_URL = "about:blank";
  protected WebViewConfig mWebViewConfig;

  protected RNCWebChromeClient mWebChromeClient = null;
  protected boolean mAllowsFullscreenVideo = false;
  protected @Nullable String mUserAgent = null;
  protected @Nullable String mUserAgentWithApplicationName = null;

  public RNCWebViewManager() {
    mWebViewConfig = new WebViewConfig() {
      public void configWebView(WebView webView) {
      }
    };
  }

  public RNCWebViewManager(WebViewConfig webViewConfig) {
    mWebViewConfig = webViewConfig;
  }

  protected static void dispatchEvent(WebView webView, Event event) {
    ReactContext reactContext = (ReactContext) webView.getContext();
    EventDispatcher eventDispatcher =
      reactContext.getNativeModule(UIManagerModule.class).getEventDispatcher();
    eventDispatcher.dispatchEvent(event);
  }

  @Override
  public String getName() {
    return REACT_CLASS;
  }

  protected RNCWebView createRNCWebViewInstance(ThemedReactContext reactContext) {
    return RNCWebView.createNewInstance(reactContext);
  }

  @Override
  @TargetApi(Build.VERSION_CODES.LOLLIPOP)
  protected WebView createViewInstance(ThemedReactContext reactContext) {
    RNCWebView webView = createRNCWebViewInstance(reactContext);
    setupWebChromeClient(reactContext, webView);
    reactContext.addLifecycleEventListener(webView);
    mWebViewConfig.configWebView(webView);
    WebSettings settings = webView.getSettings();
    settings.setBuiltInZoomControls(true);
    settings.setDisplayZoomControls(false);
    settings.setDomStorageEnabled(true);
    settings.setSupportMultipleWindows(true);

    settings.setAllowFileAccess(true);
    settings.setAllowContentAccess(false);
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
      settings.setAllowFileAccessFromFileURLs(false);
      setAllowUniversalAccessFromFileURLs(webView, false);
    }
    setMixedContentMode(webView, "never");

    // Fixes broken full-screen modals/galleries due to body height being 0.
    webView.setLayoutParams(
      new LayoutParams(LayoutParams.MATCH_PARENT,
        LayoutParams.MATCH_PARENT));

    if (ReactBuildConfig.DEBUG && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
      WebView.setWebContentsDebuggingEnabled(true);
    }

    webView.setOnLongClickListener(new View.OnLongClickListener() {
      @Override
      public boolean onLongClick(View view) {
        final RNCWebView webView = (RNCWebView) view;
        HitTestResult result = webView.getHitTestResult();
        final String extra = result.getExtra();
        final int type = result.getType();
        if (type == HitTestResult.SRC_IMAGE_ANCHOR_TYPE || type == HitTestResult.SRC_ANCHOR_TYPE || type == HitTestResult.IMAGE_TYPE || type == HitTestResult.UNKNOWN_TYPE) {
          Handler handler = new Handler(webView.getHandler().getLooper()) {
            @Override
            public void handleMessage(Message msg) {
              String url = (String) msg.getData().get("url");
              String image_url = extra;
              if (url == null && image_url == null) {
                super.handleMessage(msg);
              } else {
                if (type == HitTestResult.SRC_ANCHOR_TYPE) {
                  image_url = "";
                }
                // when any downloaded image file is showing in webView - https://github.com/lunascape/react-native-wkwebview/pull/45
                if (type == HitTestResult.IMAGE_TYPE && url == null) {
                  url = image_url;
                }
                WritableMap data = Arguments.createMap();
                data.putString("type", "contextmenu");
                data.putString("url", url);
                data.putString("image_url", image_url);
                WritableMap eventData = Arguments.createMap();
                eventData.putMap("data", data);
                dispatchEvent(webView, new TopMessageEvent(webView.getId(), eventData));
              }
            }
          };
          Message msg = handler.obtainMessage();
          webView.requestFocusNodeHref(msg);
        }
        return false; // return true to disable copy/paste action bar
      }
    });

    webView.setDownloadListener(new DownloadListener() {
      public void onDownloadStart(String url, String userAgent, String contentDisposition, String mimetype, long contentLength) {
        RNCWebViewModule module = getModule(reactContext);

        DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));

        String fileName = URLUtil.guessFileName(url, contentDisposition, mimetype);
        String downloadMessage = "Downloading " + fileName;

        //Attempt to add cookie, if it exists
        URL urlObj = null;
        try {
          urlObj = new URL(url);
          String baseUrl = urlObj.getProtocol() + "://" + urlObj.getHost();
          String cookie = CookieManager.getInstance().getCookie(baseUrl);
          request.addRequestHeader("Cookie", cookie);
          System.out.println("Got cookie for DownloadManager: " + cookie);
        } catch (MalformedURLException e) {
          System.out.println("Error getting cookie for DownloadManager: " + e.toString());
          e.printStackTrace();
        }

        //Finish setting up request
        request.addRequestHeader("User-Agent", userAgent);
        request.setTitle(fileName);
        request.setDescription(downloadMessage);
        request.allowScanningByMediaScanner();
        request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
        request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);

        module.setDownloadRequest(request);

        if (module.grantFileDownloaderPermissions()) {
          module.downloadFile();
        }
      }
    });

    return webView;
  }

  @ReactProp(name = "javaScriptEnabled")
  public void setJavaScriptEnabled(WebView view, boolean enabled) {
    view.getSettings().setJavaScriptEnabled(enabled);
  }

  @ReactProp(name = "showsHorizontalScrollIndicator")
  public void setShowsHorizontalScrollIndicator(WebView view, boolean enabled) {
    view.setHorizontalScrollBarEnabled(enabled);
  }

  @ReactProp(name = "showsVerticalScrollIndicator")
  public void setShowsVerticalScrollIndicator(WebView view, boolean enabled) {
    view.setVerticalScrollBarEnabled(enabled);
  }

  @ReactProp(name = "cacheEnabled")
  public void setCacheEnabled(WebView view, boolean enabled) {
    if (enabled) {
      Context ctx = view.getContext();
      if (ctx != null) {
        view.getSettings().setAppCachePath(ctx.getCacheDir().getAbsolutePath());
        view.getSettings().setCacheMode(WebSettings.LOAD_DEFAULT);
        view.getSettings().setAppCacheEnabled(true);
      }
    } else {
      view.getSettings().setCacheMode(WebSettings.LOAD_NO_CACHE);
      view.getSettings().setAppCacheEnabled(false);
    }
  }

  @ReactProp(name = "androidHardwareAccelerationDisabled")
  public void setHardwareAccelerationDisabled(WebView view, boolean disabled) {
    if (disabled) {
      view.setLayerType(View.LAYER_TYPE_SOFTWARE, null);
    }
  }

  @ReactProp(name = "overScrollMode")
  public void setOverScrollMode(WebView view, String overScrollModeString) {
    Integer overScrollMode;
    switch (overScrollModeString) {
      case "never":
        overScrollMode = View.OVER_SCROLL_NEVER;
        break;
      case "content":
        overScrollMode = View.OVER_SCROLL_IF_CONTENT_SCROLLS;
        break;
      case "always":
      default:
        overScrollMode = View.OVER_SCROLL_ALWAYS;
        break;
    }
    view.setOverScrollMode(overScrollMode);
  }

  @ReactProp(name = "thirdPartyCookiesEnabled")
  public void setThirdPartyCookiesEnabled(WebView view, boolean enabled) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      CookieManager.getInstance().setAcceptThirdPartyCookies(view, enabled);
    }
  }

  @ReactProp(name = "textZoom")
  public void setTextZoom(WebView view, int value) {
    view.getSettings().setTextZoom(value);
  }

  @ReactProp(name = "scalesPageToFit")
  public void setScalesPageToFit(WebView view, boolean enabled) {
    view.getSettings().setLoadWithOverviewMode(enabled);
    view.getSettings().setUseWideViewPort(enabled);
  }

  @ReactProp(name = "domStorageEnabled")
  public void setDomStorageEnabled(WebView view, boolean enabled) {
    view.getSettings().setDomStorageEnabled(enabled);
  }

  @ReactProp(name = "userAgent")
  public void setUserAgent(WebView view, @Nullable String userAgent) {
    if (userAgent != null) {
      mUserAgent = userAgent;
    } else {
      mUserAgent = null;
    }
    this.setUserAgentString(view);
  }

  @ReactProp(name = "applicationNameForUserAgent")
  public void setApplicationNameForUserAgent(WebView view, @Nullable String applicationName) {
    if(applicationName != null) {
      if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
        String defaultUserAgent = WebSettings.getDefaultUserAgent(view.getContext());
        mUserAgentWithApplicationName = defaultUserAgent + " " + applicationName;
      }
    } else {
      mUserAgentWithApplicationName = null;
    }
    this.setUserAgentString(view);
  }

  protected void setUserAgentString(WebView view) {
    if(mUserAgent != null) {
      view.getSettings().setUserAgentString(mUserAgent);
    } else if(mUserAgentWithApplicationName != null) {
      view.getSettings().setUserAgentString(mUserAgentWithApplicationName);
    } else if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
      // handle unsets of `userAgent` prop as long as device is >= API 17
      view.getSettings().setUserAgentString(WebSettings.getDefaultUserAgent(view.getContext()));
    }
  }

  @TargetApi(Build.VERSION_CODES.JELLY_BEAN_MR1)
  @ReactProp(name = "mediaPlaybackRequiresUserAction")
  public void setMediaPlaybackRequiresUserAction(WebView view, boolean requires) {
    view.getSettings().setMediaPlaybackRequiresUserGesture(requires);
  }

  @ReactProp(name = "allowUniversalAccessFromFileURLs")
  public void setAllowUniversalAccessFromFileURLs(WebView view, boolean allow) {
    view.getSettings().setAllowUniversalAccessFromFileURLs(allow);
  }

  @ReactProp(name = "saveFormDataDisabled")
  public void setSaveFormDataDisabled(WebView view, boolean disable) {
    view.getSettings().setSaveFormData(!disable);
  }

  @ReactProp(name = "injectedJavaScript")
  public void setInjectedJavaScript(WebView view, @Nullable String injectedJavaScript) {
    ((RNCWebView) view).setInjectedJavaScript(injectedJavaScript);
  }

  @ReactProp(name = "injectedJavaScriptBeforeDocumentLoad")
  public void setInjectedJavaScriptBeforeDocumentLoad(WebView view, @Nullable String injectedJavaScriptBeforeDocumentLoad) {
    String injectedScript = getModule((ReactContext)view.getContext()).getInjectedScript();
    if ((injectedScript == null || injectedScript.length() == 0) &&
        (injectedJavaScriptBeforeDocumentLoad == null || injectedJavaScriptBeforeDocumentLoad.length() == 0)
    ) {
      return;
    }
    ((RNCWebView) view).setInjectedJavaScriptBeforeDocumentLoad(injectedJavaScriptBeforeDocumentLoad + injectedScript);
  }

  @ReactProp(name = "messagingEnabled")
  public void setMessagingEnabled(WebView view, boolean enabled) {
    ((RNCWebView) view).setMessagingEnabled(enabled);
  }
  @ReactProp(name = "incognito")
  public void setIncognito(WebView view, boolean enabled) {
    // Remove all previous cookies
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      CookieManager.getInstance().removeAllCookies(null);
    } else {
      CookieManager.getInstance().removeAllCookie();
    }

    // Disable caching
    view.getSettings().setCacheMode(WebSettings.LOAD_NO_CACHE);
    view.getSettings().setAppCacheEnabled(!enabled);
    view.clearHistory();
    view.clearCache(enabled);

    // No form data or autofill enabled
    view.clearFormData();
    view.getSettings().setSavePassword(!enabled);
    view.getSettings().setSaveFormData(!enabled);
  }

  @ReactProp(name = "source")
  public void setSource(WebView view, @Nullable ReadableMap source) {
    if (source != null) {
      if (source.hasKey("html")) {
        String html = source.getString("html");
        String baseUrl = source.hasKey("baseUrl") ? source.getString("baseUrl") : "";
        view.loadDataWithBaseURL(baseUrl, html, HTML_MIME_TYPE, HTML_ENCODING, null);
        return;
      }
      if (source.hasKey("uri")) {
        String url = source.getString("uri");
        String previousUrl = view.getUrl();
        if (previousUrl != null && previousUrl.equals(url)) {
          return;
        }
        if (source.hasKey("method")) {
          String method = source.getString("method");
          if (method.equalsIgnoreCase(HTTP_METHOD_POST)) {
            byte[] postData = null;
            if (source.hasKey("body")) {
              String body = source.getString("body");
              try {
                postData = body.getBytes("UTF-8");
              } catch (UnsupportedEncodingException e) {
                postData = body.getBytes();
              }
            }
            if (postData == null) {
              postData = new byte[0];
            }
            view.postUrl(url, postData);
            return;
          }
        }
        HashMap<String, String> headerMap = new HashMap<>();
        if (source.hasKey("headers")) {
          ReadableMap headers = source.getMap("headers");
          ReadableMapKeySetIterator iter = headers.keySetIterator();
          while (iter.hasNextKey()) {
            String key = iter.nextKey();
            if ("user-agent".equals(key.toLowerCase(Locale.ENGLISH))) {
              if (view.getSettings() != null) {
                view.getSettings().setUserAgentString(headers.getString(key));
              }
            } else {
              headerMap.put(key, headers.getString(key));
            }
          }
        }
        view.loadUrl(url, headerMap);
        return;
      }
    }
    view.loadUrl(BLANK_URL);
  }

  @ReactProp(name = "onContentSizeChange")
  public void setOnContentSizeChange(WebView view, boolean sendContentSizeChangeEvents) {
    ((RNCWebView) view).setSendContentSizeChangeEvents(sendContentSizeChangeEvents);
  }

  @ReactProp(name = "mixedContentMode")
  public void setMixedContentMode(WebView view, @Nullable String mixedContentMode) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      if (mixedContentMode == null || "never".equals(mixedContentMode)) {
        view.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
      } else if ("always".equals(mixedContentMode)) {
        view.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
      } else if ("compatibility".equals(mixedContentMode)) {
        view.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);
      }
    }
  }

  @ReactProp(name = "urlPrefixesForDefaultIntent")
  public void setUrlPrefixesForDefaultIntent(
    WebView view,
    @Nullable ReadableArray urlPrefixesForDefaultIntent) {
    RNCWebViewClient client = ((RNCWebView) view).getRNCWebViewClient();
    if (client != null && urlPrefixesForDefaultIntent != null) {
      client.setUrlPrefixesForDefaultIntent(urlPrefixesForDefaultIntent);
    }
  }

  @ReactProp(name = "allowsFullscreenVideo")
  public void setAllowsFullscreenVideo(
    WebView view,
    @Nullable Boolean allowsFullscreenVideo) {
    mAllowsFullscreenVideo = allowsFullscreenVideo != null && allowsFullscreenVideo;
    setupWebChromeClient((ReactContext)view.getContext(), view);
  }

  @ReactProp(name = "allowFileAccess")
  public void setAllowFileAccess(
    WebView view,
    @Nullable Boolean allowFileAccess) {
    view.getSettings().setAllowFileAccess(allowFileAccess != null && allowFileAccess);
  }

  @ReactProp(name = "geolocationEnabled")
  public void setGeolocationEnabled(
    WebView view,
    @Nullable Boolean isGeolocationEnabled) {
    view.getSettings().setGeolocationEnabled(isGeolocationEnabled != null && isGeolocationEnabled);
  }

  @ReactProp(name = "onScroll")
  public void setOnScroll(WebView view, boolean hasScrollEvent) {
    ((RNCWebView) view).setHasScrollEvent(hasScrollEvent);
  }

  @ReactProp(name = "adblockRules")
  public void setAdblockRules(WebView view, @Nullable ReadableArray rules) {
    RNCWebViewClient client = ((RNCWebView) view).getRNCWebViewClient();
    if (client != null) {
      client.setAdblockRules(rules);
    }
  }

  @Override
  protected void addEventEmitters(ThemedReactContext reactContext, WebView view) {
    // Do not register default touch emitter and let WebView implementation handle touches
    RNCWebViewClient currentClient = ((RNCWebView)view).mRNCWebViewClient;
    RNCWebViewClient newClient = new RNCWebViewClient(reactContext);

    if (currentClient != null) {
      // Client was setup before in onCreateWindow
      // However it has some override methods, so we have to replace it by a default client
      // ==> Transfer settings before replacing
      newClient.cloneSettings(currentClient);
    }
    view.setWebViewClient(newClient);
  }

  @Override
  public Map getExportedCustomDirectEventTypeConstants() {
    Map export = super.getExportedCustomDirectEventTypeConstants();
    if (export == null) {
      export = MapBuilder.newHashMap();
    }
    export.put(TopLoadingProgressEvent.EVENT_NAME, MapBuilder.of("registrationName", "onLoadingProgress"));
    export.put(TopShouldStartLoadWithRequestEvent.EVENT_NAME, MapBuilder.of("registrationName", "onShouldStartLoadWithRequest"));
    export.put(ScrollEventType.getJSEventName(ScrollEventType.SCROLL), MapBuilder.of("registrationName", "onScroll"));
    export.put(TopHttpErrorEvent.EVENT_NAME, MapBuilder.of("registrationName", "onHttpError"));
    export.put(TopCreateNewWindowEvent.EVENT_NAME, MapBuilder.of("registrationName", "onShouldCreateNewWindow"));
    export.put(TopCaptureScreenEvent.EVENT_NAME, MapBuilder.of("registrationName", "onCaptureScreen"));
    export.put(TopMessageEvent.EVENT_NAME, MapBuilder.of("registrationName", "onMessage"));
    export.put(TopWebViewClosedEvent.EVENT_NAME, MapBuilder.of("registrationName", "onWebViewClosed"));
    return export;
  }

  @Override
  public @Nullable
  Map<String, Integer> getCommandsMap() {
    Map map = MapBuilder.of(
      "goBack", COMMAND_GO_BACK,
      "goForward", COMMAND_GO_FORWARD,
      "reload", COMMAND_RELOAD,
      "stopLoading", COMMAND_STOP_LOADING,
      "postMessage", COMMAND_POST_MESSAGE,
      "injectJavaScript", COMMAND_INJECT_JAVASCRIPT,
      "loadUrl", COMMAND_LOAD_URL
    );
    map.put("requestFocus", COMMAND_FOCUS);
    map.put("captureScreen", COMMAND_CAPTURE_SCREEN);
    map.put("findInPage", COMMAND_SEARCH_IN_PAGE);
    return map;
  }

  @Override
  public void receiveCommand(WebView root, int commandId, @Nullable ReadableArray args) {
    switch (commandId) {
      case COMMAND_GO_BACK:
        root.goBack();
        break;
      case COMMAND_GO_FORWARD:
        root.goForward();
        break;
      case COMMAND_RELOAD:
        root.reload();
        break;
      case COMMAND_STOP_LOADING:
        root.stopLoading();
        break;
      case COMMAND_POST_MESSAGE:
        try {
          RNCWebView reactWebView = (RNCWebView) root;
          JSONObject eventInitDict = new JSONObject();
          eventInitDict.put("data", args.getString(0));
          reactWebView.evaluateJavascriptWithFallback("(function () {" +
            "var event;" +
            "var data = " + eventInitDict.toString() + ";" +
            "try {" +
            "event = new MessageEvent('message', data);" +
            "} catch (e) {" +
            "event = document.createEvent('MessageEvent');" +
            "event.initMessageEvent('message', true, true, data.data, data.origin, data.lastEventId, data.source);" +
            "}" +
            "document.dispatchEvent(event);" +
            "})();");
        } catch (JSONException e) {
          throw new RuntimeException(e);
        }
        break;
      case COMMAND_INJECT_JAVASCRIPT:
        RNCWebView reactWebView = (RNCWebView) root;
        reactWebView.evaluateJavascriptWithFallback(args.getString(0));
        break;
      case COMMAND_LOAD_URL:
        if (args == null) {
          throw new RuntimeException("Arguments for loading an url are null!");
        }
        root.loadUrl(args.getString(0));
        break;
      case COMMAND_FOCUS:
        root.requestFocus();
        break;
      case COMMAND_CAPTURE_SCREEN:
        ((RNCWebView) root).captureScreen(args.getString(0));
        break;
      case COMMAND_SEARCH_IN_PAGE:
        ((RNCWebView) root).searchInPage(args.getString(0));
        break;
    }
  }

  @Override
  public void onDropViewInstance(WebView webView) {
    super.onDropViewInstance(webView);
    ((ThemedReactContext) webView.getContext()).removeLifecycleEventListener((RNCWebView) webView);
    ((RNCWebView) webView).cleanupCallbacksAndDestroy();
  }

  public static RNCWebViewModule getModule(ReactContext reactContext) {
    return reactContext.getNativeModule(RNCWebViewModule.class);
  }

  protected void setupWebChromeClient(ReactContext reactContext, WebView webView) {
    if (mAllowsFullscreenVideo) {
      int initialRequestedOrientation = reactContext.getCurrentActivity().getRequestedOrientation();
      mWebChromeClient = new RNCWebChromeClient(reactContext, webView) {
        @Override
        public void onShowCustomView(View view, CustomViewCallback callback) {
          if (mVideoView != null) {
            callback.onCustomViewHidden();
            return;
          }

          mVideoView = view;
          mCustomViewCallback = callback;

          mReactContext.getCurrentActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);

          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            mVideoView.setSystemUiVisibility(FULLSCREEN_SYSTEM_UI_VISIBILITY);
            mReactContext.getCurrentActivity().getWindow().setFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS);
          }

          mVideoView.setBackgroundColor(Color.BLACK);
          getRootView().addView(mVideoView, FULLSCREEN_LAYOUT_PARAMS);
          mWebView.setVisibility(View.GONE);

          mReactContext.addLifecycleEventListener(this);
        }

        @Override
        public void onHideCustomView() {
          if (mVideoView == null) {
            return;
          }

          mVideoView.setVisibility(View.GONE);
          getRootView().removeView(mVideoView);
          mCustomViewCallback.onCustomViewHidden();

          mVideoView = null;
          mCustomViewCallback = null;

          mWebView.setVisibility(View.VISIBLE);

          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            mReactContext.getCurrentActivity().getWindow().clearFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS);
          }
          mReactContext.getCurrentActivity().setRequestedOrientation(initialRequestedOrientation);

          mReactContext.removeLifecycleEventListener(this);
        }
      };
      webView.setWebChromeClient(mWebChromeClient);
    } else {
      if (mWebChromeClient != null) {
        mWebChromeClient.onHideCustomView();
      }
      mWebChromeClient = new RNCWebChromeClient(reactContext, webView);
      webView.setWebChromeClient(mWebChromeClient);
    }
  }

  protected static class RNCWebViewClient extends WebViewClient {
    protected ReactContext mReactContext;

    private OkHttpClient httpClient;
    private ArrayList<Engine> adblockEngines;

    protected boolean mLastLoadFailed = false;
    protected @Nullable
    ReadableArray mUrlPrefixesForDefaultIntent;

    protected Uri mainUrl;

    public RNCWebViewClient(ReactContext reactContext) {
      this.mReactContext = reactContext;

      httpClient = new okhttp3.OkHttpClient.Builder()
        .followRedirects(false)
        .followSslRedirects(false)
        .cookieJar(new RNCWebViewCookieJar())
        .build();
    }

    protected ArrayList<Engine> getAdblockRules() {
      return adblockEngines;
    }

    protected void cloneAdblockRules(RNCWebViewClient parentClient) {
      if (parentClient.getAdblockRules() != null) {
        adblockEngines = (ArrayList<Engine>)parentClient.getAdblockRules().clone();
      }
    }

    protected void cloneSettings(RNCWebViewClient parentClient) {
      cloneAdblockRules(parentClient);
      mLastLoadFailed = parentClient.mLastLoadFailed;
      mainUrl = parentClient.mainUrl;
    }

    @Override
    public void onPageFinished(WebView webView, String url) {
      super.onPageFinished(webView, url);

      if (!mLastLoadFailed) {
        RNCWebView reactWebView = (RNCWebView) webView;

        reactWebView.callInjectedJavaScript();

        emitFinishEvent(webView, url);
      }
    }

    @Override
    public void onPageStarted(WebView webView, String url, Bitmap favicon) {
      super.onPageStarted(webView, url, favicon);
      mLastLoadFailed = false;

      dispatchEvent(
        webView,
        new TopLoadingStartEvent(
          webView.getId(),
          createWebViewEvent(webView, url)));
    }

    private boolean _shouldOverrideUrlLoading(WebView view, String url, boolean isMainFrame) {
      activeUrl = url;
      WritableMap event = createWebViewEvent(view, url);
      event.putBoolean("mainFrame", isMainFrame);
      dispatchEvent(
        view,
        new TopShouldStartLoadWithRequestEvent(
          view.getId(),
          event));
      return true;
    }

    @Override
    public boolean shouldOverrideUrlLoading(WebView view, String url) {
      return this._shouldOverrideUrlLoading(view, url, true);
    }

    @TargetApi(Build.VERSION_CODES.N)
    @Override
    public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
      final String url = request.getUrl().toString();
      return this._shouldOverrideUrlLoading(view, url, request.isForMainFrame());
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
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

        if (adblockEngines != null) {
          BlockerResult blockerResult;

          for (Engine engine : adblockEngines) {
            synchronized (engine) {
              if (request.isForMainFrame()) {
                blockerResult = engine.match(url.toString(), url.getHost(), "", false, "");
              } else {
                blockerResult = engine.match(url.toString(), url.getHost(), mainUrl.getHost(), false, "");
              }
            }

            if (blockerResult.matched) {
              return new WebResourceResponse("text/plain", "utf-8", new ByteArrayInputStream("".getBytes()));
            }
          }
        }

        if (((RNCWebView) view).injectedJSBeforeDocumentLoad == null) {
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

        ResponseBody body = response.body();
        MediaType type = body != null ? body.contentType() : null;
        String mimeType = type != null ? type.type() + "/" + type.subtype() : null;
        Charset charset = type != null ? type.charset(UTF_8) : null;
        String encoding = charset != null ? charset.displayName() : null;
        InputStream bis = body != null ? body.byteStream() : null;
        HashMap<String, String> map = new HashMap<>();
        Headers headers = response.headers();
        for (String key : headers.names()) {
          map.put(key, headers.get(key));
        }
        int statusCode = response.code();
        String message = response.message();
        if (TextUtils.isEmpty(message)) {
          message = "Unknown";
        }

        if (statusCode == 401) {
          return null;
        }

        if (response.isRedirect()) {
          String location = response.header("Location");
          if (location != null) {
            view.post(new Runnable() {
              @Override
              public void run() {
                view.loadUrl(location, requestHeaders);
              }
            });
          }
          return new WebResourceResponse("text/html", "utf-8", new InputStream() {
            @Override
            public int read() throws IOException {
              return 0;
            }
          });
        }

        if (mimeType == null || !mimeType.equalsIgnoreCase("text/html")) {
          return new WebResourceResponse(mimeType, encoding, statusCode, message, map, bis);
        }

        if (!response.isSuccessful()) {
          return new WebResourceResponse(mimeType, encoding, statusCode, message, map, bis);
        }

        InputStreamWithInjectedJS iis = new InputStreamWithInjectedJS(
          bis, ((RNCWebView) view).injectedJSBeforeDocumentLoad, charset);

        return new WebResourceResponse(mimeType, encoding, statusCode, message, map, iis);
      } catch (Exception e) {
        return null;
      }
    }

    @Override
    public void onReceivedError(
      WebView webView,
      int errorCode,
      String description,
      String failingUrl) {
      super.onReceivedError(webView, errorCode, description, failingUrl);
      mLastLoadFailed = true;

      // In case of an error JS side expect to get a finish event first, and then get an error event
      // Android WebView does it in the opposite way, so we need to simulate that behavior
      emitFinishEvent(webView, failingUrl);

      WritableMap eventData = createWebViewEvent(webView, failingUrl);
      eventData.putDouble("code", errorCode);
      eventData.putString("description", description);

      dispatchEvent(
        webView,
        new TopLoadingErrorEvent(webView.getId(), eventData));
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

        dispatchEvent(
          webView,
          new TopHttpErrorEvent(webView.getId(), eventData));
      }
    }

    protected void emitFinishEvent(WebView webView, String url) {
      dispatchEvent(
        webView,
        new TopLoadingFinishEvent(
          webView.getId(),
          createWebViewEvent(webView, url)));
    }

    protected WritableMap createWebViewEvent(WebView webView, String url) {
      WritableMap event = Arguments.createMap();
      event.putDouble("target", webView.getId());
      // Don't use webView.getUrl() here, the URL isn't updated to the new value yet in callbacks
      // like onPageFinished
      event.putString("url", url);
      event.putBoolean("loading", !mLastLoadFailed && webView.getProgress() != 100);
      event.putString("title", webView.getTitle());
      event.putBoolean("canGoBack", webView.canGoBack());
      event.putBoolean("canGoForward", webView.canGoForward());
      event.putDouble("progress", webView.getProgress());
      return event;
    }

    public void setUrlPrefixesForDefaultIntent(ReadableArray specialUrls) {
      mUrlPrefixesForDefaultIntent = specialUrls;
    }

    @Override
    public void onReceivedHttpAuthRequest(WebView view, final HttpAuthHandler handler, String host, String realm) {
      AlertDialog.Builder builder = new AlertDialog.Builder(view.getContext());
      LayoutInflater inflater = LayoutInflater.from(view.getContext());
      builder.setView(inflater.inflate(R.layout.authenticate, null));

      final AlertDialog alertDialog = builder.create();
      alertDialog.getWindow().setLayout(600, 400);
      alertDialog.show();
      TextView titleTv = alertDialog.findViewById(R.id.tv_login);
      titleTv.setText(view.getResources().getString(R.string.login_title).replace("%s", host));
      Button btnLogin = alertDialog.findViewById(R.id.btn_login);
      Button btnCancel = alertDialog.findViewById(R.id.btn_cancel);
      final EditText userField = alertDialog.findViewById(R.id.edt_username);
      final EditText passField = alertDialog.findViewById(R.id.edt_password);
      btnCancel.setOnClickListener(new View.OnClickListener() {
        @Override
        public void onClick(View view) {
          alertDialog.dismiss();
          handler.cancel();
        }
      });
      btnLogin.setOnClickListener(new View.OnClickListener() {
        @Override
        public void onClick(View view) {
          alertDialog.dismiss();
          handler.proceed(userField.getText().toString(), passField.getText().toString());
        }
      });
    }

    public void setAdblockRules(ReadableArray rules) {
      if (rules != null) {
        adblockEngines = new ArrayList<Engine>();
        for (int i = 0; i < rules.size(); i++) {
          adblockEngines.add(((RNCWebViewModule)getModule(mReactContext)).getAdblockEngine(rules.getString(i)));
        }
      } else {
        adblockEngines = null;
      }
    }
  }

  protected static class RNCWebChromeClient extends WebChromeClient implements LifecycleEventListener {
    protected static final FrameLayout.LayoutParams FULLSCREEN_LAYOUT_PARAMS = new FrameLayout.LayoutParams(
      LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT, Gravity.CENTER);

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    protected static final int FULLSCREEN_SYSTEM_UI_VISIBILITY = View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
      View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
      View.SYSTEM_UI_FLAG_LAYOUT_STABLE |
      View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
      View.SYSTEM_UI_FLAG_FULLSCREEN |
      View.SYSTEM_UI_FLAG_IMMERSIVE |
      View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;

    protected ReactContext mReactContext;
    protected View mWebView;

    protected View mVideoView;
    protected WebChromeClient.CustomViewCallback mCustomViewCallback;

    public RNCWebChromeClient(ReactContext reactContext, WebView webView) {
      this.mReactContext = reactContext;
      this.mWebView = webView;
    }

    @Override
    public boolean onConsoleMessage(ConsoleMessage message) {
      if (ReactBuildConfig.DEBUG) {
        return super.onConsoleMessage(message);
      }
      // Ignore console logs in non debug builds.
      return true;
    }

    // Fix WebRTC permission request error.
    @Override
    public void onPermissionRequest(final PermissionRequest request) {
      String[] requestedResources = request.getResources();
      ArrayList<String> permissions = new ArrayList<>();
      ArrayList<String> grantedPermissions = new ArrayList<String>();
      for (int i = 0; i < requestedResources.length; i++) {
        if (requestedResources[i].equals(PermissionRequest.RESOURCE_AUDIO_CAPTURE)) {
          permissions.add(Manifest.permission.RECORD_AUDIO);
        } else if (requestedResources[i].equals(PermissionRequest.RESOURCE_VIDEO_CAPTURE)) {
          permissions.add(Manifest.permission.CAMERA);
        }
        // TODO: RESOURCE_MIDI_SYSEX, RESOURCE_PROTECTED_MEDIA_ID.
      }

      for (int i = 0; i < permissions.size(); i++) {
        if (ContextCompat.checkSelfPermission(mReactContext, permissions.get(i)) != PackageManager.PERMISSION_GRANTED) {
          continue;
        }
        if (permissions.get(i).equals(Manifest.permission.RECORD_AUDIO)) {
          grantedPermissions.add(PermissionRequest.RESOURCE_AUDIO_CAPTURE);
        } else if (permissions.get(i).equals(Manifest.permission.CAMERA)) {
          grantedPermissions.add(PermissionRequest.RESOURCE_VIDEO_CAPTURE);
        }
      }

      if (grantedPermissions.isEmpty()) {
        request.deny();
      } else {
        String[] grantedPermissionsArray = new String[grantedPermissions.size()];
        grantedPermissionsArray = grantedPermissions.toArray(grantedPermissionsArray);
        request.grant(grantedPermissionsArray);
      }
    }

    @Override
    public void onProgressChanged(WebView webView, int newProgress) {
      super.onProgressChanged(webView, newProgress);
      final String url = webView.getUrl();
      if (
        url != null
        && activeUrl != null
        && !url.equals(activeUrl)
      ) {
        return;
      }
      WritableMap event = Arguments.createMap();
      event.putDouble("target", webView.getId());
      event.putString("title", webView.getTitle());
      event.putString("url", url);
      event.putBoolean("canGoBack", webView.canGoBack());
      event.putBoolean("canGoForward", webView.canGoForward());
      event.putDouble("progress", (float) newProgress / 100);
      dispatchEvent(
        webView,
        new TopLoadingProgressEvent(
          webView.getId(),
          event));
    }

    @Override
    public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
      callback.invoke(origin, true, false);
    }

    protected void openFileChooser(ValueCallback<Uri> filePathCallback, String acceptType) {
      getModule(mReactContext).startPhotoPickerIntent(filePathCallback, acceptType);
    }

    protected void openFileChooser(ValueCallback<Uri> filePathCallback) {
      getModule(mReactContext).startPhotoPickerIntent(filePathCallback, "");
    }

    protected void openFileChooser(ValueCallback<Uri> filePathCallback, String acceptType, String capture) {
      getModule(mReactContext).startPhotoPickerIntent(filePathCallback, acceptType);
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    @Override
    public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback, FileChooserParams fileChooserParams) {
      String[] acceptTypes = fileChooserParams.getAcceptTypes();
      boolean allowMultiple = fileChooserParams.getMode() == WebChromeClient.FileChooserParams.MODE_OPEN_MULTIPLE;
      Intent intent = fileChooserParams.createIntent();
      return getModule(mReactContext).startPhotoPickerIntent(filePathCallback, intent, acceptTypes, allowMultiple);
    }
    @Override
    public boolean onCreateWindow(final WebView webView, boolean isDialog, boolean isUserGesture, Message resultMsg) {
      // Create a new view
      RNCWebView newView = RNCWebView.createNewWindow((ThemedReactContext) mReactContext);
      newView.setWebViewClient(new RNCWebViewClient((ThemedReactContext) mReactContext) {
        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
          WritableMap eventData = Arguments.createMap();
          eventData.putDouble("target", webView.getId());
          eventData.putString("url", url);
          eventData.putBoolean("loading", false);
          eventData.putDouble("progress", webView.getProgress());
          eventData.putString("title", webView.getTitle());
          eventData.putBoolean("canGoBack", webView.canGoBack());
          eventData.putBoolean("canGoForward", webView.canGoForward());
          dispatchEvent(webView, new TopCreateNewWindowEvent(webView.getId(), eventData));
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
          return false;
        }

        @TargetApi(Build.VERSION_CODES.N)
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
          final String url = request.getUrl().toString();
          return this.shouldOverrideUrlLoading(view, url);
        }
      });

      // Clone settings from parent view
      newView.cloneSettings((RNCWebView)webView);
      newView.setLayoutParams(new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
      newView.setVisibility(View.GONE);

      webView.addView(newView);

      WebView.WebViewTransport transport = (WebView.WebViewTransport) resultMsg.obj;
      transport.setWebView(newView);
      resultMsg.sendToTarget();
      return true;
    }

    @Override
    public void onCloseWindow(WebView webView) {
      WritableMap event = Arguments.createMap();
      event.putDouble("target", webView.getId());
      event.putString("title", webView.getTitle());
      event.putString("url", webView.getUrl());
      event.putBoolean("canGoBack", webView.canGoBack());
      event.putBoolean("canGoForward", webView.canGoForward());
      event.putDouble("progress", (float) webView.getProgress() / 100);
      dispatchEvent(webView, new TopWebViewClosedEvent(webView.getId(), event));
    }

    @Override
    public void onHostResume() {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT && mVideoView != null && mVideoView.getSystemUiVisibility() != FULLSCREEN_SYSTEM_UI_VISIBILITY) {
        mVideoView.setSystemUiVisibility(FULLSCREEN_SYSTEM_UI_VISIBILITY);
      }
    }

    @Override
    public void onHostPause() { }

    @Override
    public void onHostDestroy() { }

    protected ViewGroup getRootView() {
      return (ViewGroup) mReactContext.getCurrentActivity().findViewById(android.R.id.content);
    }
  }

  /**
   * Subclass of {@link WebView} that implements {@link LifecycleEventListener} interface in order
   * to call {@link WebView#destroy} on activity destroy event and also to clear the client
   */
  protected static class RNCWebView extends WebView implements LifecycleEventListener {
    protected @Nullable
    String injectedJS;
    String injectedJSBeforeDocumentLoad;
    protected boolean messagingEnabled = false;
    protected @Nullable
    RNCWebViewClient mRNCWebViewClient;
    protected boolean sendContentSizeChangeEvents = false;
    private OnScrollDispatchHelper mOnScrollDispatchHelper;
    protected boolean hasScrollEvent = false;

    private static RNCWebView newWindow;

    /**
     * WebView must be created with an context of the current activity
     * <p>
     * Activity Context is required for creation of dialogs internally by WebView
     * Reactive Native needed for access to ReactNative internal system functionality
     */

    public static RNCWebView createNewInstance(ThemedReactContext reactContext) {
      RNCWebView webView = null;
      if (newWindow != null) {
        webView = newWindow;
        try {
          ViewGroup parent = (ViewGroup)newWindow.getParent();
          if (parent != null) {
            parent.removeView(newWindow);
          }
        } catch (Exception e) {
          Log.e("RNCWebView", "createNewInstance error: " + e.getLocalizedMessage());
        }
        newWindow = null;
      } else {
        webView = new RNCWebView(reactContext);
      }
      return webView;
    }
    public static RNCWebView createNewWindow(ThemedReactContext reactContext) {
      newWindow = new RNCWebView(reactContext);
      return newWindow;
    }

    private RNCWebView(ThemedReactContext reactContext) {
      super(reactContext);
    }

    public void cloneSettings(RNCWebView parentView) {
      WebSettings settings = getSettings();
      WebSettings parentSettings = parentView.getSettings();

      settings.setBuiltInZoomControls(true);
      settings.setDisplayZoomControls(false);
      settings.setSupportMultipleWindows(true);

      settings.setJavaScriptEnabled(parentSettings.getJavaScriptEnabled());
      settings.setDomStorageEnabled(parentSettings.getDomStorageEnabled());
      settings.setLoadWithOverviewMode(parentSettings.getLoadWithOverviewMode());
      settings.setUseWideViewPort(parentSettings.getUseWideViewPort());
      settings.setTextZoom(parentSettings.getTextZoom());
      settings.setUserAgentString(parentSettings.getUserAgentString());
      settings.setMediaPlaybackRequiresUserGesture(parentSettings.getMediaPlaybackRequiresUserGesture());

      mRNCWebViewClient.cloneAdblockRules(parentView.mRNCWebViewClient);
      injectedJS = parentView.injectedJS;
      injectedJSBeforeDocumentLoad = parentView.injectedJSBeforeDocumentLoad;
      messagingEnabled = parentView.messagingEnabled;
      sendContentSizeChangeEvents = parentView.sendContentSizeChangeEvents;
    }

    @Override
    public int getContentHeight() {
      return computeVerticalScrollRange();
    }

    public void setSendContentSizeChangeEvents(boolean sendContentSizeChangeEvents) {
      this.sendContentSizeChangeEvents = sendContentSizeChangeEvents;
    }

    public void setHasScrollEvent(boolean hasScrollEvent) {
      this.hasScrollEvent = hasScrollEvent;
    }

    @Override
    public void onHostResume() {
      // do nothing
    }

    @Override
    public void onHostPause() {
      // do nothing
    }

    @Override
    public void onHostDestroy() {
      cleanupCallbacksAndDestroy();
    }

    @Override
    protected void onSizeChanged(int w, int h, int ow, int oh) {
      super.onSizeChanged(w, h, ow, oh);

      if (sendContentSizeChangeEvents) {
        dispatchEvent(
          this,
          new ContentSizeChangeEvent(
            this.getId(),
            w,
            h
          )
        );
      }
    }

    @Override
    public void setWebViewClient(WebViewClient client) {
      super.setWebViewClient(client);
      mRNCWebViewClient = (RNCWebViewClient) client;
    }

    public @Nullable
    RNCWebViewClient getRNCWebViewClient() {
      return mRNCWebViewClient;
    }

    public void setInjectedJavaScript(@Nullable String js) {
      injectedJS = js;
    }

    public void setInjectedJavaScriptBeforeDocumentLoad(@Nullable String js) {
      injectedJSBeforeDocumentLoad = js;
    }

    protected RNCWebViewBridge createRNCWebViewBridge(RNCWebView webView) {
      return new RNCWebViewBridge(webView);
    }

    @SuppressLint("AddJavascriptInterface")
    public void setMessagingEnabled(boolean enabled) {
      if (messagingEnabled == enabled) {
        return;
      }

      messagingEnabled = enabled;

      if (enabled) {
        addJavascriptInterface(createRNCWebViewBridge(this), JAVASCRIPT_INTERFACE);
      } else {
        removeJavascriptInterface(JAVASCRIPT_INTERFACE);
      }
    }

    protected void evaluateJavascriptWithFallback(String script) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
        evaluateJavascript(script, null);
        return;
      }

      try {
        loadUrl("javascript:" + URLEncoder.encode(script, "UTF-8"));
      } catch (UnsupportedEncodingException e) {
        // UTF-8 should always be supported
        throw new RuntimeException(e);
      }
    }

    public void callInjectedJavaScript() {
      if (getSettings().getJavaScriptEnabled() &&
        injectedJS != null &&
        !TextUtils.isEmpty(injectedJS)) {
        evaluateJavascriptWithFallback("(function() {\n" + injectedJS + ";\n})();");
      }
    }

    public void onMessage(String message) {
      if (mRNCWebViewClient != null) {
        WebView webView = this;
        webView.post(new Runnable() {
          @Override
          public void run() {
            if (mRNCWebViewClient == null) {
              return;
            }
            WritableMap data = mRNCWebViewClient.createWebViewEvent(webView, webView.getUrl());
            data.putString("data", message);
            dispatchEvent(webView, new TopMessageEvent(webView.getId(), data));
          }
        });
      } else {
        WritableMap eventData = Arguments.createMap();
        eventData.putString("data", message);
        dispatchEvent(this, new TopMessageEvent(this.getId(), eventData));
      }
    }

    protected void onScrollChanged(int x, int y, int oldX, int oldY) {
      super.onScrollChanged(x, y, oldX, oldY);

      if (!hasScrollEvent) {
        return;
      }

      if (mOnScrollDispatchHelper == null) {
        mOnScrollDispatchHelper = new OnScrollDispatchHelper();
      }

      if (mOnScrollDispatchHelper.onScrollChanged(x, y)) {
        ScrollEvent event = ScrollEvent.obtain(
                this.getId(),
                ScrollEventType.SCROLL,
                x,
                y,
                mOnScrollDispatchHelper.getXFlingVelocity(),
                mOnScrollDispatchHelper.getYFlingVelocity(),
                this.computeHorizontalScrollRange(),
                this.computeVerticalScrollRange(),
                this.getWidth(),
                this.getHeight());

        dispatchEvent(this, event);
      }
    }

    protected void cleanupCallbacksAndDestroy() {
      setWebViewClient(null);
      destroy();
    }

    protected class RNCWebViewBridge {
      RNCWebView mContext;

      RNCWebViewBridge(RNCWebView c) {
        mContext = c;
      }

      /**
       * This method is called whenever JavaScript running within the web view calls:
       * - window[JAVASCRIPT_INTERFACE].postMessage
       */
      @JavascriptInterface
      public void postMessage(String message) {
        mContext.onMessage(message);
      }
    }

    public void captureScreen(String type) {
      final String fileName = System.currentTimeMillis() + ".jpg";
      String directory = type.equals("SCREEN_SHOT") ? TEMP_DIRECTORY : DOWNLOAD_DIRECTORY;

      File d = new File(directory);
      d.mkdirs();
      final String localFilePath = directory + fileName;
      boolean success = false;
      try {
        Picture picture = this.capturePicture();
        int width = type.equals("CAPTURE_SCREEN") ? this.getWidth() : picture.getWidth();
        int height = type.equals("CAPTURE_SCREEN") ? this.getHeight() : picture.getHeight();
        Bitmap b = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        picture.draw(c);

        FileOutputStream fos = new FileOutputStream(localFilePath);
        if (fos != null) {
          b.compress(Bitmap.CompressFormat.JPEG, 80, fos);
          fos.close();
        }
        success = true;
      } catch (Throwable t) {
        System.out.println(t);
      } finally {
        WritableMap event = Arguments.createMap();
        event.putDouble("target", this.getId());
        event.putBoolean("result", success);
        event.putString("type", type);
        if (success) {
          event.putString("data", localFilePath);
        }
        dispatchEvent(this, new TopCaptureScreenEvent(this.getId(), event));
      }
    }

    public void searchInPage(String keyword) {
      String[] words = keyword.split(" |　");
      String[] highlightColors = {
        "yellow", "cyan", "magenta", "greenyellow", "tomato", "lightskyblue"
      };
      try {
        InputStream fileInputStream;
        fileInputStream = this.getContext().getAssets().open("SearchWebView.js");
        byte[] readBytes = new byte[fileInputStream.available()];
        fileInputStream.read(readBytes);
        String jsString = new String(readBytes);

        StringBuilder sb = new StringBuilder();
        sb.append("MyApp_RemoveAllHighlights();");
        for (int i = 0; i < words.length; i++) {
          String color = i < highlightColors.length ? highlightColors[i] : highlightColors[highlightColors.length - 1];
          sb.append("MyApp_HighlightAllOccurencesOfString('" + words[i] + "','" + color + "');");
        }
        sb.append("alert('" + this.getContext().getString(R.string.dialog_found) + ": ' + MyApp_SearchResultCount);");
        sb.append("MyApp_ScrollToHighlightTop();");
        this.loadUrl("javascript:" + jsString + sb.toString());
      } catch (FileNotFoundException e) {
        e.printStackTrace();
      } catch (IOException e) {
        e.printStackTrace();
      }
    }
  }
}
