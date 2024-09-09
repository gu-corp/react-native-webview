package com.reactnativecommunity.webview.lunascape

import android.util.Log
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.nio.charset.Charset
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.charset.UnsupportedCharsetException
import java.util.*

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
  private var openingHeadFound: Boolean = false
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
      val nextByte: Int = scriptIS?.read() ?: -1
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
      val nextByteStr = nextByte.toChar()
      contentBuffer.append(nextByteStr)
      val bufferLength = contentBuffer.length
      val headString = "<head"
      if (openingHeadFound) {
        if (nextByte == 62) {
          scriptIS = getScript(charset)
          headWasFound = true
        }
      } else {
        val isLetterD = nextByte == 68 || nextByte == 100
        if (isLetterD && bufferLength >= 5) {
          val stringToMatch = contentBuffer.substring(bufferLength - 5).lowercase(Locale.getDefault())
          if (stringToMatch.contains(headString, false)) {
            openingHeadFound = true
          }
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
