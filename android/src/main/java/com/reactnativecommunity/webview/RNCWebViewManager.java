package com.reactnativecommunity.webview;

import static java.nio.charset.StandardCharsets.UTF_8;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.app.Activity;
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

import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintManager;
import android.text.TextUtils;
import android.util.Log;
import android.view.Gravity;
import android.view.MotionEvent;
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

import com.facebook.react.modules.core.PermissionAwareActivity;
import com.facebook.react.modules.core.PermissionListener;
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
import com.reactnativecommunity.webview.downloaddatabase.DownloadRequest;
import com.reactnativecommunity.webview.events.TopFileDownloadEvent;
import com.reactnativecommunity.webview.events.TopGetFaviconEvent;
import com.reactnativecommunity.webview.events.TopLoadingErrorEvent;
import com.reactnativecommunity.webview.events.TopHttpErrorEvent;
import com.reactnativecommunity.webview.events.TopLoadingFinishEvent;
import com.reactnativecommunity.webview.events.TopLoadingProgressEvent;
import com.reactnativecommunity.webview.events.TopLoadingStartEvent;
import com.reactnativecommunity.webview.events.TopMessageEvent;
import com.reactnativecommunity.webview.events.TopRequestWebViewStatusEvent;
import com.reactnativecommunity.webview.events.TopShouldStartLoadWithRequestEvent;
import com.reactnativecommunity.webview.events.TopCreateNewWindowEvent;
import com.reactnativecommunity.webview.events.TopCaptureScreenEvent;
import com.reactnativecommunity.webview.events.TopWebViewOnFullScreenEvent;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import javax.annotation.Nullable;

import okhttp3.Headers;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

import android.os.Handler;
import android.webkit.WebView.HitTestResult;
import android.os.Message;
import android.widget.TextView;
import android.widget.Toast;

import com.brave.adblock.BlockerResult;
import com.brave.adblock.Engine;
import com.reactnativecommunity.webview.events.TopWebViewClosedEvent;
import com.reactnativecommunity.webview.utils.HtmlExtractor;
import com.reactnativecommunity.webview.utils.UrlUtils;
import com.reactnativecommunity.webview.utils.Utils;

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

  // SearchInPage
  public static final int COMMAND_SEARCH_IN_PAGE = 10;
  public static final int COMMAND_SEARCH_NEXT = 11;
  public static final int COMMAND_SEARCH_PREVIOUS = 12;
  public static final int COMMAND_REMOVE_ALL_HIGHLIGHTS = 13;
  public static final int COMMAND_PRINT_CONTENT = 14;
  public static final int COMMAND_SET_FONT_SIZE = 15;
  public static final int COMMAND_REQUEST_WEB_VIEW_STATUS = 16;
  public static final int COMMAND_REQUEST_WEB_FAVICON = 17;
  public static final int COMMAND_SET_ENABLE_NIGHT_MODE = 18;

  public static final String DOWNLOAD_DIRECTORY = Environment.getExternalStorageDirectory() + "/Android/data/jp.co.lunascape.android.ilunascape/downloads/";
  public static final String TEMP_DIRECTORY = Environment.getExternalStorageDirectory() + "/Android/data/jp.co.lunascape.android.ilunascape/temps/";

  protected static final String MIME_UNKNOWN = "application/octet-stream";
  protected static final String HTML_ENCODING = "UTF-8";
  protected static final long BYTES_IN_MEGABYTE = 1000000;

  protected static final String REACT_CLASS = "RNCWebView";

  protected static final String HEADER_CONTENT_TYPE = "content-type";

  protected static final String HTML_MIME_TYPE = "text/html";
  protected static final String JAVASCRIPT_INTERFACE = "ReactNativeWebView";
  protected static final String FAVICON_INTERFACE = "FaviconWebView";
  protected static final String NATIVE_SCRIPT_INTERFACE = "nativeScriptHandler";
  protected static final String HTTP_METHOD_POST = "POST";
  // Use `webView.loadUrl("about:blank")` to reliably reset the view
  // state and release page resources (including any running JavaScript).
  protected static final String BLANK_URL = "about:blank";
  protected WebViewConfig mWebViewConfig;

  protected RNCWebChromeClient mWebChromeClient = null;
  protected boolean mAllowsFullscreenVideo = false;
  protected @Nullable String mUserAgent = null;
  protected @Nullable String mUserAgentWithApplicationName = null;

  private String DOWNLOAD_FOLDER;

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

  @SuppressLint("AddJavascriptInterface")
  protected RNCWebView createRNCWebViewInstance(ThemedReactContext reactContext) {
    RNCWebView rncWebview = RNCWebView.createNewInstance(reactContext);
    rncWebview.addJavascriptInterface(rncWebview.createRNCNativeWebViewBridge(rncWebview), NATIVE_SCRIPT_INTERFACE);
    rncWebview.addJavascriptInterface(rncWebview.createRNCWebViewBridge(rncWebview), FAVICON_INTERFACE);
    return rncWebview;
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
        if (url.startsWith("blob")) {
          String jsConvert = "getBase64StringFromBlobUrl('" + url + "');";
          webView.loadUrl("javascript:" + jsConvert);
          return;
        }

         // block non-http/https download links
        if (!URLUtil.isNetworkUrl(url)) {
          Toast.makeText(reactContext.getCurrentActivity(), R.string.download_protocol_not_supported,
            Toast.LENGTH_LONG).show();
          return;
        }

        RNCWebViewModule module = getModule(reactContext);

        DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));

        String fileName = Utils.getFileNameDownload(url, contentDisposition, mimetype);
        String subPath = fileName;
        if (DOWNLOAD_FOLDER != null && !DOWNLOAD_FOLDER.isEmpty()) {
          subPath = DOWNLOAD_FOLDER + "/" + fileName;
        }
        String downloadMessage = "Downloading " + fileName;

        //Attempt to add cookie, if it exists
        URL urlObj = null;
        String cookie = "";
        try {
          urlObj = new URL(url);
          String baseUrl = urlObj.getProtocol() + "://" + urlObj.getHost();
          cookie = CookieManager.getInstance().getCookie(baseUrl);
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
        request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, subPath);

        module.setDownloadRequest(
          request,
          new DownloadRequest(-1, -1, url, userAgent, contentDisposition, mimetype, cookie, 0)
        );

        if (module.grantFileDownloaderPermissions()) {
          module.downloadFile();
          WritableMap eventData = Arguments.createMap();;
          eventData.putString("downloadUrl", url);
          dispatchEvent(webView, new TopFileDownloadEvent(webView.getId(), eventData));
        }
      }
    });

    /**
     * can use the injectedJavaScript prop to inject JavaScript code
     * TODO: rewrite this code later after refactoring AdBlockEngine in RNCWebViewClient -> shouldInterceptRequest
     * Ref: https://github.com/MetaMask/metamask-mobile/blob/047e3fec96dff293051ffa8170994739f70b154d/patches/react-native-webview%2B11.13.0.patch#L319
     * Ex: inject the web3 Javascript code into app.uniswap.org page (PWA)
     * */
//    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
//      ServiceWorkerController swController = ServiceWorkerController.getInstance();
//      swController.setServiceWorkerClient(new ServiceWorkerClient() {
//        @androidx.annotation.Nullable
//        @Override
//        public WebResourceResponse shouldInterceptRequest(WebResourceRequest request) {
//          String method = request.getMethod();
//
//          if(method.equals("GET")) {
//            WebResourceResponse response = RNCWebViewManager.this.shouldInterceptRequest(request, false, webView);
//            if (response != null) {
//              return response;
//            }
//          }
//
//          return super.shouldInterceptRequest(request);
//        }
//      });
//    }

    return webView;
  }

  // Ref: https://github.com/MetaMask/metamask-mobile/blob/047e3fec96dff293051ffa8170994739f70b154d/patches/react-native-webview%2B11.13.0.patch#L380C31-L380C53
  // the shouldInterceptRequest detail at RNCWebViewClient -> shouldInterceptRequest

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
      view.getSettings().setCacheMode(WebSettings.LOAD_DEFAULT);
    } else {
      view.getSettings().setCacheMode(WebSettings.LOAD_NO_CACHE);
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

  @ReactProp(name = "nestedScrollEnabled")
  public void setNestedScrollEnabled(WebView view, boolean enabled) {
    ((RNCWebView) view).setNestedScrollEnabled(enabled);
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

  @ReactProp(name = "additionalUserAgent")
  public void setAdditionalUserAgent(WebView view, @Nullable ReadableArray additionalUserAgent) {
    RNCWebViewClient client = ((RNCWebView) view).getRNCWebViewClient();
    if (client != null && additionalUserAgent != null) {
      client.setAdditionalUserAgent(additionalUserAgent);
    }
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

    RNCWebViewClient client = ((RNCWebView) view).getRNCWebViewClient();
    if (client != null) {
      client.setUserAgent(view.getSettings().getUserAgentString());
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
    ((RNCWebView) view).setInjectedJavaScriptBeforeDocumentLoad(injectedJavaScriptBeforeDocumentLoad);
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
        boolean preventLoadUrl = false;
        if (source.hasKey("preventLoadUrl")) {
          preventLoadUrl = source.getBoolean("preventLoadUrl");
        }
        if (preventLoadUrl) return;

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

  @ReactProp(name = "downloadConfig")
  public void setDownloadConfig(WebView view, @Nullable ReadableMap downloadConfig) {
    if (downloadConfig != null) {
      if (downloadConfig.hasKey("downloadFolder")) {
        String downloadFolder = downloadConfig.getString("downloadFolder");
        RNCWebViewModule module = getModule((ReactContext) view.getContext());
        RNCWebView rncWebView = (RNCWebView) view;
        rncWebView.setDownloadFolder(downloadFolder);
        module.setDownloadFolder(downloadFolder);
        DOWNLOAD_FOLDER = downloadFolder;
      }
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
    export.put(TopGetFaviconEvent.EVENT_NAME, MapBuilder.of("registrationName", "onGetFavicon"));
    export.put(TopMessageEvent.EVENT_NAME, MapBuilder.of("registrationName", "onMessage"));
    export.put(TopWebViewClosedEvent.EVENT_NAME, MapBuilder.of("registrationName", "onWebViewClosed"));
    export.put(TopWebViewOnFullScreenEvent.EVENT_NAME, MapBuilder.of("registrationName", "onVideoFullScreen"));
    export.put(TopRequestWebViewStatusEvent.EVENT_NAME, MapBuilder.of("registrationName", "onReceiveWebViewStatus"));
    export.put(TopFileDownloadEvent.EVENT_NAME, MapBuilder.of("registrationName", "onFileDownload"));
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
    map.put("findNext", COMMAND_SEARCH_NEXT);
    map.put("findPrevious", COMMAND_SEARCH_PREVIOUS);
    map.put("removeAllHighlights", COMMAND_REMOVE_ALL_HIGHLIGHTS);
    map.put("printContent", COMMAND_PRINT_CONTENT);
    map.put("setFontSize", COMMAND_SET_FONT_SIZE);
    map.put("requestWebViewStatus", COMMAND_REQUEST_WEB_VIEW_STATUS);
    map.put("requestWebFavicon", COMMAND_REQUEST_WEB_FAVICON);
    map.put("setEnableNightMode", COMMAND_SET_ENABLE_NIGHT_MODE);

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
      case COMMAND_SET_FONT_SIZE:
        ((RNCWebView) root).setFontSize(args.getInt(0));
        break;
      case COMMAND_SEARCH_NEXT:
        ((RNCWebView) root).searchNext();
        break;
      case COMMAND_SEARCH_PREVIOUS:
        ((RNCWebView) root).searchPrevious();
        break;
      case COMMAND_REMOVE_ALL_HIGHLIGHTS:
        ((RNCWebView) root).removeAllHighlights();
        break;
      case COMMAND_PRINT_CONTENT:
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
          ((RNCWebView) root).printContent();
        }
        break;
      case COMMAND_REQUEST_WEB_VIEW_STATUS:
        ((RNCWebView) root).requestWebViewStatus();
        break;
      case COMMAND_REQUEST_WEB_FAVICON:
        ((RNCWebView) root).getFaviconUrl();
        break;
      case COMMAND_SET_ENABLE_NIGHT_MODE:
        ((RNCWebView) root).setEnableNightMode(args.getString(0));
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
          mVideoView.setId(R.id.focus_video_in_webview_fullscreen);
          mReactContext.getCurrentActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);

          WritableMap data = Arguments.createMap();;
          data.putBoolean("fullscreen", true);
          dispatchEvent(webView, new TopWebViewOnFullScreenEvent(webView.getId(), data));

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

          WritableMap data = Arguments.createMap();;
          data.putBoolean("fullscreen", false);
          dispatchEvent(webView, new TopWebViewOnFullScreenEvent(webView.getId(), data));

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

    private @Nullable String mUserAgent = null; // to append with additional user agent
    protected @Nullable ReadableArray mAdditionalUserAgent = null;

    protected int mLoadingProgress = 0;
    protected boolean mLastLoadFailed = false;
    protected @Nullable
    ReadableArray mUrlPrefixesForDefaultIntent;

    protected Uri mainUrl;
    protected boolean isMainDocumentException;
    protected boolean mEnableNightMode = false;

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

    private String currentPageUrl = null;
    private String currentPageTitle = null;

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

    public void loadAdditionalUserAgent(WebView webview, String urlString) {
      if (mAdditionalUserAgent != null && mAdditionalUserAgent.size() > 0 && mUserAgent != null) {
        int size = mAdditionalUserAgent.size();
        for (int i = 0; i< size; i++) {
          ReadableMap object = mAdditionalUserAgent.getMap(i);
          String domain = object.getString("domain");
          if (domain != null && UrlUtils.isMatchDomain(urlString, domain)) {
            String extendedUserAgent = object.getString("extendedUserAgent");
            if (extendedUserAgent != null) {
              String newUserAgent = mUserAgent + " " + extendedUserAgent;
              webview.getSettings().setUserAgentString(newUserAgent);
              return;
            }
          }
        }
      }
    }

    @Override
    public void onLoadResource(WebView view, String url) {
      super.onLoadResource(view, url);
      String newRequestURL = view.getUrl();
      String newRequestTitle = view.getTitle();
      if(newRequestURL != null && (!newRequestURL.equals((currentPageUrl)) || !newRequestTitle.equals((currentPageTitle)) )){
        currentPageUrl = newRequestURL;
        currentPageTitle = newRequestTitle;
        dispatchEvent(
          view,
          new TopLoadingStartEvent(
            view.getId(),
            createWebViewEvent(view, currentPageUrl)));
      }
    }

    @Override
    public void doUpdateVisitedHistory(WebView view, String url, boolean isReload) {
      super.doUpdateVisitedHistory(view, url, isReload);
      if (url != null && !url.equals(currentPageUrl)) {
        currentPageUrl = url;
      }
      dispatchEvent(
        view,
        new TopLoadingStartEvent(
          view.getId(),
          createWebViewEvent(view, currentPageUrl)));
    }

    @Override
    public void onPageFinished(WebView webView, String url) {
      super.onPageFinished(webView, url);

      if (!mLastLoadFailed) {
        RNCWebView reactWebView = (RNCWebView) webView;
        String webviewUrl = webView.getUrl();
        boolean enableYoutubeAdblock = getEnableYoutubeVideoAdblocker(webviewUrl);
        reactWebView.callInjectedJavaScript(enableYoutubeAdblock);

        // load additional userAgent
        loadAdditionalUserAgent(webView, webviewUrl);
        
        reactWebView.linkWindowObject();

        emitFinishEvent(webView, url);

        reactWebView.getFaviconUrl();

        String jsNightMode = "window.NightMode.setEnabled(" + mEnableNightMode + ");";
        reactWebView.loadUrl("javascript:" + jsNightMode);
      }


    }

    @Override
    public void onPageStarted(WebView webView, String url, Bitmap favicon) {
      super.onPageStarted(webView, url, favicon);
      mLastLoadFailed = false;

      // remove the callInjectedJavaScriptBeforeContentLoaded function in this line. We're using another way to inject javascript code. 
      // Please check RNCWebViewClient -> shouldInterceptRequest
      // ref: https://github.com/MetaMask/metamask-mobile/blob/047e3fec96dff293051ffa8170994739f70b154d/patches/react-native-webview%2B11.13.0.patch#L650
      // RNCWebView reactNativeWebView = (RNCWebView) webView;
      // reactNativeWebView.callInjectedJavaScriptBeforeContentLoaded();

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

    public static Boolean responseRequiresJSInjection(Response response) {
      if (response.isRedirect()) {
        return false;
      }
      final String contentTypeAndCharset = response.header(HEADER_CONTENT_TYPE, MIME_UNKNOWN);
      final int responseCode = response.code();

      boolean contentTypeIsHtml = contentTypeAndCharset.startsWith(HTML_MIME_TYPE);
      boolean responseCodeIsInjectible = responseCode == 200;
      String responseBody = "";

      if (contentTypeIsHtml && responseCodeIsInjectible) {
        try {
          assert response.body() != null;
          responseBody = response.peekBody(BYTES_IN_MEGABYTE).string();
        } catch (IOException e) {
          e.printStackTrace();
          return false;
        }


        boolean responseBodyContainsHTMLLikeString = responseBody.matches("[\\S\\s]*<[a-z]+[\\S\\s]*>[\\S\\s]*");
        return responseBodyContainsHTMLLikeString;
      } else {
        return false;
      }
    }

    /**
     * fix android injection
     * https://github.com/MetaMask/metamask-mobile/pull/2070
     * https://github.com/MetaMask/metamask-mobile/blob/047e3fec96dff293051ffa8170994739f70b154d/patches/react-native-webview%2B11.13.0.patch#L415
     * * */
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

        if (adblockEngines != null && !this.isMainDocumentException) {
          BlockerResult blockerResult;

          boolean matched = false;
          boolean exception = false;
          for (Engine engine : adblockEngines) {
            synchronized (engine) {
              if (request.isForMainFrame()) {
                blockerResult = engine.match(url.toString(), url.getHost(), "", false, "document");
              } else {
                blockerResult = engine.match(url.toString(), url.getHost(), mainUrl.getHost(), false, "");
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
              return new WebResourceResponse("text/plain", "utf-8", new ByteArrayInputStream("".getBytes()));
            }
          }
        }
        RNCWebView reactWebView = (RNCWebView) view;
        if(reactWebView.injectedJSBeforeDocumentLoad == null || reactWebView.injectedJSBeforeDocumentLoad.isEmpty()){
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

        if (!responseRequiresJSInjection(response)) {
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
          String charsetHtml = HtmlExtractor.findHtmlCharsetFromRequest(httpClient, req);
          if (charsetHtml != null && !encoding.equalsIgnoreCase(charsetHtml)) {
            encoding = charsetHtml;
          }

          // TODO: if httpResponseCharset is null and charsetHtml is null, I can't find a way to detect the encoding value so I will use UTF_8 as a default value
        }

        if (response.code() == HttpURLConnection.HTTP_OK) {
          is = new InputStreamWithInjectedJS(is, reactWebView.injectedJSBeforeDocumentLoad, defaultCharset);
        }

        return new WebResourceResponse("text/html", encoding, is);
      } catch (Exception e) {
        e.printStackTrace();
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
      event.putBoolean("loading", !mLastLoadFailed && webView.getProgress() != 100 && mLoadingProgress != 100);
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

    public void setAdditionalUserAgent(ReadableArray additionalUserAgent) {
      if (additionalUserAgent != null) {
        mAdditionalUserAgent = additionalUserAgent;
      } else {
        mAdditionalUserAgent = null;
      }
    }

    public void setUserAgent(String userAgent) {
      mUserAgent = userAgent;
    }

    public void setLoadingProgress(int newProgress) {
      this.mLoadingProgress = newProgress;
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
    private PermissionRequest permissionRequest;
    private ArrayList<String> grantedPermissions;

    // Webview geolocation permission callback
    protected GeolocationPermissions.Callback geolocationPermissionCallback;
    // Webview geolocation permission origin callback
    protected String geolocationPermissionOrigin;

    private final ArrayList<String> pendingPermissions = new ArrayList<>();
    private boolean permissionsRequestShown = false;
    protected boolean allowsProtectedMedia = true;
    @Override
    public void onPermissionRequest(final PermissionRequest request) {
      grantedPermissions = new ArrayList<>();

      ArrayList<String> requestedAndroidPermissions = new ArrayList<>();
      for (String requestedResource : request.getResources()) {
        String androidPermission = null;

        if (requestedResource.equals(PermissionRequest.RESOURCE_AUDIO_CAPTURE)) {
          // need define permission android.permission.RECORD_AUDIO and android.permission.MODIFY_AUDIO_SETTINGS in Manifest.xml
          androidPermission = Manifest.permission.RECORD_AUDIO;
        } else if (requestedResource.equals(PermissionRequest.RESOURCE_VIDEO_CAPTURE)) {
          // need define permission android.permission.CAMERA in Manifest.xml
          androidPermission = Manifest.permission.CAMERA;
        } else if(requestedResource.equals(PermissionRequest.RESOURCE_PROTECTED_MEDIA_ID)) {
          if (allowsProtectedMedia) {
            grantedPermissions.add(requestedResource);
          } else {
            /**
             * Legacy handling (Kept in case it was working under some conditions (given Android version or something))
             *
             * Try to ask user to grant permission using Activity.requestPermissions
             *
             * Find more details here: https://github.com/react-native-webview/react-native-webview/pull/2732
             */
            androidPermission = PermissionRequest.RESOURCE_PROTECTED_MEDIA_ID;
          }
        } else {
          androidPermission = requestedResource;
        }
        // TODO: RESOURCE_MIDI_SYSEX, RESOURCE_PROTECTED_MEDIA_ID.
        if (androidPermission != null) {
          if (ContextCompat.checkSelfPermission(this.mWebView.getContext(), androidPermission) == PackageManager.PERMISSION_GRANTED) {
            grantedPermissions.add(requestedResource);
          } else {
            requestedAndroidPermissions.add(androidPermission);
          }
        }
      }

      // If all the permissions are already granted, send the response to the WebView synchronously
      if (requestedAndroidPermissions.isEmpty()) {
        request.grant(grantedPermissions.toArray(new String[0]));
        grantedPermissions = null;
        return;
      }

      // Otherwise, ask to Android System for native permissions asynchronously
      this.permissionRequest = request;
      requestPermissions(requestedAndroidPermissions);
    }

    private PermissionAwareActivity getPermissionAwareActivity() {
      Activity activity = this.mReactContext.getCurrentActivity();
      if (!(activity instanceof PermissionAwareActivity)) {
        return null;
      }
      return (PermissionAwareActivity) activity;
    }

    private synchronized void requestPermissions(List<String> permissions) {
      /*
       * If permissions request dialog is displayed on the screen and another request is sent to the
       * activity, the last permission asked is skipped. As a work-around, we use pendingPermissions
       * to store next required permissions.
       */
      if (permissionsRequestShown) {
        pendingPermissions.addAll(permissions);
        return;
      }

      PermissionAwareActivity activity = getPermissionAwareActivity();
      if (activity != null) {
        permissionsRequestShown = true;
        activity.requestPermissions(
          permissions.toArray(new String[0]),
          3,
          webviewPermissionsListener
        );
        // Pending permissions have been sent, the list can be cleared
        pendingPermissions.clear();
      }
    }

    private final PermissionListener webviewPermissionsListener = (requestCode, permissions, grantResults) -> {
      permissionsRequestShown = false;

      /*
       * As a "pending requests" approach is used, requestCode cannot help to define if the request
       * came from geolocation or camera/audio. This is why shouldAnswerToPermissionRequest is used
       */
      boolean shouldAnswerToPermissionRequest = false;

      for (int i = 0; i < permissions.length; i++) {
        String permission = permissions[i];
        boolean granted = grantResults[i] == PackageManager.PERMISSION_GRANTED;

        if (permission.equals(Manifest.permission.ACCESS_FINE_LOCATION)
          && geolocationPermissionCallback != null
          && geolocationPermissionOrigin != null) {

          if (granted) {
            geolocationPermissionCallback.invoke(geolocationPermissionOrigin, true, false);
          } else {
            geolocationPermissionCallback.invoke(geolocationPermissionOrigin, false, false);
          }

          geolocationPermissionCallback = null;
          geolocationPermissionOrigin = null;
        }

        if (permission.equals(Manifest.permission.RECORD_AUDIO)) {
          if (granted && grantedPermissions != null) {
            grantedPermissions.add(PermissionRequest.RESOURCE_AUDIO_CAPTURE);
          }
          shouldAnswerToPermissionRequest = true;
        }

        if (permission.equals(Manifest.permission.CAMERA)) {
          if (granted && grantedPermissions != null) {
            grantedPermissions.add(PermissionRequest.RESOURCE_VIDEO_CAPTURE);
          }
          shouldAnswerToPermissionRequest = true;
        }

        if (permission.equals(PermissionRequest.RESOURCE_PROTECTED_MEDIA_ID)) {
          if (granted && grantedPermissions != null) {
            grantedPermissions.add(PermissionRequest.RESOURCE_PROTECTED_MEDIA_ID);
          }
          shouldAnswerToPermissionRequest = true;
        }
      }

      if (shouldAnswerToPermissionRequest
        && permissionRequest != null
        && grantedPermissions != null) {
        permissionRequest.grant(grantedPermissions.toArray(new String[0]));
        permissionRequest = null;
        grantedPermissions = null;
      }

      if (!pendingPermissions.isEmpty()) {
        requestPermissions(pendingPermissions);
        return false;
      }

      return true;
    };

    @Override
    public void onProgressChanged(WebView webView, int newProgress) {
      super.onProgressChanged(webView, newProgress);
      final String url = webView.getUrl();

      RNCWebView rncWebView = (RNCWebView) webView;
      if (rncWebView.getRNCWebViewClient() != null) {
        rncWebView.getRNCWebViewClient().setLoadingProgress(newProgress);
      }

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

      if (ContextCompat.checkSelfPermission(mReactContext, Manifest.permission.ACCESS_FINE_LOCATION)
        != PackageManager.PERMISSION_GRANTED) {

        /*
         * Keep the trace of callback and origin for the async permission request
         */
        geolocationPermissionCallback = callback;
        geolocationPermissionOrigin = origin;

        requestPermissions(Collections.singletonList(Manifest.permission.ACCESS_FINE_LOCATION));

      } else {
        callback.invoke(origin, true, false);
      }
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

    // similar createRNCWebViewInstance method in RNCWebViewManager
    protected RNCWebView createNewWindow(ThemedReactContext reactContext) {
      RNCWebView newView = RNCWebView.createNewWindow(reactContext);
      newView.addJavascriptInterface(newView.createRNCNativeWebViewBridge(newView), NATIVE_SCRIPT_INTERFACE);
      newView.addJavascriptInterface(newView.createRNCWebViewBridge(newView), FAVICON_INTERFACE);
      return newView;
    }

    @Override
    public boolean onCreateWindow(final WebView webView, boolean isDialog, boolean isUserGesture, Message resultMsg) {
      // Create a new view
      RNCWebView newView = this.createNewWindow((ThemedReactContext) mReactContext);
      RNCWebViewClient newWebViewClient = new RNCWebViewClient((ThemedReactContext) mReactContext) {
        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
          /*
          * In some case like Figma page, when click hyperlink have target="_blank"
          * url="about:blank" will be load first, need process it to get real url in next time onPageStarted called
          * */
          if (url.equals(BLANK_URL)) {
            super.onPageStarted(view, url, favicon);
            return;
          }

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
      };
      RNCWebView currentWebView = (RNCWebView) webView;
      if (currentWebView.mRNCWebViewClient != null) {
        newWebViewClient.mEnableNightMode = currentWebView.mRNCWebViewClient.mEnableNightMode;
      }

      newView.setWebViewClient(newWebViewClient);

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
    protected boolean nestedScrollEnabled = false;
    private static RNCWebView newWindow;
    private String DOWNLOAD_FOLDER = "";

    /**
     * WebView must be created with an context of the current activity
     * <p>
     * Activity Context is required for creation of dialogs internally by WebView
     * Reactive Native needed for access to ReactNative internal system functionality
     */

    public static RNCWebView createNewInstance(ThemedReactContext reactContext) {
      RNCWebView webView = null;
      /**
       * Hello Maintainer! 
       * If you are here, you might be wondering why we are using a static variable to store the new window. 
       * Because we should keep the new window instance alive until the new window is added to the parent view. 
       * Some URL's only can use one time, if we create a new window and add it to the parent view, we can't use the URL again.
       * For example: If we open a new window with the URL "https://accounts.google.com/..." to authenticate account, we can't use that URL again (It will be shown an blank page).
       */
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
      setMessagingEnabled(parentView.messagingEnabled);
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

    public void setNestedScrollEnabled(boolean nestedScrollEnabled) {
      this.nestedScrollEnabled = nestedScrollEnabled;
    }

    public void setDownloadFolder(String downloadFolder) {
      this.DOWNLOAD_FOLDER = downloadFolder;
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
    public boolean onTouchEvent(MotionEvent event) {
      if (this.nestedScrollEnabled) {
        requestDisallowInterceptTouchEvent(true);
      }
      return super.onTouchEvent(event);
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

    protected RNCNativeWebviewBridge createRNCNativeWebViewBridge(RNCWebView webView) {
      return new RNCNativeWebviewBridge(webView);
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
    public String loadSearchWebviewFile() {
      String jsString = null;
      try {
        InputStream fileInputStream;
        fileInputStream = this.getContext().getAssets().open("SearchWebView.js");
        byte[] readBytes = new byte[fileInputStream.available()];
        fileInputStream.read(readBytes);
        jsString = new String(readBytes);
      } catch (FileNotFoundException e) {
        e.printStackTrace();
      } catch (IOException e) {
        e.printStackTrace();
      }
      return jsString;
    }

    public String loadYouTubeAdblockFile() {
      String jsString = null;
      try {
        InputStream fileInputStream;
        fileInputStream = this.getContext().getAssets().open("youtubeAdblock.js");
        byte[] readBytes = new byte[fileInputStream.available()];
        fileInputStream.read(readBytes);
        jsString = new String(readBytes);
      } catch (FileNotFoundException e) {
        e.printStackTrace();
      } catch (IOException e) {
        e.printStackTrace();
      }
      return jsString;
    }

    public String loadNightModeScriptFile() {
      String jsString = null;
      try {
        InputStream fileInputStream;
        fileInputStream = this.getContext().getAssets().open("NightModeScript.js");
        byte[] readBytes = new byte[fileInputStream.available()];
        fileInputStream.read(readBytes);
        jsString = new String(readBytes);
      } catch (FileNotFoundException e) {
        e.printStackTrace();
      } catch (IOException e) {
        e.printStackTrace();
      }
      return jsString;
    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    @SuppressWarnings("deprecation")
    public void printContent() {
      PrintManager printManager = (PrintManager) this.getContext().getSystemService(Context.PRINT_SERVICE);

      String jobName = "Print Document";
      
      PrintDocumentAdapter printAdapter;
      if (android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        printAdapter = this.createPrintDocumentAdapter(jobName);
      } else {
        printAdapter = this.createPrintDocumentAdapter();
      }

      printManager.print(jobName, printAdapter, new PrintAttributes.Builder().build());
    }

    public void requestWebViewStatus() {
      if (mRNCWebViewClient != null) {
        WritableMap eventData = mRNCWebViewClient.createWebViewEvent(this, this.getUrl());
        dispatchEvent(
          this,
          new TopRequestWebViewStatusEvent(
            this.getId(),
            eventData));
      }
    }

    public void callInjectedJavaScript(boolean enableYoutubeAdblocker) {
      if(getSettings().getJavaScriptEnabled()){
        String jsNightMode = loadNightModeScriptFile();
        if(jsNightMode != null) this.evaluateJavascriptWithFallback(jsNightMode);

        String jsSearch = loadSearchWebviewFile();
        if(jsSearch != null) this.evaluateJavascriptWithFallback(jsSearch);

        if(enableYoutubeAdblocker) {
          String youtubeAdblockJs = loadYouTubeAdblockFile();
          if (youtubeAdblockJs != null) this.evaluateJavascriptWithFallback(youtubeAdblockJs);
        }
      }

      if (getSettings().getJavaScriptEnabled() &&
        injectedJS != null &&
        !TextUtils.isEmpty(injectedJS)) {
        evaluateJavascriptWithFallback("(function() {\n" + injectedJS + ";\n})();");
      }
    }

    public void callInjectedJavaScriptBeforeContentLoaded() {
      if (getSettings().getJavaScriptEnabled() &&
        injectedJSBeforeDocumentLoad != null &&
        !TextUtils.isEmpty(injectedJSBeforeDocumentLoad)) {
        evaluateJavascriptWithFallback("(function() {\n" + injectedJSBeforeDocumentLoad + ";\n})();");
      }
    }

    public void linkWindowObject() {
      // override window.print method to call native function
      this.evaluateJavascriptWithFallback("("+
        "window.print = function () {"+
          "window."+ NATIVE_SCRIPT_INTERFACE + ".print();"
        +"});"
        );
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

    public void onGetFavicon(String favicon) {
      WritableMap eventData = Arguments.createMap();
      eventData.putString("data", favicon);
      dispatchEvent(this, new TopGetFaviconEvent(this.getId(), eventData));
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

      @JavascriptInterface
      public void postFavicon(String favicon) {
        mContext.onGetFavicon(favicon);
      }
    }

    public class RNCNativeWebviewBridge {
      RNCWebView mContext;

      RNCNativeWebviewBridge(RNCWebView c) {
        mContext = c;
      }

      @JavascriptInterface
      public void print() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
          mContext.post(new Runnable() {
            @Override
            public void run() {
              mContext.printContent();
            }
          });
        }
      }

      @JavascriptInterface
      public void sendPartialBase64Data(String base64Data) {
        RNCWebViewModule module = getModule((ReactContext) mContext.getContext());
        module.sendPartialBase64Data(base64Data);
      }

      @JavascriptInterface
      public void notifyConvertBlobToBase64Completed() {
        RNCWebViewModule module = getModule((ReactContext) mContext.getContext());
        if (module.grantFileDownloaderPermissions()) {
          module.saveBase64DataToFile();
        }
      }
    }

    public void captureScreen(String type) {
      final String fileName = System.currentTimeMillis() + ".jpg";
      // Old logic: save internal storage
      // String directory = type.equals("SCREEN_SHOT") ? TEMP_DIRECTORY : DOWNLOAD_DIRECTORY;

      File saveDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
      if (DOWNLOAD_FOLDER != null && !DOWNLOAD_FOLDER.isEmpty()) {
        saveDir = new File(saveDir, DOWNLOAD_FOLDER);
        if (!saveDir.exists()) {
          saveDir.mkdirs();
        }
      }
      File downloadPath = new File(saveDir, fileName);
      boolean success = false;
      try {
        Picture picture = this.capturePicture();
        int width = type.equals("CAPTURE_SCREEN") ? this.getWidth() : picture.getWidth();
        int height = type.equals("CAPTURE_SCREEN") ? this.getHeight() : picture.getHeight();
        Bitmap b = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        picture.draw(c);

        FileOutputStream fos = new FileOutputStream(downloadPath, false);
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
          event.putString("data", downloadPath.getAbsolutePath());
        }
        dispatchEvent(this, new TopCaptureScreenEvent(this.getId(), event));
      }
    }

    public void getFaviconUrl() {
      this.loadUrl("javascript:getFavicons()");
    }

    public void searchInPage(String keyword) {
      String jsSearch = "MyApp_HighlightAllOccurencesOfString('" + keyword + "');";
      this.loadUrl("javascript:" + jsSearch);
    }
    
    public void searchNext() {
      this.loadUrl("javascript:myAppSearchNextInThePage()");
    }

    public void searchPrevious() {
      this.loadUrl("javascript:myAppSearchPreviousInThePage()");
    }

    public void removeAllHighlights() {
      this.loadUrl("javascript:myAppSearchDoneInThePage()");
    }

    public void setFontSize(Number size) {
      WebView webView = this;
      webView.getSettings().setTextZoom((int) size);
    }

    public void setEnableNightMode(String enable) {
      if (mRNCWebViewClient != null) {
        mRNCWebViewClient.mEnableNightMode = Boolean.parseBoolean(enable);
      }
      String jsNightMode = "window.NightMode.setEnabled(" + enable + ");";
      this.loadUrl("javascript:" + jsNightMode);
    }
  }
}
