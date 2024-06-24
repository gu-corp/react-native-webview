package com.reactnativecommunity.webview.downloaddatabase;

public class DownloadRequest {
  private long id;
  private long downloadRequestId;
  private String url;
  private String userAgent;
  private String contentDisposition;
  private String mimetype;
  private String cookie;
  private int status;

  public DownloadRequest(long id, long downloadRequestId, String url, String userAgent,
                         String contentDisposition, String mimetype, String cookie, int status) {
    this.id = id;
    this.downloadRequestId = downloadRequestId;
    this.url = url;
    this.userAgent = userAgent;
    this.contentDisposition = contentDisposition;
    this.mimetype = mimetype;
    this.cookie = cookie;
    this.status = status;
  }

  public long getId() {
    return id;
  }

  public long getDownloadRequestId() {
    return downloadRequestId;
  }

  public String getUrl() {
    return url;
  }

  public String getUserAgent() {
    return userAgent;
  }

  public String getContentDisposition() {
    return contentDisposition;
  }

  public String getMimetype() {
    return mimetype;
  }

  public String getCookie() {
    return cookie;
  }

  public int getStatus() {
    return status;
  }
}
