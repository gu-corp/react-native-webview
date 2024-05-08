/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
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
        
        NSString *nextSessionId = [self getNextIndexSessionInfo: _request fileName:self.filename mimeType:self.mimeType expectedFileSize:self.totalBytesExpected];
        
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:nextSessionId]
                                                 delegate:self
                                            delegateQueue:nil];

        _task = [_session downloadTaskWithRequest:_request];
        
    }
    return self;
}

- (instancetype)initWithSessionId: (NSString *)sessionId urlStr: (NSString *)str fileName: (NSString *)fileName mimeType: (NSString *)mimeType expectedFileSize: (NSNumber *)length {
    self = [super init];
    if (self) {
        self.filename = fileName;
        self.mimeType = mimeType;
        if (length) {
            self.totalBytesExpected = [length intValue] > 0 ? length : nil;
        }
        
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionId]
                                                 delegate:self
                                            delegateQueue:nil];
        _request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:str]];
        _task = [_session downloadTaskWithRequest:_request];
    }
    return self;
}

- (void) setDownloadingInfos: (NSArray *)downloadInfos {
    [DownloadQueue setDownloadingList:downloadInfos];
    [[DownloadModule sharedInstance] downloadingFileDidUpdate];
    dispatch_async([DownloadQueue downloadSerialQueue], ^{
        [Utility setDownloadSessionInfo:downloadInfos];
    });
}


- (NSString *)getNextIndexSessionInfo: (NSURLRequest *)url fileName: (NSString *)fileName mimeType: (NSString *)mimeType expectedFileSize: (NSNumber *)length {
    NSArray *sessionInfos = [Utility getDownloadSessionInfo];
    if (sessionInfos && sessionInfos.count != 0) {
        NSMutableArray *indexs = [NSMutableArray array];
        for (NSDictionary* sessionInfo in sessionInfos) {
            [indexs addObject:(NSNumber *)[sessionInfo objectForKey:@"sessionId"]];
        }
        NSNumber *maxNumber = [indexs valueForKeyPath:@"@max.intValue"];
        NSString *newSessionId = [NSString stringWithFormat:@"sessionId%d", maxNumber.intValue + 1];
        NSDictionary *new = @{@"sessionId": @(maxNumber.intValue + 1), @"status": @0, @"url": url.URL.absoluteString, @"fileName": fileName, @"mimeType": mimeType, @"expectedFileSize": length, @"downloadedSize": @0};
        NSMutableArray *copySessionInfos = [NSMutableArray arrayWithArray:sessionInfos];
        [copySessionInfos addObject:new];
        [self setDownloadingInfos:copySessionInfos];
        return newSessionId;
    }

    NSDictionary *new = @{@"sessionId": @0, @"status": @0, @"url": url.URL.absoluteString, @"fileName": fileName, @"mimeType": mimeType, @"expectedFileSize": length, @"downloadedSize": @0};
    [self setDownloadingInfos:@[new]];
    return @"sessionId0";
}

- (void) updateSessionInfo: (NSString *)sessionId downloadedSize: (NSNumber *)size status: (NSNumber *) status {
    dispatch_async([DownloadQueue downloadSerialQueue], ^{
        NSArray *sessionInfos = [DownloadQueue downloadingList];
        NSMutableArray *newSessionInfos = [NSMutableArray arrayWithArray:sessionInfos];
        for (int i = 0; i < newSessionInfos.count; i++) {
            NSDictionary *sessionInfo = newSessionInfos[i];
            NSString *sessionIdStr = [sessionInfo[@"sessionId"] stringValue];
            if ([sessionIdStr isEqual:sessionId]) {
                NSMutableDictionary *new = [NSMutableDictionary dictionaryWithDictionary:sessionInfo];
                if (size) {
                    new[@"downloadedSize"] = size;
                }
                
                if (status) {
                    new[@"status"] = status;
                }
                [newSessionInfos replaceObjectAtIndex:i withObject:new];
                break;
            }
        }
        [self setDownloadingInfos:newSessionInfos];
    });
}

- (NSString *)getSessionId: (NSURLSession *)session {
    NSString *sessionId = session.configuration.identifier;
    NSString *indexStr = [sessionId substringFromIndex: [@"sessionId" length]];
    return indexStr;
}

- (void)removeSessionInfo: (NSString *)sessionId {
    NSMutableArray *sessionInfos =  [NSMutableArray arrayWithArray: [DownloadQueue downloadingList]];
    for (NSMutableDictionary *sessionInfo in sessionInfos) {
        NSString *sessionIdStr = [sessionInfo[@"sessionId"] stringValue];
        if ([sessionIdStr isEqual:sessionId]) {
            [sessionInfos removeObject:sessionInfo];
            [[DownloadModule sharedInstance] downloadingFileItemDidSuccess];
            break;
        }
    }
    [self setDownloadingInfos:sessionInfos];
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
    if (self.cookieStore) {
        [self.cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
            for (NSHTTPCookie *cookie in cookies) {
                [self.session.configuration.HTTPCookieStorage setCookie:cookie];
            }

            if (self->resumeData) {
                self.task = [self.session downloadTaskWithResumeData:self->resumeData];
            }

            [self.task resume];
        }];
    } else {
        [self.task resume];
    }
}

- (NSString *)stripUnicodeFromFilename:(NSString *)string {
    NSCharacterSet *validFilenameSet = [NSCharacterSet characterSetWithCharactersInString:@":/\n\0"];
    NSArray<NSString *> *components = [string componentsSeparatedByCharactersInSet:validFilenameSet];
    return [components componentsJoinedByString:@""];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSString *indexStr = [self getSessionId:session];
    if (error && [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        return;
    }
    [self updateSessionInfo:indexStr downloadedSize:nil status:@(2)];
    [self.delegate download:self didCompleteWithError:error];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.bytesDownloaded = totalBytesWritten;
    self.totalBytesExpected = totalBytesExpectedToWrite > 0 ? @(totalBytesExpectedToWrite) : nil;
    NSString *indexStr = [self getSessionId:session];
    [self updateSessionInfo:indexStr downloadedSize:@(totalBytesWritten) status:nil];

    [self.delegate download:self didDownloadBytes:bytesWritten];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSURL *destination = [Utility uniqueDownloadPathForFilename:self.filename];
    NSString *indexStr = [self getSessionId:session];
    if (!destination) {
        [self updateSessionInfo:indexStr downloadedSize:nil status:@(2)];
        [self.delegate download:self didCompleteWithError: [[NSError alloc] init]];
    } else {
        NSError *moveError;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destination error:&moveError];
        [self removeSessionInfo:indexStr];
        [session invalidateAndCancel];
        [self.delegate download:self didFinishDownloadingTo:destination];
    }
}


@end

@implementation DownloadQueue

static DownloadQueue *_downloadQueue = nil;
static dispatch_queue_t _downloadSerialQueue;
static NSArray *_downloadingList;

+ (void)initialize {
    if (self == [DownloadQueue class]) {
        _downloadQueue = [[DownloadQueue alloc] init];
        _downloadQueue.delegate = [DownloadModule sharedInstance];
        _downloadSerialQueue = dispatch_queue_create("com.example.serialQueue", DISPATCH_QUEUE_SERIAL);
        _downloadingList = [NSArray array];
    }
}

+ (NSArray *)downloadingList {
    return _downloadingList;
}

+ (void)setDownloadingList: (NSArray *)downloadingList {
    _downloadingList = downloadingList;
}

+ (dispatch_queue_t)downloadSerialQueue {
    return _downloadSerialQueue;
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

- (void)dequeue:(Download *)download sessionId:(NSString *)sessionId  {
    if (self.downloads.count == 0) {
        return;
    }
    [self.downloads removeObject:download];
    if (self.downloads.count == 0) {
        self.combinedBytesDownloaded = 0;
        self.combinedTotalBytesExpected = nil;
        self.lastDownloadError = nil;
    }
    
    [download cancel];
    [(HTTPDownload *)download updateSessionInfo:sessionId downloadedSize:nil status:@1];
    
    if (download.totalBytesExpected && self.combinedTotalBytesExpected) {
        self.combinedTotalBytesExpected = @(self.combinedTotalBytesExpected.longLongValue - download.totalBytesExpected.longLongValue);
    } else {
        self.combinedTotalBytesExpected = nil;
    }
    self.combinedBytesDownloaded -= download.bytesDownloaded;
    [self.delegate downloadQueue:self didRemoveDownload:download];
    [self.delegate downloadQueue:self didDownloadCombinedBytes:self.combinedBytesDownloaded combinedTotalBytesExpected:self.combinedTotalBytesExpected];
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
        
        if (self.downloads.count == 0) {
            [self.delegate downloadQueue:self didCompleteWithError:self.lastDownloadError];
        }
    }
}

@end

