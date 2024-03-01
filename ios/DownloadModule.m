#import "DownloadModule.h"
#import "Utility.h"

@implementation DownloadModule
{
    NSMutableArray<Download *> *_downloads;
    DownloadQueue *_currentDownloadQueue;
}

RCT_EXPORT_MODULE(DownloadModule);

- (NSArray<NSString *> *)supportedEvents {
    return @[@"DownloadStarted", @"TotalBytesExpectedDidChange", @"CombinedBytesDownloadedDidChange", @"DownloadCompleted", @"DownloadCanceled"];
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
    [self sendEventWithName:@"TotalBytesExpectedDidChange" body:@{@"totalBytesExpected": self.combinedTotalBytesExpected, @"downloadCount": @([_downloads count])}];
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
    [self sendEventWithName:@"CombinedBytesDownloadedDidChange" body:@{@"combinedBytesDownloaded": @(self.combinedBytesDownloaded)}];
}

- (void)downloadQueue:(id)downloadQueue didStartDownload:(Download *)download {
    _currentDownloadQueue = downloadQueue;
    if (_downloads.count == 0) {
        [_downloads addObject:download];
        self.combinedTotalBytesExpected = download.totalBytesExpected;
        [self sendEventWithName:@"DownloadStarted" body:@{@"totalBytesExpected": self.combinedTotalBytesExpected}];
    } else {
        [self addDownload:download];
    }
}

- (void)downloadQueue:(id)downloadQueue download:(Download *)download didFinishDownloadingTo:(NSURL *)location {
    
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

@end
