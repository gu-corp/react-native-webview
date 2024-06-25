#import "DownloadModule.h"
#import "Utility.h"
#import "DownloadQueue.h"

@implementation DownloadModule

RCT_EXPORT_MODULE(DownloadModule);

- (NSArray<NSString *> *)supportedEvents {
    return @[@"DownloadCanceled", @"PassBookError", @"DownloadingFileDidUpdate", @"DownloadingFileItemDidSuccess", @"DownloadingFileItemDidChangeStatus"];
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

@end
