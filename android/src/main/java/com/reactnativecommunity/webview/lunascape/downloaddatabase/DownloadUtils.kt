package com.reactnativecommunity.webview.lunascape.downloaddatabase

class DownloadUtils {
    companion object {
        const val SESSION_ID = "sessionId"
        const val FILE_NAME = "filename"
        const val MIME_TYPE = "mimeType"
        const val TOTAL_BYTES = "totalBytes"
        const val BYTES_DOWNLOADED = "bytesDownloaded"
        const val STATUS = "status"

        fun convertStatusDownloadingFile(status: Int): String {
            return when (status) {
                2 -> "downloading"
                1, 4 -> "pause"
                else -> "fail"
            }
        }
    }
}
