package com.reactnativecommunity.webview.lunascape

import android.webkit.CookieManager
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl

internal class RNCWebViewCookieJar : CookieJar {

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        val urlString = url.toString()
        for (cookie in cookies) {
            CookieManager.getInstance().setCookie(urlString, cookie.toString())
        }
    }

    override fun loadForRequest(url: HttpUrl): MutableList<Cookie> {
        val cookie = CookieManager.getInstance().getCookie(url.toString())
        if (cookie.isNullOrBlank()) {
            return mutableListOf()
        }

        val headers = cookie.split(";")
          .toTypedArray()
        val cookies = mutableListOf<Cookie>()
        for (header in headers) {
          val item = Cookie.parse(url, header)
          item?.let {
            cookies.add(it)
          }
        }
        return cookies
    }
}