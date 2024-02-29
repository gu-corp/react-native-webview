package com.reactnativecommunity.webview.utils;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;

import androidx.core.app.NotificationCompat;

import com.reactnativecommunity.webview.R;

public class Utils {

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

}
