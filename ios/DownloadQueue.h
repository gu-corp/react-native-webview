#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@protocol DownloadDelegate <NSObject>

- (void)download:(id)download didCompleteWithError:(NSError *_Nullable)error;
- (void)download:(id)download didDownloadBytes:(int64_t)bytesDownloaded;
- (void)download:(id)download didFinishDownloadingTo:(NSURL *)location;

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
@property (nonatomic, strong, readonly) NSURLRequest *request;
@property (nonatomic, readonly) NSURLSessionTaskState state;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, strong) WKHTTPCookieStore *cookieStore;

- (instancetype)initWithCookieStore:(WKHTTPCookieStore *)cookieStore preflightResponse:(NSURLResponse *)preflightResponse request:(NSURLRequest *)request;

@end

@protocol DownloadQueueDelegate <NSObject>

- (void)downloadQueue:(id)downloadQueue didStartDownload:(Download *)download;
- (void)downloadQueue:(id)downloadQueue didDownloadCombinedBytes:(int64_t)combinedBytesDownloaded combinedTotalBytesExpected:(nullable NSNumber *)combinedTotalBytesExpected;
- (void)downloadQueue:(id)downloadQueue download:(Download *)download didFinishDownloadingTo:(NSURL *)location;
- (void)downloadQueue:(id)downloadQueue didCompleteWithError:(NSError *_Nullable)error;

@end

@interface DownloadQueue : NSObject <DownloadDelegate>

@property (class, nonatomic, strong) DownloadQueue *downloadQueue;

@property (nonatomic, strong) NSMutableArray<Download *> *downloads;
@property (nonatomic, weak) id<DownloadQueueDelegate> delegate;
@property (nonatomic, readonly) BOOL isEmpty;

@property (nonatomic) int64_t combinedBytesDownloaded;
@property (nonatomic, nullable) NSNumber *combinedTotalBytesExpected;
@property (nonatomic, strong, nullable) NSError *lastDownloadError;

- (void)enqueue:(Download *)download;
- (void)cancelAll;
- (void)pauseAll;
- (void)resumeAll;

@end
