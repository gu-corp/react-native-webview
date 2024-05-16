/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@protocol DownloadDelegate <NSObject>

- (void)download:(id)download didCompleteWithError:(NSError *_Nullable)error;
- (void)download:(id)download didDownloadBytes:(int64_t)bytesDownloaded;
- (void)download:(id)download didFinishDownloadingTo:(NSURL *)location;

@end

@interface SessionInfo : NSObject

@property (nonatomic) NSInteger sessionId;
@property (nonatomic) NSInteger status;

@end

@interface Download : NSObject

@property (nonatomic, weak) id<DownloadDelegate> delegate;
@property (nonatomic) NSString *filename;
@property (nonatomic) NSString *mimeType;
@property (nonatomic) BOOL isComplete;
@property (nonatomic, nullable) NSNumber *totalBytesExpected;
@property (nonatomic) int64_t bytesDownloaded;

- (void)cancel;
- (void)pause;
- (void)resume;

@end

@interface HTTPDownload : Download <NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, strong, readonly) NSURLResponse *preflightResponse;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, readonly) NSURLSessionTaskState state;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, strong) WKHTTPCookieStore *cookieStore;
@property (nonatomic, strong) NSNumber *sessionId;
- (instancetype)initWithCookieStore:(WKHTTPCookieStore *)cookieStore preflightResponse:(NSURLResponse *)preflightResponse request:(NSURLRequest *)request;

- (instancetype)initWithSessionId: (NSNumber *)sessionId urlStr: (NSString *)str fileName: (NSString *)fileName mimeType: (NSString *)mimeType expectedFileSize: (NSNumber *)length;

@end

@protocol DownloadQueueDelegate <NSObject>

- (void)downloadQueue:(id)downloadQueue didStartDownload:(Download *)download;
- (void)downloadQueue:(id)downloadQueue didRemoveDownload:(Download *)download;
- (void)downloadQueue:(id)downloadQueue didDownloadCombinedBytes:(int64_t)combinedBytesDownloaded combinedTotalBytesExpected:(nullable NSNumber *)combinedTotalBytesExpected;
- (void)downloadQueue:(id)downloadQueue download:(Download *)download didFinishDownloadingTo:(NSURL *)location;
- (void)downloadQueue:(id)downloadQueue didCompleteWithError:(NSError *_Nullable)error;

@end

@interface DownloadQueue : NSObject <DownloadDelegate>

@property (class, nonatomic, strong) DownloadQueue *downloadQueue;
@property (class, nonatomic, strong) NSArray *downloadingList;
@property (class, nonatomic, readonly) dispatch_queue_t downloadSerialQueue;
@property (class, nonatomic, strong) NSDictionary *tempSessionInfo;

@property (nonatomic, strong) NSMutableArray<Download *> *downloads;
@property (nonatomic, weak) id<DownloadQueueDelegate> delegate;
@property (nonatomic, readonly) BOOL isEmpty;

- (void)enqueue:(Download *)download;
- (void)dequeue:(Download *)download sessionId:(NSString *)sessionId isDelete:(BOOL)isDelete;
- (void)appendSessionInfo;
- (void)cancelAll;
- (void)pauseAll;
- (void)resumeAll;
- (void)pauseDownload: (NSString *) sessionId;
- (void)resumeDownload: (NSString *) sessionId;
- (void)deleteDownload: (NSString *) sessionId;

@end
