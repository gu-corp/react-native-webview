package com.reactnativecommunity.webview;

import android.app.DownloadManager;
import android.net.Uri;
import android.webkit.ValueCallback;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.module.annotations.ReactModule;
import com.brave.adblock.Engine;
import com.reactnativecommunity.webview.lunascape.downloaddatabase.DownloadRequest;

@ReactModule(name = RNCWebViewModuleImpl.NAME)
public class RNCWebViewModule extends NativeRNCWebViewModuleSpec {
    final private RNCWebViewModuleImpl mRNCWebViewModuleImpl;

    public RNCWebViewModule(ReactApplicationContext reactContext) {
        super(reactContext);
        mRNCWebViewModuleImpl = new RNCWebViewModuleImpl(reactContext);
    }

    @Override
    public void isFileUploadSupported(final Promise promise) {
        promise.resolve(mRNCWebViewModuleImpl.isFileUploadSupported());
    }

    @Override
    public void shouldStartLoadWithLockIdentifier(boolean shouldStart, double lockIdentifier) {
        mRNCWebViewModuleImpl.shouldStartLoadWithLockIdentifier(shouldStart, lockIdentifier);
    }

    public void startPhotoPickerIntent(ValueCallback<Uri> filePathCallback, String acceptType) {
        mRNCWebViewModuleImpl.startPhotoPickerIntent(acceptType, filePathCallback);
    }

    public boolean startPhotoPickerIntent(final ValueCallback<Uri[]> callback, final String[] acceptTypes, final boolean allowMultiple, final boolean isCaptureEnabled) {
        return mRNCWebViewModuleImpl.startPhotoPickerIntent(acceptTypes, allowMultiple, callback, isCaptureEnabled);
    }

    public void setDownloadRequest(DownloadManager.Request request, DownloadRequest tempDownloadRequest) {
        mRNCWebViewModuleImpl.setDownloadRequest(request, tempDownloadRequest);
    }

    public void downloadFile(String downloadingMessage) {
        mRNCWebViewModuleImpl.downloadFile(downloadingMessage);
    }

    public boolean grantFileDownloaderPermissions(String downloadingMessage, String lackPermissionToDownloadMessage) {
        return mRNCWebViewModuleImpl.grantFileDownloaderPermissions(downloadingMessage, lackPermissionToDownloadMessage);
    }

    @NonNull
    @Override
    public String getName() {
        return RNCWebViewModuleImpl.NAME;
    }

    /**
     * Lunascape modules
     * */
    public static RNCWebViewModule getRNCWebViewModule(ReactContext reactContext) {
        return reactContext.getNativeModule(RNCWebViewModule.class);
    }

    /**
     * Adblock
     * */
    @Override
    public void addAdblockRulesFromAsset(String name, String assetPath, final Promise promise) {
        mRNCWebViewModuleImpl.addAdblockRulesFromAsset(name, assetPath, promise);
    }

    @Override
    public void addAdblockRules(String name, String rules, final Promise promise) {
        mRNCWebViewModuleImpl.addAdblockRules(name, rules, promise);
    }

    @Override
    public void removeAdblockRules(String name, String rules, final Promise promise) {
        mRNCWebViewModuleImpl.removeAdblockRules(name, rules, promise);
    }

    public Engine getAdblockEngine(String name) {
        return mRNCWebViewModuleImpl.getAdblockEngine(name);
    }

    /**
     * Download manager
     * */
    /**
     * Get list downloading files
     * */
    @Override
    public void getDownloadingFiles(final Promise promise) {
        mRNCWebViewModuleImpl.getDownloadingFiles(promise);
    }

    /**
     *  Delete downloading file by download id
     * */
    @Override
    public void deleteDownloadingFileById(double downloadId, final Promise promise) {
        mRNCWebViewModuleImpl.deleteDownloadingFileById((int) downloadId, promise);
    }

    /**
     * Pause downloading file by downloadId
     * */
    @Override
    public void pauseDownloadingFileById(double downloadId) {
        mRNCWebViewModuleImpl.pauseDownloadingFileById((int) downloadId);
    }

    /**
     * Resume downloading file by downloadId
     * */
    @Override
    public void resumeDownloadingFileById(double downloadId, String downloadFolderConfig, final Promise promise) {
        mRNCWebViewModuleImpl.resumeDownloadingFileById((int) downloadId, downloadFolderConfig, promise);
    }

    /**
     * Download blob file
     * */
    public void setDownloadFolder(String folder) {
        mRNCWebViewModuleImpl.setDownloadFolder(folder);
    }

    public void sendPartialBase64Data(String base64Data) {
        mRNCWebViewModuleImpl.sendPartialBase64Data(base64Data);
    }

    public void saveBase64DataToFile() {
        mRNCWebViewModuleImpl.saveBase64DataToFile();
    }
}
