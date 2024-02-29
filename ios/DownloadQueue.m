#import "DownloadQueue.h"
#import "Utility.h"
#import "DownloadModule.h"

@implementation Download

- (instancetype)init {
    self = [super init];
    if (self) {
        _filename = @"unknown";
        _mimeType = @"application/octet-stream";
        _bytesDownloaded = 0;
    }
    return self;
}

- (void)cancel {
    // Implement cancellation logic here
}

- (void)pause {
    // Implement pause logic here
}

- (void)resume {
    // Implement resume logic here
}

@end

@implementation HTTPDownload

{
    NSData *resumeData;
}

- (instancetype)initWithCookieStore:(WKHTTPCookieStore *)cookieStore preflightResponse:(NSURLResponse *)preflightResponse request:(NSURLRequest *)request {
    self = [super init];
    if (self) {
        _cookieStore = cookieStore;
        _preflightResponse = preflightResponse;
        _request = request;

        if (preflightResponse.suggestedFilename) {
            self.filename = [self stripUnicodeFromFilename:preflightResponse.suggestedFilename];
        }

        if (preflightResponse.MIMEType) {
            self.mimeType = preflightResponse.MIMEType;
        }

        self.totalBytesExpected = preflightResponse.expectedContentLength > 0 ? @(preflightResponse.expectedContentLength) : nil;

        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:[NSOperationQueue mainQueue]];

        _task = [_session downloadTaskWithRequest:_request];
    }
    return self;
}

- (void)cancel {
    [self.task cancel];
}

- (void)pause {
    [self.task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        self->resumeData = resumeData;
    }];
}

- (void)resume {
    [self.cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        for (NSHTTPCookie *cookie in cookies) {
            [self.session.configuration.HTTPCookieStorage setCookie:cookie];
        }

        if (self->resumeData) {
            self.task = [self.session downloadTaskWithResumeData:self->resumeData];
        }

        [self.task resume];
    }];
}

- (NSString *)stripUnicodeFromFilename:(NSString *)string {
    NSCharacterSet *validFilenameSet = [NSCharacterSet characterSetWithCharactersInString:@":/\n\0"];
    NSArray<NSString *> *components = [string componentsSeparatedByCharactersInSet:validFilenameSet];
    return [components componentsJoinedByString:@""];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled && self->resumeData) {
        return;
    }

    [self.delegate download:self didCompleteWithError:error];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.bytesDownloaded = totalBytesWritten;
    self.totalBytesExpected = totalBytesExpectedToWrite > 0 ? @(totalBytesExpectedToWrite) : nil;

    [self.delegate download:self didDownloadBytes:bytesWritten];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSURL *destination = [Utility uniqueDownloadPathForFilename:self.filename];
    if (!destination) {
        [self.delegate download:self didCompleteWithError: [[NSError alloc] init]];
    } else {
        NSError *moveError;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destination error:&moveError];
        [self.delegate download:self didFinishDownloadingTo:destination];
    }
}


@end

@implementation DownloadQueue

static DownloadQueue *_downloadQueue = nil;

+ (void)initialize {
    if (self == [DownloadQueue class]) {
        _downloadQueue = [[DownloadQueue alloc] init];
        _downloadQueue.delegate = [DownloadModule sharedInstance];
    }
}

+ (DownloadQueue *) downloadQueue {
    return _downloadQueue;
}

+ (void)setDownloadQueue:(DownloadQueue *)newValue {
    _downloadQueue = newValue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _downloads = [NSMutableArray array];
    }
    return self;
}

- (BOOL)isEmpty {
    return self.downloads.count == 0;
}

- (void)enqueue:(Download *)download {
    if (self.downloads.count == 0) {
        self.combinedBytesDownloaded = 0;
        self.combinedTotalBytesExpected = @(0);
        self.lastDownloadError = nil;
    }

    [self.downloads addObject:download];
    download.delegate = self;

    if (download.totalBytesExpected && self.combinedTotalBytesExpected) {
        self.combinedTotalBytesExpected = @(self.combinedTotalBytesExpected.longLongValue + download.totalBytesExpected.longLongValue);
    } else {
        self.combinedTotalBytesExpected = nil;
    }

    [download resume];
    [self.delegate downloadQueue:self didStartDownload:download];
}

- (void)cancelAll {
    for (Download *download in self.downloads) {
        if (!download.isComplete) {
            [download cancel];
        }
    }
}

- (void)pauseAll {
    for (Download *download in self.downloads) {
        if (!download.isComplete) {
            [download pause];
        }
    }
}

- (void)resumeAll {
    for (Download *download in self.downloads) {
        if (!download.isComplete) {
            [download resume];
        }
    }
}

#pragma mark - DownloadDelegate

- (void)download:(Download *)download didCompleteWithError:(NSError *)error {
    NSUInteger index = [self.downloads indexOfObject:download];
    
    if (error && index != NSNotFound) {
        self.lastDownloadError = error;
        [self.downloads removeObjectAtIndex:index];
        
        if (self.downloads.count == 0) {
            [self.delegate downloadQueue:self didCompleteWithError:self.lastDownloadError];
        }
    }
}

- (void)download:(Download *)download didDownloadBytes:(int64_t)bytesDownloaded {
    self.combinedBytesDownloaded += bytesDownloaded;
    [self.delegate downloadQueue:self didDownloadCombinedBytes:self.combinedBytesDownloaded combinedTotalBytesExpected:self.combinedTotalBytesExpected];
}

- (void)download:(Download *)download didFinishDownloadingTo:(NSURL *)location {
    NSUInteger index = [self.downloads indexOfObject:download];
    
    if (index != NSNotFound) {
        [self.downloads removeObjectAtIndex:index];
        [self.delegate downloadQueue:self download:download didFinishDownloadingTo:location];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"fileDidDownload" object:location];
        
        if (self.downloads.count == 0) {
            [self.delegate downloadQueue:self didCompleteWithError:self.lastDownloadError];
        }
    }
}

@end

