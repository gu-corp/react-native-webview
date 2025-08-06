#import "DownloadModule.h"
#import "Utility.h"
#import "DownloadQueue.h"

@implementation DownloadModule

RCT_EXPORT_MODULE(DownloadModule);

- (NSArray<NSString *> *)supportedEvents {
    return @[@"DownloadCanceled", @"PassBookError", @"DownloadingFileDidUpdate", @"DownloadingFileItemDidSuccess", @"DownloadingFileItemDidChangeStatus", @"Base64FileSaved"];
}

static DownloadModule *sharedInstance = nil;

+ (instancetype)sharedInstance {
    if (sharedInstance) {
        return sharedInstance;
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (instancetype)init {
    self = [super init];
    if (self) {
        sharedInstance = self;
        [Utility initDownloadingList];
    }
    return self;
}

- (void) passBookdidCompleteWithError {
    [self sendEventWithName:@"PassBookError" body:@{}];
}

- (void) downloadingFileDidUpdate {
    NSMutableArray *resultArray = [NSMutableArray arrayWithArray:[DownloadQueue downloadingList]];
    [self sendEventWithName:@"DownloadingFileDidUpdate" body:@{@"downloadingList": resultArray}];
}

- (void)downloadingFileStatusDidUpdate:(NSNumber *)sessionId status:(NSString *)status {
    [self sendEventWithName:@"DownloadingFileItemDidChangeStatus" body:@{@"sessionId": sessionId, @"status": status}];
}

- (void)downloadingFileItemDidSuccess {
    [self sendEventWithName:@"DownloadingFileItemDidSuccess" body:@{}];
}

RCT_EXPORT_METHOD(openDownloadFolder)
{
    [Utility openDownloadFolder];
}

RCT_EXPORT_METHOD(cancelDownload)
{
    if ([DownloadQueue downloadQueue] && ![[DownloadQueue downloadQueue] isEmpty]) {
        [[DownloadQueue downloadQueue] cancelAll];
        [self sendEventWithName:@"DownloadCanceled" body:@{}];
    }
}

RCT_EXPORT_METHOD(pauseDownload: (NSString *)sessionId)
{
    if ([DownloadQueue downloadQueue]) {
        [[DownloadQueue downloadQueue] pauseDownload: sessionId];
    }
}

RCT_EXPORT_METHOD(resumeDownload: (NSString *)sessionId)
{
    if ([DownloadQueue downloadQueue]) {
        [[DownloadQueue downloadQueue] resumeDownload:sessionId];
    }
}

RCT_EXPORT_METHOD(deleteDownload: (NSString *)sessionId)
{
    if ([DownloadQueue downloadQueue]) {
        [[DownloadQueue downloadQueue] deleteDownload: sessionId];
    }
}

RCT_EXPORT_METHOD(getListDowloading:(RCTResponseSenderBlock)callback) {
    NSMutableArray *resultArray = [NSMutableArray arrayWithArray:[DownloadQueue downloadingList]];
    callback(@[resultArray]);
}

RCT_EXPORT_METHOD(saveBase64File:(NSString *)dataUrl filename:(NSString *)filename)
{
    // Parse dataUrl: "data:image/png;base64,...."
    NSArray *parts = [dataUrl componentsSeparatedByString:@","];
    if (parts.count != 2) {
        NSLog(@"Invalid data URL format");
        return;
    }
    
    NSString *base64String = parts[1];
    NSData *fileData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    
    if (!fileData) {
        NSLog(@"Failed to decode base64 data");
        return;
    }
    
    // Lưu file vào Documents directory
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [docsDir stringByAppendingPathComponent:filename];
    
    NSError *error;
    BOOL success = [fileData writeToFile:filePath options:NSDataWritingAtomic error:&error];
    
    if (success) {
        NSLog(@"File saved successfully: %@", filePath);
        // Có thể gửi event về JS nếu muốn
        [self sendEventWithName:@"Base64FileSaved" body:@{@"filename": filename, @"path": filePath}];
    } else {
        NSLog(@"Failed to save file: %@", error.localizedDescription);
    }
}

@end
