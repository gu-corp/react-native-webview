#import "DownloadModule.h"
#import "Utility.h"
#import "DownloadQueue.h"

@implementation DownloadModule
{
    NSMutableArray<Download *> *_downloads;
    DownloadQueue *_currentDownloadQueue;
}

RCT_EXPORT_MODULE(DownloadModule);

- (NSArray<NSString *> *)supportedEvents {
    return @[@"DownloadStarted", @"TotalBytesExpectedDidChange", @"CombinedBytesDownloadedDidChange", @"DownloadCompleted", @"DownloadCanceled", @"PassBookError", @"DownloadingFileDidUpdate", @"DownloadingFileItemDidSuccess"];
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
        _downloads = [NSMutableArray array];
        sharedInstance = self;
        [Utility updateDownloadingList];
    }
    return self;
}

- (void) addDownload: (Download *) download {
    [_downloads addObject:download];
    if (self.combinedTotalBytesExpected) {
        NSNumber *totalBytesExpected = download.totalBytesExpected;
        if (totalBytesExpected) {
            self.combinedTotalBytesExpected = @(self.combinedTotalBytesExpected.longLongValue + totalBytesExpected.longLongValue);
        } else {
            self.combinedTotalBytesExpected = nil;
        }
    }
    [self sendEventWithName:@"TotalBytesExpectedDidChange" body:@{@"totalBytesExpected": self.combinedTotalBytesExpected ?: @0, @"downloadCount": @([_downloads count])}];

}

- (void)downloadQueue:(id)downloadQueue didCompleteWithError:(NSError * _Nullable)error {
    if (_downloads.count != 0) {
        NSString *errorStr = error != nil ? [error description] : @"";
        [self sendEventWithName:@"DownloadCompleted" body:@{@"error": errorStr}];
        [_downloads removeAllObjects];
        self.combinedBytesDownloaded = 0;
        self.combinedTotalBytesExpected = @0;
    }
}

- (void)downloadQueue:(id)downloadQueue didDownloadCombinedBytes:(int64_t)combinedBytesDownloaded combinedTotalBytesExpected:(nullable NSNumber *)combinedTotalBytesExpected {
    self.combinedBytesDownloaded = combinedBytesDownloaded;
    [self sendEventWithName:@"CombinedBytesDownloadedDidChange" body:@{@"combinedBytesDownloaded": @(self.combinedBytesDownloaded ?: 0)}];

}

- (void)downloadQueue:(id)downloadQueue didStartDownload:(Download *)download {
    _currentDownloadQueue = downloadQueue;
    if (_downloads.count == 0) {
        [_downloads addObject:download];
        self.combinedTotalBytesExpected = download.totalBytesExpected;
        [self sendEventWithName:@"DownloadStarted" body:@{@"totalBytesExpected": self.combinedTotalBytesExpected ?: @0}];

    } else {
        [self addDownload:download];
    }
}

- (void)downloadQueue:(id)downloadQueue didRemoveDownload:(Download *)download {
    [_downloads removeObject:download];
    if (self.combinedTotalBytesExpected) {
        NSNumber *totalBytesExpected = download.totalBytesExpected;
        if (totalBytesExpected) {
            self.combinedTotalBytesExpected = @(self.combinedTotalBytesExpected.longLongValue - totalBytesExpected.longLongValue);
        } else {
            self.combinedTotalBytesExpected = nil;
        }
    }
    [self sendEventWithName:@"TotalBytesExpectedDidChange" body:@{@"totalBytesExpected": self.combinedTotalBytesExpected ?: @0, @"downloadCount": @([_downloads count])}];
}

- (void)downloadQueue:(id)downloadQueue download:(Download *)download didFinishDownloadingTo:(NSURL *)location {
    
}

- (void) passBookdidCompleteWithError {
    [self sendEventWithName:@"PassBookError" body:@{}];
}

- (void) downloadingFileDidUpdate {
    NSMutableArray *resultArray = [NSMutableArray arrayWithArray:[DownloadQueue downloadingList]];
    [self sendEventWithName:@"DownloadingFileDidUpdate" body:@{@"downloadingList": resultArray}];
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
    if (_currentDownloadQueue && ![_currentDownloadQueue isEmpty]) {
        [_currentDownloadQueue cancelAll];
        [_downloads removeAllObjects];
        self.combinedBytesDownloaded = 0;
        self.combinedTotalBytesExpected = @0;
        [self sendEventWithName:@"DownloadCanceled" body:@{}];
    }
}

RCT_EXPORT_METHOD(pauseDownload: (NSString *)sessionId)
{
    if (_currentDownloadQueue && ![_currentDownloadQueue isEmpty]) {
        for (HTTPDownload *download in _downloads) {
            if ([download.session.configuration.identifier isEqual: [NSString stringWithFormat:@"sessionId%@", sessionId]]) {
                [_downloads removeObject:download];
                [_currentDownloadQueue dequeue:download sessionId:sessionId];
                break;
            }
        }
    }
}

RCT_EXPORT_METHOD(resumeDownload: (NSString *)sessionId)
{
    NSArray *sessionInfos = [DownloadQueue downloadingList];
    if (sessionInfos && sessionInfos.count != 0) {
        NSDictionary *sessionInfo;
        for (NSDictionary *temp in sessionInfos) {
            NSString *tempSessionId = [[temp objectForKey:@"sessionId"] stringValue];
            if ([tempSessionId isEqual:sessionId]) {
                sessionInfo = temp;
                break;
            }
        }
        if (!sessionInfo) {
            return;
        }
        NSString *sessionStr = [NSString stringWithFormat:@"sessionId%@", sessionId] ;
        NSString *url = [sessionInfo objectForKey:@"url"];
        NSString *fileName = [sessionInfo objectForKey:@"fileName"];
        NSString *mimeType = [sessionInfo objectForKey:@"mimeType"];
        NSNumber *length = [sessionInfo objectForKey:@"expectedFileSize"];
        HTTPDownload *download = [[HTTPDownload alloc] initWithSessionId:sessionStr urlStr: url fileName:fileName mimeType:mimeType expectedFileSize:length];
        [download updateSessionInfo:sessionId downloadedSize:nil status:@0];
        [[DownloadQueue downloadQueue] enqueue: download];
    }
}

RCT_EXPORT_METHOD(getListDowloading:(RCTResponseSenderBlock)callback) {
    NSMutableArray *resultArray = [NSMutableArray arrayWithArray:[DownloadQueue downloadingList]];
    callback(@[[NSNull null], resultArray]);
}

@end
