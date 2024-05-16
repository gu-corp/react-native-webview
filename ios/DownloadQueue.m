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
        
        NSNumber *nextSession = [Utility getNextIndexSessionInfo: _request fileName:self.filename mimeType:self.mimeType expectedFileSize:self.totalBytesExpected];
        _sessionId = nextSession;
        NSString *nextSessionId = [NSString stringWithFormat:@"sessionId%d", [nextSession intValue]];
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:nextSessionId]
                                                 delegate:self
                                            delegateQueue:nil];

        _task = [_session downloadTaskWithRequest:_request];
        [_task setTaskDescription: nextSessionId];
    }
    return self;
}

- (instancetype)initWithSessionId: (NSNumber *)sessionId urlStr: (NSString *)str fileName: (NSString *)fileName mimeType: (NSString *)mimeType expectedFileSize: (NSNumber *)length {
    self = [super init];
    if (self) {
        self.filename = fileName;
        self.mimeType = mimeType;
        if (length) {
            self.totalBytesExpected = [length intValue] > 0 ? length : nil;
        }
        
        self.sessionId = sessionId;
        
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier: [NSString stringWithFormat:@"sessionId%d", [sessionId intValue]]]
                                                 delegate:self
                                            delegateQueue:nil];
        _request =  [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:str]];
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
    }
}

- (NSString *)stripUnicodeFromFilename:(NSString *)string {
    NSCharacterSet *validFilenameSet = [NSCharacterSet characterSetWithCharactersInString:@":/\n\0"];
    NSArray<NSString *> *components = [string componentsSeparatedByCharactersInSet:validFilenameSet];
    return [components componentsJoinedByString:@""];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSString *indexStr = [Utility getSessionId:session];
    if (error && [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        return;
    }
    if (error) {
        [Utility updateSessionInfo:indexStr downloadedSize:nil status:@(2)];
    } else {
        [Utility removeSessionInfo: @([indexStr intValue])];
    }
    [self.delegate download:self didCompleteWithError:error];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.bytesDownloaded = totalBytesWritten;
    self.totalBytesExpected = totalBytesExpectedToWrite > 0 ? @(totalBytesExpectedToWrite) : nil;
    NSString *indexStr = [Utility getSessionId:session];
    [Utility updateSessionInfo:indexStr downloadedSize:@(totalBytesWritten) status:nil];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSURL *destination = [Utility uniqueDownloadPathForFilename:self.filename];
    NSString *indexStr = [Utility getSessionId:session];
    if (!destination) {
        [Utility updateSessionInfo:indexStr downloadedSize:nil status:@(2)];
    } else {
        NSError *moveError;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destination error:&moveError];
        [Utility removeSessionInfo:@([indexStr intValue])];
        [session invalidateAndCancel];
        [self.delegate download: self didFinishDownloadingTo:location];
    }
}


@end

@implementation DownloadQueue

static DownloadQueue *_downloadQueue = nil;
static dispatch_queue_t _downloadSerialQueue;
static NSDictionary *_tempSessionInfo;
static NSArray *_downloadingList;

+ (void)initialize {
    if (self == [DownloadQueue class]) {
        _downloadQueue = [[DownloadQueue alloc] init];
        _downloadQueue.delegate = [DownloadModule sharedInstance];
        _downloadSerialQueue = dispatch_queue_create("com.example.serialQueue", DISPATCH_QUEUE_SERIAL);
        _downloadingList = [NSArray array];
    }
}

+ (NSDictionary *)tempSessionInfo {
    return _tempSessionInfo;
}

+ (void)setTempSessionInfo: (NSDictionary *)tempSessionInfo {
    _tempSessionInfo = tempSessionInfo;
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


- (NSUInteger)indexOfDownload: (HTTPDownload *)download {
    for(int i = 0; i < _downloads.count; i++) {
        HTTPDownload *item = (HTTPDownload *)_downloads[i];
        if ([item.sessionId isEqual:download.sessionId]) {
            return i;
        }
    }
    return NSNotFound;
}

- (void)appendSessionInfo {
    if (!DownloadQueue.tempSessionInfo) {
        return;
    }
    NSArray *sessionInfos = [Utility getDownloadSessionInfo];
    NSMutableArray *copySessionInfos = [NSMutableArray arrayWithArray:sessionInfos];
    NSDictionary *new = [NSDictionary dictionaryWithDictionary:DownloadQueue.tempSessionInfo];
    [copySessionInfos addObject: new];
    [Utility setDownloadingInfos:copySessionInfos];
    NSUInteger lastIndex = [[Utility getLastSessionIndex] intValue];
    [Utility setLastSessionIndex: @(lastIndex + 1)];
    DownloadQueue.tempSessionInfo = nil;
}

- (void)enqueue:(Download *)download {
    [self.downloads addObject:download];
    download.delegate = self;
    
    HTTPDownload *_download = (HTTPDownload *)download;
    if (!_download.task) {
        [_download.session getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> * _Nonnull tasks) {
            for (NSURLSessionTask *task in tasks) {
                [task suspend];
                if ([task.taskDescription isEqual: [NSString stringWithFormat:@"sessionId%d", [_download.sessionId intValue]]]) {
                    if (_download.task) {
                        [task cancel];
                    } else {
                        _download.task = (NSURLSessionDownloadTask *)task;
                        _download.request = task.originalRequest;
                    }
                } else {
                    [task cancel];
                }
            }
            
            if (!_download.task) {
                _download.task = [_download.session downloadTaskWithRequest:_download.request];
            }
            [_download.task resume];
        }];
    } else {
        [download resume];
    }
    
}

- (void)dequeue:(Download *)download sessionId:(NSString *)sessionId isDelete:(BOOL)isDelete {
    if (self.downloads.count == 0) {
        return;
    }
    NSUInteger index = [self indexOfDownload:(HTTPDownload *)download];
    if (index != NSNotFound) {
        [self.downloads removeObjectAtIndex:index];
    }
    if (isDelete) {
        [((HTTPDownload *)download).session invalidateAndCancel];
        [Utility removeSessionInfo: @([sessionId intValue])];
    } else {
        [download cancel];
        [Utility updateSessionInfo:sessionId downloadedSize:nil status:@1];
    }
}

- (void)cancelAll {
    for (Download *download in self.downloads) {
        HTTPDownload *_download = (HTTPDownload *)download;
        [_download.session invalidateAndCancel];
        [Utility removeSessionInfo:_download.sessionId];
    }
    [self.downloads removeAllObjects];
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

- (void)pauseDownload: (NSString *) sessionId {
    if (![self isEmpty]) {
        for (HTTPDownload *download in _downloads) {
            if ([download.session.configuration.identifier isEqual: [NSString stringWithFormat:@"sessionId%@", sessionId]]) {
                [self dequeue:download sessionId:sessionId isDelete:NO];
                break;
            }
        }
    }
}

- (void)resumeDownload: (NSString *) sessionId {
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
        NSString *url = [sessionInfo objectForKey:@"url"];
        NSString *fileName = [sessionInfo objectForKey:@"fileName"];
        NSString *mimeType = [sessionInfo objectForKey:@"mimeType"];
        NSNumber *length = [sessionInfo objectForKey:@"expectedFileSize"];
        HTTPDownload *download = [[HTTPDownload alloc] initWithSessionId:@([sessionId intValue]) urlStr: url fileName:fileName mimeType:mimeType expectedFileSize:length];
        [Utility updateSessionInfo:sessionId downloadedSize:nil status:@0];
        [self enqueue: download];
    }
}

- (void)deleteDownload: (NSString *) sessionId {
    BOOL found = NO;
    for (HTTPDownload *download in _downloads) {
        if ([download.session.configuration.identifier isEqual: [NSString stringWithFormat:@"sessionId%@", sessionId]]) {
            [self dequeue:download sessionId:sessionId isDelete:YES];
            found = YES;
            break;
        }
    }
    if (!found) {
        NSString *sessionStr = [NSString stringWithFormat:@"sessionId%@", sessionId];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionStr]
                                                              delegate:nil
                                                         delegateQueue:nil];
        [session invalidateAndCancel];
        [Utility removeSessionInfo:@([sessionId intValue])];
    }
}

#pragma mark - DownloadDelegate

- (void)download:(Download *)download didCompleteWithError:(NSError *)error {
    NSUInteger index = [self indexOfDownload:(HTTPDownload *)download];
    if (index != NSNotFound) {
        [_downloads removeObjectAtIndex:index];
    }
}

- (void)download:(Download *)download didDownloadBytes:(int64_t)bytesDownloaded {
    
}

- (void)download:(Download *)download didFinishDownloadingTo:(NSURL *)location {
    NSUInteger index = [self indexOfDownload:(HTTPDownload *)download];
    if (index != NSNotFound) {
        [_downloads removeObjectAtIndex:index];
    }
}

@end

