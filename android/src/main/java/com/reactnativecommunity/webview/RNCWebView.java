package com.reactnativecommunity.webview;

import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Picture;
import android.graphics.Rect;
import android.os.Environment;
import android.text.TextUtils;
import android.util.Log;
import android.view.ActionMode;
import android.view.Menu;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.annotation.Nullable;

import com.facebook.common.logging.FLog;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.CatalystInstance;
import com.facebook.react.bridge.JavaScriptModule;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.UIManagerHelper;
import com.facebook.react.uimanager.events.ContentSizeChangeEvent;
import com.facebook.react.uimanager.events.Event;
import com.facebook.react.views.scroll.OnScrollDispatchHelper;
import com.facebook.react.views.scroll.ScrollEvent;
import com.facebook.react.views.scroll.ScrollEventType;
import com.reactnativecommunity.webview.events.TopCaptureScreenEvent;
import com.reactnativecommunity.webview.events.TopCustomMenuSelectionEvent;
import com.reactnativecommunity.webview.events.TopGetFaviconEvent;
import com.reactnativecommunity.webview.events.TopMessageEvent;
import com.reactnativecommunity.webview.lunascape.RNCNativeWebViewBridge;
import com.reactnativecommunity.webview.events.TopRequestWebViewStatusEvent;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.Map;

public class RNCWebView extends WebView implements LifecycleEventListener {
    protected @Nullable
    String injectedJS;
    protected @Nullable
    String injectedJSBeforeContentLoaded;
    protected static final String JAVASCRIPT_INTERFACE = "ReactNativeWebView";
    protected @Nullable
    RNCWebViewBridge bridge;

    /**
     * android.webkit.WebChromeClient fundamentally does not support JS injection into frames other
     * than the main frame, so these two properties are mostly here just for parity with iOS & macOS.
     */
    protected boolean injectedJavaScriptForMainFrameOnly = true;
    protected boolean injectedJavaScriptBeforeContentLoadedForMainFrameOnly = true;

    protected boolean messagingEnabled = false;
    protected @Nullable
    String messagingModuleName;
    protected @Nullable
    RNCWebViewMessagingModule mMessagingJSModule;
    protected @Nullable
    RNCWebViewClient mRNCWebViewClient;
    protected boolean sendContentSizeChangeEvents = false;
    private OnScrollDispatchHelper mOnScrollDispatchHelper;
    protected boolean hasScrollEvent = false;
    protected boolean nestedScrollEnabled = false;
    protected ProgressChangedFilter progressChangedFilter;

    /**
     * WebView must be created with an context of the current activity
     * <p>
     * Activity Context is required for creation of dialogs internally by WebView
     * Reactive Native needed for access to ReactNative internal system functionality
     */
    public RNCWebView(ThemedReactContext reactContext) {
        super(reactContext);
        mMessagingJSModule = ((ThemedReactContext) this.getContext()).getReactApplicationContext().getJSModule(RNCWebViewMessagingModule.class);
        progressChangedFilter = new ProgressChangedFilter();
    }

    public void setIgnoreErrFailedForThisURL(String url) {
        mRNCWebViewClient.setIgnoreErrFailedForThisURL(url);
    }

    public void setBasicAuthCredential(RNCBasicAuthCredential credential) {
        mRNCWebViewClient.setBasicAuthCredential(credential);
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
    public boolean onTouchEvent(MotionEvent event) {
        if (this.nestedScrollEnabled) {
            requestDisallowInterceptTouchEvent(true);
        }
        return super.onTouchEvent(event);
    }

    @Override
    protected void onSizeChanged(int w, int h, int ow, int oh) {
        super.onSizeChanged(w, h, ow, oh);

        if (sendContentSizeChangeEvents) {
            dispatchEvent(
                    this,
                    new ContentSizeChangeEvent(
                            RNCWebViewWrapper.getReactTagFromWebView(this),
                            w,
                            h
                    )
            );
        }
    }

    protected @Nullable
    List<Map<String, String>> menuCustomItems;

    public void setMenuCustomItems(List<Map<String, String>> menuCustomItems) {
      this.menuCustomItems = menuCustomItems;
    }

    @Override
    public ActionMode startActionMode(ActionMode.Callback callback, int type) {
      if(menuCustomItems == null ){
        return super.startActionMode(callback, type);
      }

      return super.startActionMode(new ActionMode.Callback2() {
        @Override
        public boolean onCreateActionMode(ActionMode mode, Menu menu) {
          for (int i = 0; i < menuCustomItems.size(); i++) {
            menu.add(Menu.NONE, i, i, (menuCustomItems.get(i)).get("label"));
          }
          return true;
        }

        @Override
        public boolean onPrepareActionMode(ActionMode actionMode, Menu menu) {
          return false;
        }

        @Override
        public boolean onActionItemClicked(ActionMode mode, MenuItem item) {
          WritableMap wMap = Arguments.createMap();
          RNCWebView.this.evaluateJavascript(
            "(function(){return {selection: window.getSelection().toString()} })()",
            new ValueCallback<String>() {
              @Override
              public void onReceiveValue(String selectionJson) {
                Map<String, String> menuItemMap = menuCustomItems.get(item.getItemId());
                wMap.putString("label", menuItemMap.get("label"));
                wMap.putString("key", menuItemMap.get("key"));
                String selectionText = "";
                try {
                  selectionText = new JSONObject(selectionJson).getString("selection");
                } catch (JSONException ignored) {}
                wMap.putString("selectedText", selectionText);
                dispatchEvent(RNCWebView.this, new TopCustomMenuSelectionEvent(RNCWebViewWrapper.getReactTagFromWebView(RNCWebView.this), wMap));
                mode.finish();
              }
            }
          );
          return true;
        }

        @Override
        public void onDestroyActionMode(ActionMode mode) {
          mode = null;
        }

        @Override
        public void onGetContentRect (ActionMode mode,
                View view,
                Rect outRect){
            if (callback instanceof ActionMode.Callback2) {
                ((ActionMode.Callback2) callback).onGetContentRect(mode, view, outRect);
            } else {
                super.onGetContentRect(mode, view, outRect);
            }
          }
      }, type);
    }

    @Override
    public void setWebViewClient(WebViewClient client) {
        super.setWebViewClient(client);
        if (client instanceof RNCWebViewClient) {
            mRNCWebViewClient = (RNCWebViewClient) client;
            mRNCWebViewClient.setProgressChangedFilter(progressChangedFilter);
        }
    }

    WebChromeClient mWebChromeClient;
    @Override
    public void setWebChromeClient(WebChromeClient client) {
        this.mWebChromeClient = client;
        super.setWebChromeClient(client);
        if (client instanceof RNCWebChromeClient) {
            ((RNCWebChromeClient) client).setProgressChangedFilter(progressChangedFilter);
        }
    }

    public WebChromeClient getWebChromeClient() {
        return this.mWebChromeClient;
    }

    public @Nullable
    RNCWebViewClient getRNCWebViewClient() {
        return mRNCWebViewClient;
    }

    public boolean getMessagingEnabled() {
        return this.messagingEnabled;
    }

    protected RNCWebViewBridge createRNCWebViewBridge(RNCWebView webView) {
        if (bridge == null) {
            bridge = new RNCWebViewBridge(webView);
            addJavascriptInterface(bridge, JAVASCRIPT_INTERFACE);
        }
        return bridge;
    }

    @SuppressLint("AddJavascriptInterface")
    public void setMessagingEnabled(boolean enabled) {
        if (messagingEnabled == enabled) {
            return;
        }

        messagingEnabled = enabled;

        if (enabled) {
            createRNCWebViewBridge(this);
        }
    }

    protected void evaluateJavascriptWithFallback(String script) {
        evaluateJavascript(script, null);
    }

    public void callInjectedJavaScript(boolean enableYoutubeAdblocker) {
        // TODO task @2ad9976 add findNext, findPrevious, removeAllHighlights functions
        if(getSettings().getJavaScriptEnabled()){
  //            String jsNightMode = loadNightModeScriptFile();
  //            if(jsNightMode != null) this.evaluateJavascriptWithFallback(jsNightMode);

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
                injectedJSBeforeContentLoaded != null &&
                !TextUtils.isEmpty(injectedJSBeforeContentLoaded)) {
            evaluateJavascriptWithFallback("(function() {\n" + injectedJSBeforeContentLoaded + ";\n})();");
        }
    }

    public void setInjectedJavaScriptObject(String obj) {
        if (getSettings().getJavaScriptEnabled()) {
            RNCWebViewBridge b = createRNCWebViewBridge(this);
            b.setInjectedObjectJson(obj);
        }
    }

    public void onMessage(String message) {
        ThemedReactContext reactContext = getThemedReactContext();
        RNCWebView mWebView = this;

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

                    if (mMessagingJSModule != null) {
                        dispatchDirectMessage(data);
                    } else {
                        dispatchEvent(webView, new TopMessageEvent(RNCWebViewWrapper.getReactTagFromWebView(webView), data));
                    }
                }
            });
        } else {
            WritableMap eventData = Arguments.createMap();
            eventData.putString("data", message);

            if (mMessagingJSModule != null) {
                dispatchDirectMessage(eventData);
            } else {
                dispatchEvent(this, new TopMessageEvent(RNCWebViewWrapper.getReactTagFromWebView(this), eventData));
            }
        }
    }

    protected void dispatchDirectMessage(WritableMap data) {
        WritableNativeMap event = new WritableNativeMap();
        event.putMap("nativeEvent", data);
        event.putString("messagingModuleName", messagingModuleName);

        mMessagingJSModule.onMessage(event);
    }

    protected boolean dispatchDirectShouldStartLoadWithRequest(WritableMap data) {
        WritableNativeMap event = new WritableNativeMap();
        event.putMap("nativeEvent", data);
        event.putString("messagingModuleName", messagingModuleName);

        mMessagingJSModule.onShouldStartLoadWithRequest(event);
        return true;
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
                    RNCWebViewWrapper.getReactTagFromWebView(this),
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

    protected void dispatchEvent(WebView webView, Event event) {
        ThemedReactContext reactContext = getThemedReactContext();
        int reactTag = RNCWebViewWrapper.getReactTagFromWebView(webView);
        UIManagerHelper.getEventDispatcherForReactTag(reactContext, reactTag).dispatchEvent(event);
    }

    protected void cleanupCallbacksAndDestroy() {
        setWebViewClient(null);
        destroy();
    }

    @Override
    public void destroy() {
        if (mWebChromeClient != null) {
            mWebChromeClient.onHideCustomView();
        }
        super.destroy();
    }

  public ThemedReactContext getThemedReactContext() {
    return (ThemedReactContext) this.getContext();
  }

  public ReactApplicationContext getReactApplicationContext() {
      return this.getThemedReactContext().getReactApplicationContext();
  }

  protected class RNCWebViewBridge {
        private String TAG = "RNCWebViewBridge";
        RNCWebView mWebView;
        String injectedObjectJson;

        RNCWebViewBridge(RNCWebView c) {
          mWebView = c;
        }

        public void setInjectedObjectJson(String s) {
            injectedObjectJson = s;
        }

        /**
         * This method is called whenever JavaScript running within the web view calls:
         * - window[JAVASCRIPT_INTERFACE].postMessage
         */
        @JavascriptInterface
        public void postMessage(String message) {
            if (mWebView.getMessagingEnabled()) {
                mWebView.onMessage(message);
            } else {
                FLog.w(TAG, "ReactNativeWebView.postMessage method was called but messaging is disabled. Pass an onMessage handler to the WebView.");
            }
        }

        @JavascriptInterface
        public String injectedObjectJson() { return injectedObjectJson; }

        @JavascriptInterface
        public void postFavicon(String favicon) {
            mWebView.onGetFavicon(favicon);
        }
    }


    protected static class ProgressChangedFilter {
        private boolean waitingForCommandLoadUrl = false;

        public void setWaitingForCommandLoadUrl(boolean isWaiting) {
            waitingForCommandLoadUrl = isWaiting;
        }

        public boolean isWaitingForCommandLoadUrl() {
            return waitingForCommandLoadUrl;
        }
    }

    /**
     * Lunascape logic
     * */
    public static final String BLANK_URL = "about:blank";
    public static final String FAVICON_INTERFACE = "FaviconWebView";
    public static final String NATIVE_SCRIPT_INTERFACE = "nativeScriptHandler";

    protected String activeUrl;
    private static RNCWebView newWindow;
    public static final String DOWNLOAD_DIRECTORY = Environment.getExternalStorageDirectory() + "/Android/data/jp.co.lunascape.android.ilunascape/downloads/";
    public static final String TEMP_DIRECTORY = Environment.getExternalStorageDirectory() + "/Android/data/jp.co.lunascape.android.ilunascape/temps/";

    public static RNCWebView createNewInstance(ThemedReactContext reactContext) {
        RNCWebView webView;
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
                e.printStackTrace();
                // Log.e("RNCWebView", "createNewInstance error: " + e.getLocalizedMessage());
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

    protected RNCNativeWebViewBridge createRNCNativeWebViewBridge(RNCWebView webView) {
        return new RNCNativeWebViewBridge(webView);
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

        if (mRNCWebViewClient != null && parentView.mRNCWebViewClient != null) {
            mRNCWebViewClient.cloneAdblockRules(parentView.mRNCWebViewClient);
        }
        injectedJS = parentView.injectedJS;
        injectedJSBeforeContentLoaded = parentView.injectedJSBeforeContentLoaded;
        setMessagingEnabled(parentView.messagingEnabled);
        sendContentSizeChangeEvents = parentView.sendContentSizeChangeEvents;
    }

    public void requestWebViewStatus() {
      if (mRNCWebViewClient != null) {
        WritableMap eventData = mRNCWebViewClient.createWebViewEvent(this, this.getUrl());
        dispatchEvent(RNCWebView.this, new TopRequestWebViewStatusEvent(RNCWebViewWrapper.getReactTagFromWebView(RNCWebView.this), eventData));
      }
    }

    public void getFaviconUrl() {
        this.loadUrl("javascript:getFavicons()");
    }

    public void onGetFavicon(String favicon) {
        WritableMap eventData = Arguments.createMap();
        eventData.putString("data", favicon);
        dispatchEvent(RNCWebView.this, new TopGetFaviconEvent(RNCWebViewWrapper.getReactTagFromWebView(RNCWebView.this), eventData));
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

    public void captureScreen(String type) {
        final String fileName = System.currentTimeMillis() + ".jpg";
        // Old logic: save internal storage
        String directory = type.equals("SCREEN_SHOT") ? TEMP_DIRECTORY : DOWNLOAD_DIRECTORY;
        File d = new File(directory);
        if (!d.exists()) {
            d.mkdirs();
        }
        File downloadPath = new File(directory, fileName);

      // New logic waiting done download
  //    File saveDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
  //    if (DOWNLOAD_FOLDER != null && !DOWNLOAD_FOLDER.isEmpty()) {
  //      saveDir = new File(saveDir, DOWNLOAD_FOLDER);
  //      if (!saveDir.exists()) {
  //        saveDir.mkdirs();
  //      }
  //    }
  //    File downloadPath = new File(saveDir, fileName);

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
            dispatchEvent(RNCWebView.this, new TopCaptureScreenEvent(RNCWebViewWrapper.getReactTagFromWebView(RNCWebView.this), event));
        }
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
}
