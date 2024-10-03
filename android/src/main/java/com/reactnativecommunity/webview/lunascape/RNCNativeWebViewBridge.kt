package com.reactnativecommunity.webview.lunascape

import android.webkit.JavascriptInterface
import com.reactnativecommunity.webview.RNCWebView
import com.reactnativecommunity.webview.RNCWebViewModule

class RNCNativeWebViewBridge(private val mWebView: RNCWebView) {

    private val DEFAULT_DOWNLOADING_MESSAGE = "Downloading"
    private val DEFAULT_LACK_PERMISSION_TO_DOWNLOAD_MESSAGE =
        "Cannot download files as permission was denied. Please provide permission to write to storage, in order to download files."

    @JavascriptInterface
    fun print() {
        mWebView.post {
            mWebView.printContent()
        }
    }

    @JavascriptInterface
    fun sendPartialBase64Data(base64Data: String?) {
        val module: RNCWebViewModule = RNCWebViewModule.getRNCWebViewModule(mWebView.themedReactContext)
        module.sendPartialBase64Data(base64Data)
    }

    @JavascriptInterface
    fun notifyConvertBlobToBase64Completed() {
        val module: RNCWebViewModule = RNCWebViewModule.getRNCWebViewModule(mWebView.themedReactContext)
        if (module.grantFileDownloaderPermissions(DEFAULT_DOWNLOADING_MESSAGE, DEFAULT_LACK_PERMISSION_TO_DOWNLOAD_MESSAGE)) {
            module.saveBase64DataToFile()
        }
    }
}
