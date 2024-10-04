package com.reactnativecommunity.webview.lunascape.downloaddatabase

import android.provider.BaseColumns

object DownloadRequestContract {
    object DownloadRequestEntry : BaseColumns {
        const val TABLE_NAME = "download_request_tb"
        const val COLUMN_NAME_DOWNLOAD_REQUEST_ID = "download_request_id"
        const val COLUMN_NAME_DOWNLOAD_URL = "download_url"
        const val COLUMN_NAME_USER_AGENT = "user_agent"
        const val COLUMN_NAME_CONTENT_DISPOSITION = "content_disposition"
        const val COLUMN_NAME_MIME_TYPE = "mime_type"
        const val COLUMN_NAME_COOKIE = "cookie"
        const val COLUMN_NAME_STATUS = "status"
    }
}
