package com.reactnativecommunity.webview.lunascape

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import org.jsoup.parser.Parser
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader


class HtmlExtractor {
    companion object {
        // https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta#charset
        // https://www.w3schools.com/charsets/default.asp
        /**
         * Read charset from HTML content
         * @param inputStream
         * @return charset (Ex: UTF-8, ISO-8859-1, windows-1252, ...)
         * */
        fun readCharset(inputStream: InputStream): String? {
            var charset: String? = null
            try {
                val reader = BufferedReader(InputStreamReader(inputStream))
                val document = Parser.htmlParser().parseInput(reader, "")
                val elements = document.head().getElementsByTag("meta")
                for (item in elements) {
                    val isMetaCharset = item.hasAttr("charset")
                    // https://www.w3schools.com/charsets/default.asp
                    // check HTML5: <meta charset="UTF-8">
                    if (isMetaCharset) {
                        charset = item.attr("charset")
                        break
                    }

                    val isMetaContent = item.hasAttr("content")
                    val hasHttpEquiv = item.hasAttr("http-equiv")
                    // check http-equiv="Content-Type". HTML 4: <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
                    if (isMetaContent && hasHttpEquiv
                      && item.attr("http-equiv").equals("Content-Type", ignoreCase = true)) {
                        val valueOfContent = item.attr("content")
                        val parts = valueOfContent.split(";")
                        for (part in parts) {
                            if (part.contains("charset=")) {
                                val charsetParts = part.split("charset=")
                                if (charsetParts.size > 1) {
                                    charset = charsetParts[1].trim()
                                    break
                                }
                            }
                        }
                        break
                    }
                }
                reader.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }

            return charset
        }

        fun findHtmlCharsetFromRequest(httpClient: OkHttpClient?, request: Request?): String? {
            var charset: String? = null
            if (httpClient == null || request == null) return null

            try {
                val response: Response = httpClient.newCall(request).execute()
                response.body?.let { body ->
                    val inputStream = body.byteStream()
                    charset = readCharset(inputStream)
                    inputStream.close()
                }
                response.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }

            return charset
        }
    }
}
