package com.reactnativecommunity.webview.downloaddatabase;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import com.reactnativecommunity.webview.downloaddatabase.DownloadRequestContract.DownloadRequestEntry;

import java.util.ArrayList;

public class DownloadRequestDBHelper extends SQLiteOpenHelper {
  public static final int DATABASE_VERSION = 1;
  public static final String DATABASE_NAME = "DownloadRequest.db";

  private static final String SQL_CREATE_ENTRIES =
    "CREATE TABLE " + DownloadRequestEntry.TABLE_NAME + " (" +
      DownloadRequestEntry._ID + " INTEGER PRIMARY KEY," +
      DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " INTEGER," +
      DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL + " TEXT," +
      DownloadRequestEntry.COLUMN_NAME_USER_AGENT + " TEXT," +
      DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION + " TEXT," +
      DownloadRequestEntry.COLUMN_NAME_MIME_TYPE + " TEXT," +
      DownloadRequestEntry.COLUMN_NAME_COOKIE + " TEXT," +
      DownloadRequestEntry.COLUMN_NAME_STATUS + " INTEGER)";

  private static final String SQL_DELETE_ENTRIES =
    "DROP TABLE IF EXISTS " + DownloadRequestEntry.TABLE_NAME;

  public DownloadRequestDBHelper(Context context) {
    super(context, DATABASE_NAME, null, DATABASE_VERSION);
  }

  @Override
  public void onCreate(SQLiteDatabase db) {
    db.execSQL(SQL_CREATE_ENTRIES);
  }

  @Override
  public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
    // execute upgrade sql
  }

  @Override
  public void onDowngrade(SQLiteDatabase db, int oldVersion, int newVersion) {
    onUpgrade(db, oldVersion, newVersion);
  }

  public void dropTable() {
    SQLiteDatabase db = getWritableDatabase();
    db.execSQL(SQL_DELETE_ENTRIES);
  }

  public long insetDownloadRequest(long downloadRequestId, String url, String userAgent,
                                   String contentDisposition, String mimetype, String cookie) {
    SQLiteDatabase db = getWritableDatabase();

    ContentValues values = new ContentValues();
    values.put(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID, downloadRequestId);
    values.put(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL, url);
    values.put(DownloadRequestEntry.COLUMN_NAME_USER_AGENT, userAgent);
    values.put(DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION, contentDisposition);
    values.put(DownloadRequestEntry.COLUMN_NAME_MIME_TYPE, mimetype);
    values.put(DownloadRequestEntry.COLUMN_NAME_COOKIE, cookie);
    values.put(DownloadRequestEntry.COLUMN_NAME_STATUS, DownloadRequestStatus.NONE.status());

    return db.insert(DownloadRequestEntry.TABLE_NAME, null, values);
  }

  public long updateDownloadRequestStatus(long downloadRequestId, int newStatus) {
    SQLiteDatabase db = getWritableDatabase();

    ContentValues values = new ContentValues();
    values.put(DownloadRequestEntry.COLUMN_NAME_STATUS, newStatus);
    String selection = DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " = ?";
    String[] selectionArgs = { String.valueOf(downloadRequestId) };

    return db.update(
      DownloadRequestEntry.TABLE_NAME,
      values,
      selection,
      selectionArgs
    );
  }

  public long resetDownloadRequestWithNewId(long downloadRequestId, long newDownloadRequestId) {
    SQLiteDatabase db = getWritableDatabase();

    ContentValues values = new ContentValues();
    values.put(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID, newDownloadRequestId);
    values.put(DownloadRequestEntry.COLUMN_NAME_STATUS, DownloadRequestStatus.NONE.status());
    String selection = DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " = ?";
    String[] selectionArgs = { String.valueOf(downloadRequestId) };

    return db.update(
      DownloadRequestEntry.TABLE_NAME,
      values,
      selection,
      selectionArgs
    );
  }

  public int deleteDownloadRequest(long downloadRequestId) {
    SQLiteDatabase db = getWritableDatabase();

    String selection = DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " = ?";
    String[] selectionArgs = { String.valueOf(downloadRequestId) };

    return db.delete(DownloadRequestEntry.TABLE_NAME, selection, selectionArgs);
  }

  public ArrayList<DownloadRequest> getAllDownloadRequestByStatus(int status) {
    SQLiteDatabase db = getReadableDatabase();
    ArrayList<DownloadRequest> downloadRequests = new ArrayList<>();

    String[] projection = {
      DownloadRequestEntry._ID,
      DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID,
      DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL,
      DownloadRequestEntry.COLUMN_NAME_USER_AGENT,
      DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION,
      DownloadRequestEntry.COLUMN_NAME_MIME_TYPE,
      DownloadRequestEntry.COLUMN_NAME_COOKIE,
      DownloadRequestEntry.COLUMN_NAME_STATUS
    };
    String selection = DownloadRequestEntry.COLUMN_NAME_STATUS + " = ?";
    String[] selectionArgs = { String.valueOf(status) };

    String sortOrder = DownloadRequestEntry._ID + " DESC";

    try {
      Cursor cursor = db.query(
        DownloadRequestEntry.TABLE_NAME,
        projection,
        selection,
        selectionArgs,
        null,
        null,
        sortOrder
      );

      if (cursor != null) {
        int idColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry._ID);
        int downloadRequestIdColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID);
        int urlColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL);
        int userAgentColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_USER_AGENT);
        int contentDispositionColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION);
        int mimeTypeColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_MIME_TYPE);
        int cookieColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_COOKIE);
        int statusColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_STATUS);

        while (cursor.moveToNext()) {
          long id = cursor.getLong(idColumn);
          long downloadRequestId = cursor.getLong(downloadRequestIdColumn);
          String url = cursor.getString(urlColumn);
          String userAgent = cursor.getString(userAgentColumn);
          String contentDisposition = cursor.getString(contentDispositionColumn);
          String mimeType = cursor.getString(mimeTypeColumn);
          String cookie = cursor.getString(cookieColumn);
          int requestStatus = cursor.getInt(statusColumn);

          downloadRequests.add(
            new DownloadRequest(id, downloadRequestId, url, userAgent,
              contentDisposition, mimeType, cookie, requestStatus)
          );
        }
        cursor.close();
      }
    } catch (Exception e) {
      e.printStackTrace();
    }

    return downloadRequests;
  }

  public DownloadRequest getDownloadRequestById(long downloadRequestId) {
    SQLiteDatabase db = getReadableDatabase();

    String[] projection = {
      DownloadRequestEntry._ID,
      DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID,
      DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL,
      DownloadRequestEntry.COLUMN_NAME_USER_AGENT,
      DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION,
      DownloadRequestEntry.COLUMN_NAME_MIME_TYPE,
      DownloadRequestEntry.COLUMN_NAME_COOKIE,
      DownloadRequestEntry.COLUMN_NAME_STATUS
    };
    String selection = DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " = ?";
    String[] selectionArgs = { String.valueOf(downloadRequestId) };
    String sortOrder = DownloadRequestEntry._ID + " DESC";

    try {
      Cursor cursor = db.query(
        DownloadRequestEntry.TABLE_NAME,
        projection,
        selection,
        selectionArgs,
        null,
        null,
        sortOrder
      );

      if (cursor != null && cursor.moveToFirst()) {
        int idColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry._ID);
        int urlColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL);
        int userAgentColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_USER_AGENT);
        int contentDispositionColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION);
        int mimeTypeColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_MIME_TYPE);
        int cookieColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_COOKIE);
        int statusColumn =
          cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_STATUS);

        long id = cursor.getLong(idColumn);
        String url = cursor.getString(urlColumn);
        String userAgent = cursor.getString(userAgentColumn);
        String contentDisposition = cursor.getString(contentDispositionColumn);
        String mimeType = cursor.getString(mimeTypeColumn);
        String cookie = cursor.getString(cookieColumn);
        int requestStatus = cursor.getInt(statusColumn);

        cursor.close();

        return new DownloadRequest(id, downloadRequestId, url, userAgent, contentDisposition,
          mimeType, cookie, requestStatus);
      }
    } catch (Exception e) {
      e.printStackTrace();
    }

    return null;
  }
}
