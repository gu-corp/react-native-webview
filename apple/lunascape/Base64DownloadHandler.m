#import "Base64DownloadHandler.h"
#import "Utility.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface Base64DownloadHandler ()
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, copy) void (^onComplete)(Base64DownloadHandler *handler);
@property (nonatomic, copy) void (^cancelCallback)(void);
@property (nonatomic, strong) NSURL *destinationURL;
@end

@implementation Base64DownloadHandler

- (instancetype)initWithPresenter:(UIViewController *)presenter
                       onComplete:(void (^_Nullable)(Base64DownloadHandler *handler))onComplete {
    self = [super init];
    if (self) {
        _presenter = presenter;
        _onComplete = [onComplete copy];
    }
    return self;
}

#pragma mark - Public

- (void)presentForDataURL:(NSURL *)dataURL
                 fromView:(UIView *)view
               onProceed:(void(^)(void))onProceed
                onCancel:(void(^)(void))onCancel {

    if (!self.presenter || !dataURL) { if (onCancel) onCancel(); return; }

    NSString *mimeType = nil;
    NSString *filename = nil;
    BOOL isBase64 = NO;
    NSString *base64 = nil;
    if (![self parseDataURL:dataURL.absoluteString mimeType:&mimeType filename:&filename isBase64:&isBase64 base64:&base64] || !isBase64) {
        if (onCancel) onCancel();
        return;
    }

    // Expected size from base64 length (approx): floor(n * 3/4) - padding
    NSUInteger n = base64.length;
    NSUInteger pad = 0;
    if (n >= 2) {
        if ([base64 hasSuffix:@"=="]) pad = 2;
        else if ([base64 hasSuffix:@"="]) pad = 1;
    }
    long long expectedBytes = (long long)((n * 3) / 4 - pad);
    NSString *expectedSize = expectedBytes > 0 ? [NSByteCountFormatter stringFromByteCount:expectedBytes countStyle:NSByteCountFormatterCountStyleFile] : nil;

    NSString *host = @"data";
    NSString *title = [NSString stringWithFormat:@"%@ - %@", filename ?: @"download", host];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // Button titles from Utility downloadConfig (same keys you already use)
    NSString *downloadText = [Utility downloadConfig][@"downloadButton"] ?: @"Download";
    if (expectedSize) downloadText = [NSString stringWithFormat:@"%@ (%@)", downloadText, expectedSize];
    NSString *cancelTitle = [Utility downloadConfig][@"downloadCancelButton"] ?: @"Cancel";

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:downloadText style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        // Proceed: decode and save, then complete
        [weakSelf decodeAndSaveBase64:base64 suggestedFilename:(filename ?: @"download") completion:^(BOOL ok, NSError *err) {
            if (ok) {
                NSString *okTitle = [Utility downloadConfig][@"downloadCompletedTitle"] ?: @"Download completed";
                [weakSelf showAlertWithTitle:okTitle message:weakSelf.destinationURL.lastPathComponent ?: @""];
            } else {
                NSString *failTitle = [Utility downloadConfig][@"downloadFailedTitle"] ?: @"Download failed";
                [weakSelf showAlertWithTitle:failTitle message:(err.localizedDescription ?: @"")];
            }
            if (onProceed) onProceed();
            if (weakSelf.onComplete) weakSelf.onComplete(weakSelf);
            weakSelf.cancelCallback = nil;
        }];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *a) {
        if (onCancel) onCancel();
        if (weakSelf.onComplete) weakSelf.onComplete(weakSelf);
        weakSelf.cancelCallback = nil;
    }]];

    // Save cancel callback for iPad outside-tap dismiss case
    self.cancelCallback = [onCancel copy];

    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(view.bounds), CGRectGetMaxY(view.bounds) - 16, 0, 0);
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        popover.delegate = self;
    }

    [self.presenter presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIPopoverPresentationControllerDelegate/UIAdaptivePresentationControllerDelegate

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    if (self.cancelCallback) { self.cancelCallback(); self.cancelCallback = nil; }
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    if (self.cancelCallback) { self.cancelCallback(); self.cancelCallback = nil; }
}

#pragma mark - Helpers

- (BOOL)parseDataURL:(NSString *)url
            mimeType:(NSString * _Nullable * _Nullable)mimeType
            filename:(NSString * _Nullable * _Nullable)filename
            isBase64:(BOOL *)isBase64
              base64:(NSString * _Nullable * _Nullable)base64Out {
    if (![url hasPrefix:@"data:"]) return NO;
    NSRange comma = [url rangeOfString:@","];
    if (comma.location == NSNotFound) return NO;

    NSString *meta = [url substringWithRange:NSMakeRange(5, comma.location - 5)];
    NSString *payload = [url substringFromIndex:comma.location + 1];

    BOOL b64 = [meta.lowercaseString containsString:@";base64"];
    if (isBase64) *isBase64 = b64;
    if (!b64) return YES;

    // Extract MIME type
    NSString *mt = @"application/octet-stream";
    NSArray<NSString *> *parts = [meta componentsSeparatedByString:@";"];
    if (parts.count > 0 && parts[0].length > 0) mt = parts[0];

    if (mimeType) *mimeType = mt;
    if (base64Out) *base64Out = payload;

    // Suggest filename from MIME type
    NSString *ext = @"bin";
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)mt, NULL);
    if (uti) {
        CFStringRef tag = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
        if (tag) { ext = (__bridge_transfer NSString *)tag; }
        CFRelease(uti);
    }
    if (filename) *filename = [NSString stringWithFormat:@"download.%@", ext];
    return YES;
}

- (void)decodeAndSaveBase64:(NSString *)base64
          suggestedFilename:(NSString *)suggestedFilename
                 completion:(void(^)(BOOL ok, NSError * _Nullable err))completion {

    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!data) { if (completion) completion(NO, [NSError errorWithDomain:@"Base64Download" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid base64"}]); return; }

    NSURL *folder = [self downloadsFolderURL];
    [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *dest = [self uniqueURLInFolder:folder suggestedFilename:(suggestedFilename ?: @"download")];

    NSError *writeErr = nil;
    [data writeToURL:dest options:NSDataWritingAtomic error:&writeErr];
    if (writeErr) { if (completion) completion(NO, writeErr); return; }

    self.destinationURL = dest;
    if (completion) completion(YES, nil);
}

- (NSURL *)downloadsFolderURL {
    NSURL *docs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSString *custom = [Utility downloadConfig][@"downloadFolder"];
    NSURL *folder = custom && custom.length > 0 ? [docs URLByAppendingPathComponent:custom] : [docs URLByAppendingPathComponent:@"downloads"];
    return folder;
}

- (NSURL *)uniqueURLInFolder:(NSURL *)folder suggestedFilename:(NSString *)suggested {
    NSString *base = [suggested stringByDeletingPathExtension];
    NSString *ext = [suggested pathExtension];
    NSURL *candidate = [folder URLByAppendingPathComponent:suggested];

    NSInteger index = 1;
    while ([[NSFileManager defaultManager] fileExistsAtPath:candidate.path]) {
        NSString *name = ext.length == 0
            ? [NSString stringWithFormat:@"%@-%ld", base, (long)index]
            : [NSString stringWithFormat:@"%@-%ld.%@", base, (long)index, ext];
        candidate = [folder URLByAppendingPathComponent:name];
        index++;
    }
    return candidate;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    if (!self.presenter) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        NSString *okTitle = [Utility downloadConfig][@"downloadOkayButton"] ?: @"OK";
        [alert addAction:[UIAlertAction actionWithTitle:okTitle style:UIAlertActionStyleDefault handler:nil]];
        [self.presenter presentViewController:alert animated:YES completion:nil];
    });
}

@end