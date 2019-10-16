package com.reactnativecommunity.webview;

import android.text.TextUtils;
import android.webkit.CookieManager;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import okhttp3.Cookie;
import okhttp3.CookieJar;
import okhttp3.HttpUrl;

class RNCWebViewCookieJar implements CookieJar {
  @Override
  public void saveFromResponse(HttpUrl url, List<Cookie> cookies) {
    String urlString = url.toString();

    for (Cookie cookie : cookies) {
      CookieManager.getInstance().setCookie(urlString, cookie.toString());
    }
  }

  @Override
  public List<Cookie> loadForRequest(HttpUrl url) {
    String cookie = CookieManager.getInstance().getCookie(url.toString());
    if (TextUtils.isEmpty(cookie)) {
      return Collections.emptyList();
    }
    String[] headers = cookie.split(";");
    ArrayList<Cookie> cookies = new ArrayList<>(headers.length);
    for (String header : headers) {
      cookies.add(Cookie.parse(url, header));
    }
    return cookies;
  }
}
