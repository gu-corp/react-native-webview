package com.reactnativecommunity.webview

import android.content.Context
import android.graphics.Color
import android.view.View
import android.webkit.WebView
import android.widget.FrameLayout

/**
 * A [FrameLayout] container to hold the [RNCWebView].
 * We need this to prevent WebView crash when the WebView is out of viewport and
 * [com.facebook.react.views.view.ReactViewGroup] clips the canvas.
 * The WebView will then create an empty offscreen surface and NPE.
 */
class RNCWebViewWrapper(context: Context, webView: RNCWebView) : FrameLayout(context) {
  init {
    // We make the WebView as transparent on top of the container,
    // and let React Native sets background color for the container.
    webView.setBackgroundColor(Color.TRANSPARENT)
    addView(webView)
  }

  val webView: RNCWebView = getChildAt(0) as RNCWebView

  /**
   * Drives the W3C Page Visibility API for the page, mirroring the iOS
   * [setPageVisibility] which detaches/attaches the WKWebView.
   *
   * On Android WebView, [View.setVisibility] does NOT update
   * `document.visibilityState`, but detaching the WebView from its window does:
   * [View.onDetachedFromWindow] flips the page to "hidden" and
   * [View.onAttachedToWindow] back to "visible", firing "visibilitychange" each
   * time. Detaching also suspends the renderer.
   *
   * We attach/detach the WebView to/from this wrapper (the library-owned parent),
   * never the React-Native-managed view tree, so RN's view registry stays
   * consistent. The WebView instance is preserved (WebContents is not destroyed),
   * so JS state, scroll and media position survive the detach/re-attach. Because
   * the wrapper holds the WebView via [webView], no back-reference is stored on
   * the child and there is nothing extra to clean up.
   */
  fun setPageVisibility(visible: Boolean) {
    if (visible) {
      if (webView.parent == null) {
        addView(webView)
      }
    } else {
      if (webView.parent != null) {
        removeView(webView)
      }
    }
  }

  companion object {
    /**
     * A helper to get react tag id by given WebView
     */
    @JvmStatic
    fun getReactTagFromWebView(webView: WebView): Int {
      // It is expected that the webView is enclosed by [RNCWebViewWrapper] as the first child.
      // Therefore, it must have a parent, and the parent ID is the reactTag.
      // In exceptional cases, such as receiving WebView messaging after the view has been unmounted,
      // the WebView will not have a parent.
      // In this case, we simply return -1 to indicate that it was not found.
      return (webView.parent as? View)?.id ?: -1
    }
  }
}
