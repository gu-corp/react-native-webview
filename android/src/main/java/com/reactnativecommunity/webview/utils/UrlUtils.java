package com.reactnativecommunity.webview.utils;

import java.net.URL;

public class UrlUtils {
  public static boolean isMatchDomain(String url, String domain) {
    boolean result = false;
    try {
      URL urlObj = new URL(url);
      String host = urlObj.getHost();
      result = domain.equals(host);
    } catch (Exception e) {
      e.printStackTrace();
    }
    return result;
  }
}
