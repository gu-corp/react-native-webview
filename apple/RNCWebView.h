/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <React/RCTView.h>
#import <React/RCTDefines.h>
#import <WebKit/WebKit.h>
#import <React/RCTBridge.h>

@class RNCWebView;

@protocol RNCWebViewDelegate <NSObject>

- (BOOL)webView:(RNCWebView *_Nonnull)webView
   shouldStartLoadForRequest:(NSMutableDictionary<NSString *, id> *_Nonnull)request
   withCallback:(RCTDirectEventBlock _Nonnull)callback;
- (RNCWebView* _Nullable)webView:(RNCWebView* _Nonnull)webView
shouldCreateNewWindow:(NSMutableDictionary<NSString *, id>* _Nonnull)request withConfiguration:(WKWebViewConfiguration* _Nonnull)configuration withCallback:(RCTDirectEventBlock _Nonnull)callback;

@end

@interface RNCWeakScriptMessageDelegate : NSObject<WKScriptMessageHandler>
@property (nonatomic, weak) id<WKScriptMessageHandler> scriptDelegate;
- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate;
@end

typedef enum {
    NoLock = 0,
    LockDirectionUp,
    LockDirectionDown,
    LockDirectionBoth
} LockScroll;

@interface RNCWebView : RCTView

@property (nonatomic, weak) id<RNCWebViewDelegate> _Nullable delegate;
@property (nonatomic, copy) NSDictionary * _Nullable source;
@property (nonatomic, assign) BOOL messagingEnabled;
@property (nonatomic, copy) NSString * _Nullable injectedJavaScript;
@property (nonatomic, copy) NSString * _Nullable injectedJavaScriptBeforeContentLoaded;
@property (nonatomic, assign) BOOL injectedJavaScriptForMainFrameOnly;
@property (nonatomic, assign) BOOL injectedJavaScriptBeforeContentLoadedForMainFrameOnly;
@property (nonatomic, assign) BOOL scrollEnabled;
@property (nonatomic, assign) BOOL sharedCookiesEnabled;
@property (nonatomic, assign) BOOL autoManageStatusBarEnabled;
@property (nonatomic, assign) BOOL pagingEnabled;
@property (nonatomic, assign) CGFloat decelerationRate;
@property (nonatomic, assign) BOOL allowsInlineMediaPlayback;
@property (nonatomic, assign) BOOL bounces;
@property (nonatomic, assign) BOOL mediaPlaybackRequiresUserAction;
#if WEBKIT_IOS_10_APIS_AVAILABLE
@property (nonatomic, assign) WKDataDetectorTypes dataDetectorTypes;
#endif
@property (nonatomic, assign) UIEdgeInsets contentInset;
@property (nonatomic, assign) BOOL automaticallyAdjustContentInsets;
@property (nonatomic, assign) BOOL keyboardDisplayRequiresUserAction;
@property (nonatomic, assign) BOOL hideKeyboardAccessoryView;
@property (nonatomic, assign) BOOL allowsBackForwardNavigationGestures;
@property (nonatomic, assign) BOOL incognito;
@property (nonatomic, assign) BOOL useSharedProcessPool;
@property (nonatomic, copy) NSString * _Nullable userAgent;
@property (nonatomic, copy) NSString * _Nullable applicationNameForUserAgent;
@property (nonatomic, assign) BOOL cacheEnabled;
@property (nonatomic, assign) BOOL javaScriptEnabled;
@property (nonatomic, assign) BOOL javaScriptCanOpenWindowsAutomatically;
@property (nonatomic, assign) BOOL allowFileAccessFromFileURLs;
@property (nonatomic, assign) BOOL allowsLinkPreview;
@property (nonatomic, assign) BOOL showsHorizontalScrollIndicator;
@property (nonatomic, assign) BOOL showsVerticalScrollIndicator;
@property (nonatomic, assign) BOOL directionalLockEnabled;
@property (nonatomic, assign) BOOL ignoreSilentHardwareSwitch;
@property (nonatomic, copy) NSString * _Nullable allowingReadAccessToURL;
@property (nonatomic, assign) BOOL scrollToTop;
@property (nonatomic, assign) BOOL openNewWindowInWebView;
@property (nonatomic, assign) LockScroll lockScroll;
@property (nonatomic, assign) CGPoint adjustOffset;
@property (nonatomic, copy) NSArray<NSString *> * _Nullable contentRuleLists;
@property (nonatomic, assign) BOOL pullToRefreshEnabled;
#if !TARGET_OS_OSX
@property (nonatomic, weak) UIRefreshControl * refreshControl;
#endif

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 /* iOS 13 */
@property (nonatomic, assign) WKContentMode contentMode;
#endif

- (instancetype _Nonnull )initWithConfiguration:(WKWebViewConfiguration*_Nonnull)configuration from:(RNCWebView*_Nonnull)parentView;
+ (void)setClientAuthenticationCredential:(nullable NSURLCredential*)credential;
+ (void)setCustomCertificatesForHost:(nullable NSDictionary *)certificates;
- (void)postMessage:(NSString *_Nullable)message;
- (void)injectJavaScript:(NSString *_Nullable)script;
- (void)goForward;
- (void)goBack;
- (void)reload;
- (void)stopLoading;
#if !TARGET_OS_OSX
- (void)addPullToRefreshControl;
- (void)pullToRefresh:(UIRefreshControl *)refreshControl;
#endif

- (void)evaluateJavaScript:(nonnull NSString *)javaScriptString completionHandler:(void (^_Nonnull)(id _Nullable, NSError* _Nullable error))completionHandler;
- (void)findInPage:(nonnull NSString *)searchString completed:(void (^_Nonnull)(NSInteger count))callback;
- (void)captureScreen:(void (^_Nonnull)(NSString* _Nullable path))callback;
- (void)capturePage:(void (^_Nonnull)(NSString* _Nullable path))callback;
- (void)printContent;

@end
