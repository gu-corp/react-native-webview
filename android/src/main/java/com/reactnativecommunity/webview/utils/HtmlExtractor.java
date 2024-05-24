package com.reactnativecommunity.webview.utils;

import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.parser.Parser;
import org.jsoup.select.Elements;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

public class HtmlExtractor {

  // https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta#charset
  // https://www.w3schools.com/charsets/default.asp
  /**
   * Read charset from HTML content
   * @param inputStream
   * @return charset (Ex: UTF-8, ISO-8859-1, windows-1252, ...)
   */
  public static String readCharset(InputStream inputStream) {
    BufferedReader reader = null;
    String charset = null;
    try {
      reader = new BufferedReader(new InputStreamReader(inputStream));
      Document document = Parser.htmlParser().parseInput(reader, "");
      Elements elements = document.head().getElementsByTag("meta");
      int size = elements.size();
      if (size > 0) {
        Element item = null;
        for (int i = 0; i < size; i++) {
          item = elements.get(i);
          boolean isMetaCharset = item.hasAttr("charset");
          // https://www.w3schools.com/charsets/default.asp
          // check HTML5: <meta charset="UTF-8">
          if (isMetaCharset) {
            String valueOfCharset = item.attr("charset");
            charset = valueOfCharset;
            break;
          }
          boolean isMetaContent = item.hasAttr("content");
          boolean hasHttpEquiv = item.hasAttr("http-equiv");
          // check http-equiv="Content-Type". HTML 4: <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
          if (isMetaContent && hasHttpEquiv && item.attr("http-equiv").equalsIgnoreCase("Content-Type")) {
            String valueOfContent = item.attr("content");
            String[] parts = valueOfContent.split(";");
            for (String part : parts) {
              if (part.contains("charset=")) {
                String[] charsetParts = part.split("charset=");
                if (charsetParts.length > 1) {
                  charset = charsetParts[1].trim();
                  break;
                }
              }
            }
            break;
          }
        }
      }
    } catch(Exception ex) {
      ex.printStackTrace();
    } finally {
      try {
        reader.close();
      } catch (IOException e) {
        e.printStackTrace();
      }
    }
    return charset;
  }

  public static String findHtmlCharsetFromRequest(OkHttpClient httpClient, Request request) {
    String charset = null;
    if (httpClient == null || request == null) return null;
    InputStream is = null;
    try {
      Response response = httpClient.newCall(request).execute();
      ResponseBody body = response.body();
      is = body.byteStream();
      charset = HtmlExtractor.readCharset(is);
    } catch (Exception e) {
      e.printStackTrace();
    } finally {
      if (is != null) {
        try {
          is.close();
        } catch (IOException e) {
          e.printStackTrace();
        }
      }
    }
    return charset;
  }
}
