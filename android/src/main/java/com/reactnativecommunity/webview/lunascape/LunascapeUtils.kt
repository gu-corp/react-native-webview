package com.reactnativecommunity.webview.lunascape

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.webkit.MimeTypeMap
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.reactnativecommunity.webview.R
import okhttp3.Response
import java.io.IOException
import java.io.UnsupportedEncodingException
import java.net.URLDecoder
import java.util.regex.Pattern

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

        fun getBase64Data(base64Data: String): String {
            val parts = base64Data.split(",")

            return if (parts.size > 1) parts[1]
            else base64Data
        }

        fun getFileExtensionFromBase64Data(base64Data: String): String? {
            val parts = base64Data.split(";")
            if (parts.isNotEmpty()) {
                val extensionPart = parts[0].split("/")
                if (extensionPart.size > 1) {
                    return extensionPart[1]
                }
            }

            return null
        }

        fun getMimeTypeFromBase64Data(base64Data: String): String? {
            val parts = base64Data.split(";")
            if (parts.isNotEmpty()) {
                val typePart = parts[0].split(":")
                if (typePart.size > 1) {
                    return typePart[1]
                }
            }

            return null
        }

        fun makeNotificationDownloadedBlobFile(context: Context, fileUri: Uri, mimeType: String?, fileName: String) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) return

            val intent = Intent(Intent.ACTION_VIEW)
            intent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (mimeType != null) {
                intent.setDataAndType(fileUri, mimeType)
            } else {
                intent.data = fileUri
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = "LunascapeChannel"
            val notificationBuilder: NotificationCompat.Builder =
                NotificationCompat.Builder(context, channel)
                    .setAutoCancel(true)
                    .setContentTitle("File downloaded")
                    .setContentText(fileName)
                    .setSmallIcon(R.drawable.ic_download_done_24)
                    .setWhen(System.currentTimeMillis())
                    .setPriority(Notification.PRIORITY_DEFAULT)
                    .setContentIntent(pendingIntent)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationChannel =
                    NotificationChannel(channel, channel, NotificationManager.IMPORTANCE_DEFAULT)
                notificationChannel.description = channel
                notificationChannel.enableLights(true)
                notificationChannel.enableVibration(true)
                notificationChannel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                notificationManager.createNotificationChannel(notificationChannel)
                notificationBuilder.setChannelId(channel)
            }
            notificationManager.notify(1, notificationBuilder.build())
        }

        /** Regex used to parse content-disposition headers  */
        private val CONTENT_DISPOSITION_PATTERN = Pattern.compile(
            "attachment(?:;\\s*filename\\s*=\\s*(\"?)([^\"]*)\\1)?(?:;\\s*filename\\s*\\*\\s*=\\s*([^']*)'[^']*'([^']*))?\\s*$",
            Pattern.CASE_INSENSITIVE
        )

        /**
         * Parse the Content-Disposition HTTP Header. The format of the header
         * is defined here: [RFC 6266](https://www.rfc-editor.org/rfc/rfc6266)
         * This header provides a filename for content that is going to be
         * downloaded to the file system. We only support the attachment type.
         */
        private fun parseContentDisposition(contentDisposition: String?): String? {
            val content = contentDisposition ?: return null
            try {
                // The regex attempts to match the following pattern:
                //     attachment; filename="(Group 2)"; filename*=(Group 3)'(lang)'(Group 4)
                // Group 4 refers to the percent-encoded filename, and the charset
                // is specified in Group 3.
                // Group 2 is the fallback filename.
                // Group 1 refers to the quotation marks around Group 2.
                //
                // Test cases can be found at http://test.greenbytes.de/tech/tc2231/
                // Examples can be found at https://www.rfc-editor.org/rfc/rfc6266#section-5
                // There are a few known limitations:
                // - any Content Disposition value that does not have parameters
                //   arranged in the order of "attachment...filename...filename*"
                //   or contains extra parameters shall fail to be parsed
                // - any filename that contains " shall fail to be parsed
                val m = CONTENT_DISPOSITION_PATTERN.matcher(content)
                if (m.find()) {
                    if (m.group(3) != null && m.group(4) != null) {
                        try {
                            return URLDecoder.decode(m.group(4), m.group(3).ifEmpty { "UTF-8" })
                        } catch (e: UnsupportedEncodingException) {
                            // Skip the ext-parameter as the encoding is unsupported
                        }
                    }
                    return m.group(2)
                }
            } catch (ex: IllegalStateException) {
                // This function is defined as returning null when it can't parse the header
            }
            return null
        }

        fun getDownloadFileName(url: String, contentDisposition: String?, mimeType: String?): String {
            var filename: String? = null
            var extension: String? = null

            // If we couldn't do anything with the hint, move toward the content disposition
            filename = parseContentDisposition(contentDisposition)
            if (filename != null) {
                val index = filename.lastIndexOf('/') + 1
                if (index > 0) {
                    filename = filename.substring(index)
                }
                // Check extension
                val dotIndex = filename.indexOf('.')
                if (dotIndex > 0) {
                    return filename
                }
            }
            // If all the other http-related approaches failed, use the plain uri
            if (filename == null) {
                var decodedUrl = Uri.decode(url)
                if (decodedUrl != null) {
                    val queryIndex = decodedUrl.indexOf('?')
                    // If there is a query string strip it, same as desktop browsers
                    if (queryIndex > 0) {
                        decodedUrl = decodedUrl.substring(0, queryIndex)
                    }
                    if (!decodedUrl.endsWith("/")) {
                        val index = decodedUrl.lastIndexOf('/') + 1
                        if (index > 0) {
                            filename = decodedUrl.substring(index)
                        }
                        if (filename != null) {
                            // Check extension
                            val dotIndex = filename.indexOf('.')
                            if (dotIndex > 0) {
                                return filename
                            }
                        }
                    }
                }
            }

            // Finally, if couldn't get filename from URI, get a generic filename
            if (filename == null) {
                filename = System.currentTimeMillis().toString()
            }

            // Add an extension if filename does not have one
            if (mimeType != null) {
                extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
                if (extension != null) {
                    extension = ".$extension"
                }
            }
            if (extension == null) {
                extension = if (mimeType != null && mimeType.lowercase().startsWith("text/")) {
                    if (mimeType.equals("text/html", ignoreCase = true)) {
                        ".html"
                    } else {
                        ".txt"
                    }
                } else {
                    ".bin"
                }
            }

            return filename + extension
        }
    }
}
