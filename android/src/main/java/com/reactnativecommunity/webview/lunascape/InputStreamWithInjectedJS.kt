package com.reactnativecommunity.webview.lunascape

import android.util.Log
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.nio.charset.Charset
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.charset.UnsupportedCharsetException

// ref: https://github.com/MetaMask/metamask-mobile/blob/047e3fec96dff293051ffa8170994739f70b154d/patches/react-native-webview%2B11.13.0.patch#L511
class InputStreamWithInjectedJS: InputStream {

    companion object {
        private const val TAG = "IStreamWithInjectedJS"
    }

    private var pageIS: InputStream
    private var scriptIS: InputStream? = null
    private val script: MutableMap<Charset, String> = mutableMapOf()
    private var charset: Charset = UTF_8

    private var hasJS: Boolean = false
    private var headWasFound: Boolean = false
    private var scriptWasInjected: Boolean = false
    private var hasClosingHead: Boolean = false

    private val lowercaseD = 100
    private val closingTag = 62

    private val contentBuffer = StringBuffer()

    constructor(inputStream: InputStream, javascript: String?, charset: Charset) {
        if (javascript == null) {
            pageIS = inputStream
        } else {
            hasJS = true
            this.charset = charset
            val cs: Charset = UTF_8
            val jsScript = "<script>$javascript</script>"
            script[cs] = jsScript
            pageIS = inputStream
        }
    }

    override fun read(): Int {
        if (scriptWasInjected || !hasJS) {
            return pageIS.read()
        }

        if (!scriptWasInjected && headWasFound) {
            val nextByte: Int
            if (!hasClosingHead) {
                nextByte = pageIS.read()
                if (nextByte != closingTag) {
                  return nextByte
                }
              hasClosingHead = true
              return nextByte
            }

            nextByte = scriptIS?.read() ?: -1
            return if (nextByte == -1) {
                scriptIS?.close()
                scriptWasInjected = true
                pageIS.read()
            } else {
              nextByte
            }
        }

        if (!headWasFound) {
            val nextByte: Int = pageIS.read()
            contentBuffer.append(nextByte.toChar())
            val bufferLength = contentBuffer.length
            if (nextByte == lowercaseD && bufferLength >= 5) {
                if (contentBuffer.substring(bufferLength - 5) == "<head") {
                    scriptIS = getScript(charset)
                    headWasFound = true
                }
            }
            return nextByte
        }

        return pageIS.read()
    }

    private fun getCharset(charsetName: String?): Charset {
        var charset: Charset = UTF_8
        if (charsetName.isNullOrBlank()) return charset

        try {
            charset = Charset.forName(charsetName)
        } catch (e: UnsupportedCharsetException) {
            e.printStackTrace()
            Log.d(TAG, "wrong charset: $charsetName")
        }
        return charset
    }

    private fun getScript(charset: Charset): InputStream {
        var js = script[charset]
        if (js == null) {
            val defaultJs = script[UTF_8] ?: ""
            js = String(defaultJs.toByteArray(UTF_8), charset)
            script[charset] = js
        }
        return ByteArrayInputStream(js.toByteArray(charset))
    }
}
