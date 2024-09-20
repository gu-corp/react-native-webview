package com.reactnativecommunity.webview.lunascape

import android.webkit.JavascriptInterface
import com.reactnativecommunity.webview.RNCWebView
import com.reactnativecommunity.webview.RNCWebViewModule

class RNCNativeWebViewBridge(private val mWebView: RNCWebView) {

    @JavascriptInterface
    fun print() {
        mWebView.post {
            mWebView.printContent()
        }
    }

    @JavascriptInterface
    fun sendPartialBase64Data(base64Data: String?) {
        val module: RNCWebViewModule = RNCWebViewModule.getRNCWebViewModule(mWebView.themedReactContext)
        // TODO update logic here
        // module.sendPartialBase64Data(base64Data)
    }

    @JavascriptInterface
    fun notifyConvertBlobToBase64Completed() {
        val module: RNCWebViewModule = RNCWebViewModule.getRNCWebViewModule(mWebView.themedReactContext)
        // TODO update logic here
        /*if (module.grantFileDownloaderPermissions()) {
            module.saveBase64DataToFile()
        }*/
    }
}
