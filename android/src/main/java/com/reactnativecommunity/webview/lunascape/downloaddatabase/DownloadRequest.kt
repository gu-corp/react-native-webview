package com.reactnativecommunity.webview.lunascape.downloaddatabase

data class DownloadRequest (
    val id: Long,
    val downloadRequestId: Long,
    val url: String,
    val userAgent: String?,
    val contentDisposition: String?,
    val mimetype: String?,
    val cookie: String?,
    val status: Int,
)
