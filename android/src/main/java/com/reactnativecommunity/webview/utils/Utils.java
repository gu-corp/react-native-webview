package com.reactnativecommunity.webview.utils;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.webkit.MimeTypeMap;

import androidx.core.app.NotificationCompat;

import com.reactnativecommunity.webview.R;

import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class Utils {

  private static final Pattern CONTENT_DISPOSITION_PATTERN =
    Pattern.compile("attachment;\\s*filename\\s*=\\s*(\"?)([^\"]*)\\1\\s*$",
      Pattern.CASE_INSENSITIVE);

  public static String getBase64Data(String base64Data) {
    String[] parts = base64Data.split(",");
    if (parts.length > 1) {
      return parts[1];
    }
    return base64Data;
  }

  public static String getMimeTypeFromBase64Data(String base64Data) {
    String[] parts = base64Data.split(";");
    if (parts.length > 0) {
      String[] typePart = parts[0].split(":");
      if (typePart.length > 1) {
        return typePart[1];
      }
    }
    return null;
  }

  public static String getFileExtensionFromBase64Data(String base64Data) {
    String[] parts = base64Data.split(";");
    if (parts.length > 0) {
      String[] extensionPart = parts[0].split("/");
      if (extensionPart.length > 1) {
        return extensionPart[1];
      }
    }
    return null;
  }

  public static void makeNotificationDownloadedBlobFile(Context context, Uri fileUri, String mimeType, String fileName) {
    Intent intent = new Intent(Intent.ACTION_VIEW);
    intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
    if (mimeType != null) {
      intent.setDataAndType(fileUri, mimeType);
    } else {
      intent.setData(fileUri);
    }
    PendingIntent pendingIntent = PendingIntent.getActivity(
      context, 0, intent,
      PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

    NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    String channel = "LunascapeChannel";

    NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(context, channel)
      .setAutoCancel(true)
      .setContentTitle("File downloaded")
      .setContentText(fileName)
      .setSmallIcon(R.drawable.ic_download_done_24)
      .setWhen(System.currentTimeMillis())
      .setPriority(Notification.PRIORITY_DEFAULT)
      .setContentIntent(pendingIntent);

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      NotificationChannel notificationChannel = new NotificationChannel(channel, channel, NotificationManager.IMPORTANCE_DEFAULT);
      notificationChannel.setDescription(channel);
      notificationChannel.enableLights(true);
      notificationChannel.enableVibration(true);
      notificationChannel.setLockscreenVisibility(Notification.VISIBILITY_PRIVATE);
      notificationManager.createNotificationChannel(notificationChannel);
      notificationBuilder.setChannelId(channel);
    }

    notificationManager.notify(1, notificationBuilder.build());
  }

  public static String getFileNameDownload(String url, String contentDisposition, String mimeType) {
    String filename = null;
    String extension = null;

    // If we couldn't do anything with the hint, move toward the content disposition
    filename = parseContentDisposition(contentDisposition);
    if (filename != null) {
      int index = filename.lastIndexOf('/') + 1;
      if (index > 0) {
        filename = filename.substring(index);
      }
      // Check extension
      int dotIndex = filename.indexOf('.');
      if (dotIndex > 0) {
        return filename;
      }
    }
    // If all the other http-related approaches failed, use the plain uri
    if (filename == null) {
      String decodedUrl = Uri.decode(url);
      if (decodedUrl != null) {
        int queryIndex = decodedUrl.indexOf('?');
        // If there is a query string strip it, same as desktop browsers
        if (queryIndex > 0) {
          decodedUrl = decodedUrl.substring(0, queryIndex);
        }
        if (!decodedUrl.endsWith("/")) {
          int index = decodedUrl.lastIndexOf('/') + 1;
          if (index > 0) {
            filename = decodedUrl.substring(index);
          }
          if (filename != null) {
            // Check extension
            int dotIndex = filename.indexOf('.');
            if (dotIndex > 0) {
              return filename;
            }
          }
        }
      }
    }

    // Finally, if couldn't get filename from URI, get a generic filename
    if (filename == null) {
      filename = String.valueOf(System.currentTimeMillis());
    }

    // Add an extension if filename does not have one
    if (mimeType != null) {
      extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType);
      if (extension != null) {
        extension = "." + extension;
      }
    }
    if (extension == null) {
      if (mimeType != null && mimeType.toLowerCase(Locale.ROOT).startsWith("text/")) {
        if (mimeType.equalsIgnoreCase("text/html")) {
          extension = ".html";
        } else {
          extension = ".txt";
        }
      } else {
        extension = ".bin";
      }
    }

    return filename + extension;
  }

  public static String parseContentDisposition(String contentDisposition) {
    try {
      Matcher m = CONTENT_DISPOSITION_PATTERN.matcher(contentDisposition);
      if (m.find()) {
        return m.group(2);
      }
    } catch (IllegalStateException ex) {
      // This function is defined as returning null when it can't parse the header
    }
    return null;
  }

}
