package com.reactnativecommunity.webview.lunascape.downloaddatabase

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.provider.BaseColumns

import com.reactnativecommunity.webview.lunascape.downloaddatabase.DownloadRequestContract.DownloadRequestEntry

class DownloadRequestDBHelper(context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_VERSION = 1
        const val DATABASE_NAME = "DownloadRequest.db"

        private const val SQL_CREATE_ENTRIES = "CREATE TABLE " + DownloadRequestEntry.TABLE_NAME + " (" +
                BaseColumns._ID + " INTEGER PRIMARY KEY," +
                DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " INTEGER," +
                DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL + " TEXT," +
                DownloadRequestEntry.COLUMN_NAME_USER_AGENT + " TEXT," +
                DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION + " TEXT," +
                DownloadRequestEntry.COLUMN_NAME_MIME_TYPE + " TEXT," +
                DownloadRequestEntry.COLUMN_NAME_COOKIE + " TEXT," +
                DownloadRequestEntry.COLUMN_NAME_STATUS + " INTEGER)"

        private const val SQL_DELETE_ENTRIES = "DROP TABLE IF EXISTS " + DownloadRequestEntry.TABLE_NAME
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(SQL_CREATE_ENTRIES)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // execute upgrade sql
    }

    override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        onUpgrade(db, oldVersion, newVersion)
    }

    fun dropTable() {
        writableDatabase.execSQL(SQL_DELETE_ENTRIES)
    }

    fun insetDownloadRequest(
        downloadRequestId: Long, url: String, userAgent: String?,
        contentDisposition: String?, mimetype: String?, cookie: String?
    ): Long {
        val db = writableDatabase

        val values = ContentValues()
        values.put(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID, downloadRequestId)
        values.put(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL, url)
        values.put(DownloadRequestEntry.COLUMN_NAME_USER_AGENT, userAgent)
        values.put(DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION, contentDisposition)
        values.put(DownloadRequestEntry.COLUMN_NAME_MIME_TYPE, mimetype)
        values.put(DownloadRequestEntry.COLUMN_NAME_COOKIE, cookie)
        values.put(DownloadRequestEntry.COLUMN_NAME_STATUS, DownloadRequestStatus.NONE.status)

        return db.insert(DownloadRequestEntry.TABLE_NAME, null, values)
    }

    fun updateDownloadRequestStatus(downloadRequestId: Long, newStatus: Int): Int {
        val db = writableDatabase

        val values = ContentValues()
        values.put(DownloadRequestEntry.COLUMN_NAME_STATUS, newStatus)
        val selection: String = DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " = ?"
        val selectionArgs = arrayOf(downloadRequestId.toString())

        return db.update(
            DownloadRequestEntry.TABLE_NAME,
            values,
            selection,
            selectionArgs
        )
    }

    fun resetDownloadRequestWithNewId(downloadRequestId: Long, newDownloadRequestId: Long): Int {
        val db = writableDatabase

        val values = ContentValues()
        values.put(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID, newDownloadRequestId)
        values.put(DownloadRequestEntry.COLUMN_NAME_STATUS, DownloadRequestStatus.NONE.status)
        val selection: String = DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " = ?"
        val selectionArgs = arrayOf(downloadRequestId.toString())

        return db.update(
            DownloadRequestEntry.TABLE_NAME,
            values,
            selection,
            selectionArgs
        )
    }

    fun deleteDownloadRequest(downloadRequestId: Long): Int {
        val db = writableDatabase

        val selection: String = DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " = ?"
        val selectionArgs = arrayOf(downloadRequestId.toString())

        return db.delete(DownloadRequestEntry.TABLE_NAME, selection, selectionArgs)
    }

    fun getAllDownloadRequestByStatus(status: Int): ArrayList<DownloadRequest> {
        val db = readableDatabase
        val downloadRequests = ArrayList<DownloadRequest>()

        val projection = arrayOf<String>(
            BaseColumns._ID,
            DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID,
            DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL,
            DownloadRequestEntry.COLUMN_NAME_USER_AGENT,
            DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION,
            DownloadRequestEntry.COLUMN_NAME_MIME_TYPE,
            DownloadRequestEntry.COLUMN_NAME_COOKIE,
            DownloadRequestEntry.COLUMN_NAME_STATUS
        )
        val selection: String = DownloadRequestEntry.COLUMN_NAME_STATUS + " = ?"
        val selectionArgs = arrayOf(status.toString())
        val sortOrder: String = BaseColumns._ID + " DESC"

        try {
            val cursor = db.query(
                DownloadRequestEntry.TABLE_NAME,
                projection,
                selection,
                selectionArgs,
                null,
                null,
                sortOrder
            )
            if (cursor != null) {
                val idColumn =
                    cursor.getColumnIndexOrThrow(BaseColumns._ID)
                val downloadRequestIdColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID)
                val urlColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL)
                val userAgentColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_USER_AGENT)
                val contentDispositionColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION)
                val mimeTypeColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_MIME_TYPE)
                val cookieColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_COOKIE)
                val statusColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_STATUS)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idColumn)
                    val downloadRequestId = cursor.getLong(downloadRequestIdColumn)
                    val url = cursor.getString(urlColumn)
                    val userAgent = cursor.getString(userAgentColumn)
                    val contentDisposition = cursor.getString(contentDispositionColumn)
                    val mimeType = cursor.getString(mimeTypeColumn)
                    val cookie = cursor.getString(cookieColumn)
                    val requestStatus = cursor.getInt(statusColumn)

                    downloadRequests.add(
                        DownloadRequest(
                            id, downloadRequestId, url, userAgent,
                            contentDisposition, mimeType, cookie, requestStatus
                        )
                    )
                }
                cursor.close()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return downloadRequests
    }

    fun getDownloadRequestById(downloadRequestId: Long): DownloadRequest? {
        val db = readableDatabase

        val projection = arrayOf<String>(
            BaseColumns._ID,
            DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID,
            DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL,
            DownloadRequestEntry.COLUMN_NAME_USER_AGENT,
            DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION,
            DownloadRequestEntry.COLUMN_NAME_MIME_TYPE,
            DownloadRequestEntry.COLUMN_NAME_COOKIE,
            DownloadRequestEntry.COLUMN_NAME_STATUS
        )
        val selection: String = DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_REQUEST_ID + " = ?"
        val selectionArgs = arrayOf(downloadRequestId.toString())
        val sortOrder: String = BaseColumns._ID + " DESC"

        try {
            val cursor = db.query(
                DownloadRequestEntry.TABLE_NAME,
                projection,
                selection,
                selectionArgs,
                null,
                null,
                sortOrder
            )

            if (cursor != null && cursor.moveToFirst()) {
                val idColumn =
                    cursor.getColumnIndexOrThrow(BaseColumns._ID)
                val urlColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_DOWNLOAD_URL)
                val userAgentColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_USER_AGENT)
                val contentDispositionColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_CONTENT_DISPOSITION)
                val mimeTypeColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_MIME_TYPE)
                val cookieColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_COOKIE)
                val statusColumn =
                    cursor.getColumnIndexOrThrow(DownloadRequestEntry.COLUMN_NAME_STATUS)

                val id = cursor.getLong(idColumn)
                val url = cursor.getString(urlColumn)
                val userAgent = cursor.getString(userAgentColumn)
                val contentDisposition = cursor.getString(contentDispositionColumn)
                val mimeType = cursor.getString(mimeTypeColumn)
                val cookie = cursor.getString(cookieColumn)
                val requestStatus = cursor.getInt(statusColumn)

                cursor.close()

                return DownloadRequest(
                    id, downloadRequestId, url, userAgent, contentDisposition,
                    mimeType, cookie, requestStatus
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
