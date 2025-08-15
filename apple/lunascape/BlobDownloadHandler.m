// BlobDownloadHandler.m
#import "BlobDownloadHandler.h"
#import "Utility.h"

@interface BlobDownloadHandler ()
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, copy) void (^onComplete)(BlobDownloadHandler *handler);
@property (nonatomic, strong) NSURL *destinationURL;
@end

@implementation BlobDownloadHandler

- (instancetype)initWithPresenter:(UIViewController *)presenter
                       onComplete:(void (^_Nullable)(BlobDownloadHandler *handler))onComplete {
    self = [super init];
    if (self) {
        _presenter = presenter;
        _onComplete = [onComplete copy];
    }
    return self;
}

- (void)download:(WKDownload *)download
decideDestinationUsingResponse:(NSURLResponse *)response
suggestedFilename:(NSString *)suggestedFilename
completionHandler:(void (^)(NSURL * _Nullable))completionHandler {

    NSURL *docs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *downloadsFolder = [docs URLByAppendingPathComponent:@"downloads"];
    [[NSFileManager defaultManager] createDirectoryAtURL:downloadsFolder
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];

    NSURL *dest = [self uniqueURLInFolder:downloadsFolder
                        suggestedFilename:(suggestedFilename ?: @"download")];

    if ([[NSFileManager defaultManager] fileExistsAtPath:dest.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:dest error:nil];
    }

    NSLog(@"Documents dir: %@", docs.path);
    NSLog(@"Saving file to: %@", dest.path);

    self.destinationURL = dest;
    completionHandler(dest);
}

- (void)downloadDidFinish:(WKDownload *)download API_AVAILABLE(ios(14.5)) {
    NSLog(@"Download finished. Saved at: %@", self.destinationURL.path);
    NSString *filename = self.destinationURL.lastPathComponent ?: @"";
    NSString *title = [Utility downloadConfig][@"downloadCompletedTitle"] ?: @"Download completed";
    [self showAlertWithTitle:title message:filename];
    if (self.onComplete) self.onComplete(self);
}

- (void)download:(WKDownload *)download
 didFailWithError:(NSError *)error
       resumeData:(NSData *)resumeData API_AVAILABLE(ios(14.5)) {
    if (self.destinationURL) {
        NSLog(@"Download failed: %@ | planned: %@", error.localizedDescription, self.destinationURL.path);
    } else {
        NSLog(@"Download failed: %@", error.localizedDescription);
    }
    NSString *title = [Utility downloadConfig][@"downloadFailedTitle"] ?: @"Download failed";
    [self showAlertWithTitle:title message:error.localizedDescription];
    if (self.onComplete) self.onComplete(self);
}

#pragma mark - Helpers

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
