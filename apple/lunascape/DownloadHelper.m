/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#import "DownloadHelper.h"
#import "Utility.h"

NSString * const DownloadStatusDownloading = @"downloading";
NSString * const DownloadStatusPause = @"pause";
NSString * const DownloadStatusFail = @"fail";
NSString * const DownloadStatusNone = @"none";

// -MARK: MIMMEType
@implementation MIMEType

NSString *const MIMETypeBitmap = @"image/bmp";
NSString *const MIMETypeCSS = @"text/css";
NSString *const MIMETypeGIF = @"image/gif";
NSString *const MIMETypeJavaScript = @"text/javascript";
NSString *const MIMETypeJPEG = @"image/jpeg";
NSString *const MIMETypeHTML = @"text/html";
NSString *const MIMETypeOctetStream = @"application/octet-stream";
NSString *const MIMETypePassbook = @"application/vnd.apple.pkpass";
NSString *const MIMETypePDF = @"application/pdf";
NSString *const MIMETypePlainText = @"text/plain";
NSString *const MIMETypePNG = @"image/png";
NSString *const MIMETypeWebP = @"image/webp";
NSString *const MIMETypeXHTML = @"application/xhtml+xml";

NSArray<NSString *> *webViewViewableTypes = nil;

+ (void)initialize {
    if (self == [MIMEType class]) {
        webViewViewableTypes = @[MIMETypeBitmap, MIMETypeGIF, MIMETypeJPEG, MIMETypeHTML, MIMETypePDF, MIMETypePlainText, MIMETypePNG, MIMETypeWebP, MIMETypeXHTML];
    }
}

+ (BOOL)canShowInWebView:(NSString *)mimeType {
    return [webViewViewableTypes containsObject:[mimeType lowercaseString]];
}

+ (NSString *)mimeTypeFromFileExtension:(NSString *)fileExtension {
    NSString *mimeType = (__bridge NSString *)(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)fileExtension, kUTTagClassFilenameExtension));
    return mimeType ?: MIMETypeOctetStream;
}

@end

@implementation NSString (HTMLCheck)

- (BOOL)isKindOfHTML {
    return [@[MIMETypeHTML, MIMETypeXHTML] containsObject:self];
}

@end

@implementation DownloadHelper

static NSMutableDictionary<NSString *, NSURLRequest *> *_pendingRequests = nil;
static NSMutableDictionary<NSString *, NSMutableArray *> *_blobData = nil;

+ (void)initialize {
    if (self == [DownloadHelper class]) {
        _pendingRequests = [NSMutableDictionary dictionary];
        _blobData = [NSMutableDictionary dictionary];
    }
}

+ (NSMutableDictionary *) blobData {
    return _blobData;
}

+ (void)setBlobData:(NSMutableDictionary *)newValue {
    _blobData = newValue;
}

+ (NSMutableDictionary *) pendingRequests {
    return _pendingRequests;
}

+ (void)setPendingRequests:(NSMutableDictionary *)newValue {
    _pendingRequests = newValue;
}

- (instancetype)initWithRequest:(NSURLRequest *)request response:(NSURLResponse *)response cookieStore:(WKHTTPCookieStore *)cookieStore canShowInWebView:(BOOL)canShowInWebView {
    self = [super init];
    if (self) {
        if (!request) {
            return nil;
        }
        
        NSString *mimeType = response.MIMEType ?: MIMETypeOctetStream;
        BOOL isAttachment = [mimeType isEqualToString:MIMETypeOctetStream];
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSString *contentDisposition = [(NSHTTPURLResponse *)response valueForHTTPHeaderField:@"Content-Disposition"];
            isAttachment = [contentDisposition hasPrefix:@"attachment"] || isAttachment;
        }

        if (!(isAttachment || !canShowInWebView)) {
            return nil;
        }

        _request = request;
        _preflightResponse = response;
        _cookieStore = cookieStore;
    }
    return self;
}

- (UIAlertController *)downloadAlertFromView:(UIView *)view
                                    okAction:(void (^)(id _Nullable download))okAction {
    return [self downloadAlertFromView:view okAction:okAction cancelAction:nil];
}

- (UIAlertController *)downloadAlertFromView:(UIView *)view
                                    okAction:(void (^)(id _Nullable download))okAction
                                cancelAction:(void (^_Nullable)(void))cancelAction {

    NSURL *url = self.request.URL;
    NSString *scheme = url.scheme.lowercaseString ?: @"";
    NSString *host = url.host ?: scheme;
    NSString *filename = url.lastPathComponent ?: @"";
    if (filename.length == 0) {
        filename = self.preflightResponse.suggestedFilename ?: @"download";
    }
    BOOL isBlobFile = [scheme isEqualToString:@"blob"];

    HTTPDownload *download = nil;
    NSString *expectedSize = nil;
    if (!isBlobFile) {
        download = [[HTTPDownload alloc] initWithCookieStore:self.cookieStore
                                           preflightResponse:self.preflightResponse
                                                     request:self.request];
        expectedSize = download.totalBytesExpected ? [NSByteCountFormatter stringFromByteCount:download.totalBytesExpected.longLongValue countStyle:NSByteCountFormatterCountStyleFile] : nil;
    }

    NSString *title = [NSString stringWithFormat:@"%@ - %@", filename, host];

    UIAlertController *downloadAlert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *downloadActionText = [[Utility downloadConfig] objectForKey:kDownloadButtonKey] ?: @"Download";
    // The download can be of undetermined size, adding expected size only if it's available.
    if (expectedSize) {
        downloadActionText = [NSString stringWithFormat:@"%@ (%@)", downloadActionText, expectedSize];
    }

    UIAlertAction *alertDoneAction = [UIAlertAction actionWithTitle:downloadActionText
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
        if (okAction) {
            okAction(download);
        }
    }];

    NSString *cancelButton = [[Utility downloadConfig] objectForKey:kDownloadCancelButtonKey] ?: @"Cancel";
    UIAlertAction *alertCancelAction = [UIAlertAction actionWithTitle:cancelButton
                                                                style:UIAlertActionStyleCancel
                                                              handler:^(UIAlertAction * _Nonnull action) {
        if (cancelAction) {
            cancelAction();
        }
    }];

    [downloadAlert addAction:alertDoneAction];
    [downloadAlert addAction:alertCancelAction];

    UIPopoverPresentationController *popover = downloadAlert.popoverPresentationController;
    if (popover) {
        popover.sourceView = view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(view.bounds), CGRectGetMaxY(view.bounds) - 16, 0, 0);
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    return downloadAlert;
}

@end

@implementation PendingDownload

- (instancetype) initWithFileUrl:(NSURL *)fileUrl response:(NSURLResponse *)response {
    self = [super init];
    if (self) {
        _fileUrl = fileUrl;
        _response = response;
    }
    return self;
}

@end
