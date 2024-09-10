package com.reactnativecommunity.webview.lunascape

import okhttp3.Response
import java.io.IOException

class LunascapeUtils {
    companion object {
        const val HEADER_CONTENT_TYPE = "content-type"
        const val MIME_UNKNOWN = "application/octet-stream"
        const val HTML_MIME_TYPE = "text/html"
        const val BYTES_IN_MEGABYTE: Long = 1000000

        fun responseRequiresJSInjection(response: Response): Boolean {
            if (response.isRedirect) {
                return false
            }

            val contentTypeAndCharset = response.header(HEADER_CONTENT_TYPE, MIME_UNKNOWN)
            val responseCode = response.code
            val contentTypeIsHtml: Boolean = contentTypeAndCharset?.startsWith(HTML_MIME_TYPE) ?: false
            val responseCodeIsInjectible = responseCode == 200

            if (contentTypeIsHtml && responseCodeIsInjectible && response.body != null) {
                return try {
                    val responseBody = response.peekBody(BYTES_IN_MEGABYTE).string()
                    responseBody.matches("[\\S\\s]*<[a-z]+[\\S\\s]*>[\\S\\s]*".toRegex())
                } catch (e: IOException) {
                    e.printStackTrace()
                    false
                }
            }

            return false
        }
    }
}
