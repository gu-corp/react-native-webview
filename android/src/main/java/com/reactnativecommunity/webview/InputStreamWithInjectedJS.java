package com.reactnativecommunity.webview;

import android.annotation.SuppressLint;
import android.os.Build;
import android.util.Log;

import androidx.annotation.RequiresApi;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.charset.UnsupportedCharsetException;
import java.util.HashMap;
import java.util.Map;

// ref: https://github.com/MetaMask/metamask-mobile/blob/047e3fec96dff293051ffa8170994739f70b154d/patches/react-native-webview%2B11.13.0.patch#L511
@RequiresApi(api = Build.VERSION_CODES.KITKAT)
public class InputStreamWithInjectedJS extends InputStream {
  private InputStream pageIS;
  private InputStream scriptIS;
  private Charset charset;
  private static final String REACT_CLASS = "InputStreamWithInjectedJS";
  private static Map<Charset, String> script = new HashMap<>();

  private boolean hasJS = false;
  private boolean headWasFound = false;
  private boolean scriptWasInjected = false;

  private int lowercaseD = 100;
  private int closingTag = 62;
  private boolean hasClosingHead = false;

  private StringBuffer contentBuffer = new StringBuffer();

  @SuppressLint("LongLogTag")
  private static Charset getCharset(String charsetName) {
    Charset cs = StandardCharsets.UTF_8;
    try {
      if (charsetName != null) {
        cs = Charset.forName(charsetName);
      }
    } catch (UnsupportedCharsetException e) {
      Log.d(REACT_CLASS, "wrong charset: " + charsetName);
    }

    return cs;
  }

  private static InputStream getScript(Charset charset) {
    String js = script.get(charset);
    if (js == null) {
      String defaultJs = script.get(StandardCharsets.UTF_8);
      js = new String(defaultJs.getBytes(StandardCharsets.UTF_8), charset);
      script.put(charset, js);
    }

    return new ByteArrayInputStream(js.getBytes(charset));
  }

  InputStreamWithInjectedJS(InputStream is, String js, Charset charset) {
    if (js == null) {
      this.pageIS = is;
    } else {
      this.hasJS = true;
      this.charset = charset;
      Charset cs = StandardCharsets.UTF_8;
      String jsScript = "<script>" + js + "</script>";
      script.put(cs, jsScript);
      this.pageIS = is;
    }
  }

  @Override
  public int read() throws IOException {
    if (scriptWasInjected || !hasJS) {
      return pageIS.read();
    }

    if (!scriptWasInjected && headWasFound) {
      int nextByte;
      if (!hasClosingHead) {
        nextByte = pageIS.read();
        if (nextByte != closingTag) {
          return nextByte;
        }
        hasClosingHead = true;
        return nextByte;
      }
      nextByte = scriptIS.read();
      if (nextByte == -1) {
        scriptIS.close();
        scriptWasInjected = true;
        return pageIS.read();
      } else {
        return nextByte;
      }
    }

    if (!headWasFound) {
      int nextByte = pageIS.read();
      contentBuffer.append((char) nextByte);
      int bufferLength = contentBuffer.length();
      if (nextByte == lowercaseD && bufferLength >= 5) {
        if (contentBuffer.substring(bufferLength - 5).equals("<head")) {
          this.scriptIS = getScript(this.charset);
          headWasFound = true;
        }
      }

      return nextByte;
    }

    return pageIS.read();
  }

}
