package com.reactnativecommunity.webview.downloaddatabase;

public enum DownloadRequestStatus {
  NONE(0), // downloading or fail or removed
  PAUSED(1); // paused by user, waiting for resume

  private final int status;

  private DownloadRequestStatus(int status) {
    this.status = status;
  }

  public int status() {
    return status;
  }
}
