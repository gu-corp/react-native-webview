/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "DownloadQueue.h"

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

