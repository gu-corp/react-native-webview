/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "DownloadQueue.h"

// -MARK key helper
static NSString * const kSessionIdKey = @"sessionId";
static NSString * const kStatusKey = @"status";
static NSString * const kUrlKey = @"url";
static NSString * const kFileNameKey = @"filename";
static NSString * const kMimeTypeKey = @"mimeType";
static NSString * const kTotalBytesKey = @"totalBytes";
static NSString * const kBytesDownloadedKey = @"bytesDownloaded";
static NSString * const kLastSessionIndexKey = @"kLastSessionIndex";
static NSString * const kDownloadSessionInfoKey = @"kDownloadSessionInfo";
static NSString * const kDownloadFolderKey = @"downloadFolder";
static NSString * const kDownloadKey = @"downloads";
static NSString * const kUnknownKey = @"unknown";

extern NSString * const DownloadStatusDownloading;
extern NSString * const DownloadStatusPause;
extern NSString * const DownloadStatusFail;
extern NSString * const DownloadStatusNone;

@interface MIMEType : NSObject

@property (class, nonatomic, copy, readonly) NSString *bitmap;
@property (class, nonatomic, copy, readonly) NSString *CSS;
@property (class, nonatomic, copy, readonly) NSString *GIF;
@property (class, nonatomic, copy, readonly) NSString *javaScript;
@property (class, nonatomic, copy, readonly) NSString *JPEG;
@property (class, nonatomic, copy, readonly) NSString *HTML;
@property (class, nonatomic, copy, readonly) NSString *octetStream;
@property (class, nonatomic, copy, readonly) NSString *passbook;
@property (class, nonatomic, copy, readonly) NSString *PDF;
@property (class, nonatomic, copy, readonly) NSString *plainText;
@property (class, nonatomic, copy, readonly) NSString *PNG;
@property (class, nonatomic, copy, readonly) NSString *webP;
@property (class, nonatomic, copy, readonly) NSString *xHTML;

+ (BOOL)canShowInWebView:(NSString *)mimeType;
+ (NSString *)mimeTypeFromFileExtension:(NSString *)fileExtension;

@end

@interface NSString (HTMLCheck)

@property (nonatomic, readonly) BOOL isKindOfHTML;

@end

API_AVAILABLE(ios(11.0))
@interface DownloadHelper : NSObject

@property (class, nonatomic, strong) NSMutableDictionary<NSString *, NSURLRequest *> *pendingRequests;
@property (class, nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *blobData;

@property (nonatomic, strong, readonly) NSURLRequest *request;
@property (nonatomic, strong, readonly) NSURLResponse *preflightResponse;
@property (nonatomic, strong, readonly) WKHTTPCookieStore *cookieStore;

- (instancetype)initWithRequest:(NSURLRequest *)request response:(NSURLResponse *)response cookieStore:(WKHTTPCookieStore *)cookieStore canShowInWebView:(BOOL)canShowInWebView;

- (UIAlertController *)downloadAlertFromView:(UIView *)view okAction:(void (^)(id download))okAction;

@end

@interface PendingDownload : NSObject

@property (nonatomic, strong) NSURL *fileUrl;
@property (nonatomic, strong) NSURLResponse * response;

- (instancetype)initWithFileUrl: (NSURL *)fileUrl response:(NSURLResponse *)response;

@end
