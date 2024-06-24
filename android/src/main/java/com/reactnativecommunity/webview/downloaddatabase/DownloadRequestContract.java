package com.reactnativecommunity.webview.downloaddatabase;

import android.provider.BaseColumns;

public final class DownloadRequestContract {

  private DownloadRequestContract() {}

  public static class DownloadRequestEntry implements BaseColumns {
    public static final String TABLE_NAME = "download_request_tb";
    public static final String COLUMN_NAME_DOWNLOAD_REQUEST_ID = "download_request_id";
    public static final String COLUMN_NAME_DOWNLOAD_URL = "download_url";
    public static final String COLUMN_NAME_USER_AGENT = "user_agent";
    public static final String COLUMN_NAME_CONTENT_DISPOSITION = "content_disposition";
    public static final String COLUMN_NAME_MIME_TYPE = "mime_type";
    public static final String COLUMN_NAME_COOKIE = "cookie";
    public static final String COLUMN_NAME_STATUS = "status";
  }
}
