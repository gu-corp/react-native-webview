#import "DownloadModule.h"
#import "Utility.h"

@implementation DownloadModule
{
    NSMutableArray<Download *> *_downloads;
}

RCT_EXPORT_MODULE(DownloadModule);

- (NSArray<NSString *> *)supportedEvents {
    return @[@"DownloadStarted", @"TotalBytesExpectedDidChange", @"CombinedBytesDownloadedDidChange", @"DownloadCompleted", @"PassBookError"];
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
    [self sendEventWithName:@"TotalBytesExpectedDidChange" body:@{@"totalBytesExpected": self.combinedTotalBytesExpected}];
}

- (void)setPercent:(CGFloat)percent {
    _percent = percent;
    NSString *downloadedSize = [NSByteCountFormatter stringFromByteCount:_combinedBytesDownloaded countStyle:NSByteCountFormatterCountStyleFile];
    NSString *expectedSize = _combinedTotalBytesExpected != nil ? [NSByteCountFormatter stringFromByteCount:_combinedTotalBytesExpected.longLongValue countStyle:NSByteCountFormatterCountStyleFile] : nil;
}

- (void)setCombinedBytesDownloaded:(int64_t)combinedBytesDownloaded {
    _combinedBytesDownloaded = combinedBytesDownloaded;
    [self updatePercent];
}

- (void)setCombinedTotalBytesExpected:(NSNumber *)combinedTotalBytesExpected {
    _combinedTotalBytesExpected = combinedTotalBytesExpected;
    [self updatePercent];
}

- (void)updatePercent {
    dispatch_async(dispatch_get_main_queue(), ^{
        int64_t combinedBytesDownloaded = self.combinedBytesDownloaded;
        NSNumber *combinedTotalBytesExpected = self.combinedTotalBytesExpected;
        
        if (!combinedTotalBytesExpected) {
            self.percent = 0.0;
            return;
        }
        
        self.percent = (CGFloat)combinedBytesDownloaded / [combinedTotalBytesExpected doubleValue];
    });
}


- (void)downloadQueue:(id)downloadQueue didCompleteWithError:(NSError * _Nullable)error {
    NSString *errorStr = error != nil ? [error description] : @"";
    [self sendEventWithName:@"DownloadCompleted" body:@{@"error": errorStr}];
    [_downloads removeAllObjects];
    self.combinedBytesDownloaded = 0;
    self.combinedTotalBytesExpected = @0;
}

- (void)downloadQueue:(id)downloadQueue didDownloadCombinedBytes:(int64_t)combinedBytesDownloaded combinedTotalBytesExpected:(nullable NSNumber *)combinedTotalBytesExpected {
    self.combinedBytesDownloaded = combinedBytesDownloaded;
    [self sendEventWithName:@"CombinedBytesDownloadedDidChange" body:@{@"combinedBytesDownloaded": @(self.combinedBytesDownloaded)}];
}

- (void)downloadQueue:(id)downloadQueue didStartDownload:(Download *)download {
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

- (void) passBookdidCompleteWithError {
    [self sendEventWithName:@"PassBookError" body:@{}];
}

RCT_EXPORT_METHOD(openDownloadFolder)
{
    [Utility openDownloadFolder];
}

@end
