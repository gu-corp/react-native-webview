package com.reactnativecommunity.webview.lunascape.downloaddatabase

enum class DownloadRequestStatus(val status: Int) {
    NONE(0),  // downloading or fail or removed
    PAUSED(1);
}
