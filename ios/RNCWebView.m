/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RNCWKProcessPoolManager.h"
#import "RNCWebView.h"
#import "objc/runtime.h"
#import <CommonCrypto/CommonDigest.h>
#import <React/RCTAutoInsetsProtocol.h>
#import <React/RCTConvert.h>
#import <UIKit/UIKit.h>

#import "DownloadHelper.h"
#import "DownloadModule.h"
#import "DownloadQueue.h"
#import "PassBookHelper.h"
#import "RCTAutoInsetsProtocol.h"
#import "RCTComponent.h"
#import "Utility.h"
#import "WKWebView+BrowserHack.h"
#import "WKWebView+Capture.h"
#import "WKWebView+Highlight.h"
#import "react_native_webview-Swift.h"
#import <WebKit/WebKit.h>
#import "RCTEngineAdBlock.h"
#define LocalizeString(key)                                                    \
  (NSLocalizedStringFromTableInBundle(key, @"Localizable", resourceBundle, nil))

static NSTimer *keyboardTimer;
static NSString *const MessageHandlerName = @"ReactNativeWebView";
static NSString *const PrintScriptHandler = @"printScriptHandler";
static NSString *const RequestBlockingScript = @"RequestBlockingScript";
static NSURLCredential *clientAuthenticationCredential;
static NSDictionary *customCertificatesForHost;

// runtime trick to remove WKWebView keyboard default toolbar
// see:
// http://stackoverflow.com/questions/19033292/ios-7-uiwebview-keyboard-issue/19042279#19042279
@interface _SwizzleHelperWK : UIView
@property(nonatomic, copy) WKWebView *webView;
@end
@implementation _SwizzleHelperWK
- (id)inputAccessoryView {
  if (_webView == nil) {
    return nil;
  }

  if ([_webView respondsToSelector:@selector(inputAssistantItem)]) {
    UITextInputAssistantItem *inputAssistantItem =
        [_webView inputAssistantItem];
    inputAssistantItem.leadingBarButtonGroups = @[];
    inputAssistantItem.trailingBarButtonGroups = @[];
  }
  return nil;
}
@end

@interface RNCWebView () <WKUIDelegate, WKNavigationDelegate,
                          WKScriptMessageHandler,
                          WKScriptMessageHandlerWithReply, UIScrollViewDelegate,
                          RCTAutoInsetsProtocol>
@property(nonatomic, copy) RCTDirectEventBlock onLoadingStart;
@property(nonatomic, copy) RCTDirectEventBlock onLoadingFinish;
@property(nonatomic, copy) RCTDirectEventBlock onLoadingError;
@property(nonatomic, copy) RCTDirectEventBlock onLoadingProgress;
@property(nonatomic, copy) RCTDirectEventBlock onShouldStartLoadWithRequest;
@property(nonatomic, copy) RCTDirectEventBlock onShouldCreateNewWindow;
@property(nonatomic, copy) RCTDirectEventBlock onNavigationStateChange;
@property(nonatomic, copy) RCTDirectEventBlock onHttpError;
@property(nonatomic, copy) RCTDirectEventBlock onMessage;
@property(nonatomic, copy) RCTDirectEventBlock onGetFavicon;
@property(nonatomic, copy) RCTDirectEventBlock onFileDownload;
@property(nonatomic, copy) RCTDirectEventBlock onScroll;
@property(nonatomic, copy) RCTDirectEventBlock onWebViewClosed;
@property(nonatomic, copy) RCTDirectEventBlock onContentProcessDidTerminate;
@property(nonatomic, copy) RCTDirectEventBlock handleRequestBlockingScript;
@property(nonatomic, copy) WKWebView *webView;
@end

@implementation RNCWebView {
  UIColor *_savedBackgroundColor;
  BOOL _savedHideKeyboardAccessoryView;
  BOOL _savedKeyboardDisplayRequiresUserAction;

  // Workaround for StatusBar appearance bug for iOS 12
  // https://github.com/react-native-community/react-native-webview/issues/62
  BOOL _isFullScreenVideoOpen;
  UIStatusBarStyle _savedStatusBarStyle;
  BOOL _savedStatusBarHidden;
    

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&                                \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000 /* __IPHONE_11_0 */
  UIScrollViewContentInsetAdjustmentBehavior
      _savedContentInsetAdjustmentBehavior;
#endif

  BOOL longPress;
  NSBundle *resourceBundle;
  WKWebViewConfiguration *wkWebViewConfig;
  // Youtube Videos Without Ads
  WKUserScript *scriptYoutubeAdblock;
  // Picture-in-picture feature on Youtube page
  WKUserScript *scriptYoutubePictureInPicture;
  WKUserScript *scriptNightMode;
  WKUserScript *scriptRequestBlocking;
  Engine *engine;
  WKNavigationAction *navigationActionGlobal;

  CGPoint lastOffset;
  BOOL decelerating;
  BOOL dragging;
  BOOL scrollingToTop;
  BOOL initiated;
  BOOL isAddScriptByTypes;
}

- (void)webViewDidClose:(WKWebView *)webView {
  if (_onWebViewClosed) {
    _onWebViewClosed([self baseEvent]);
  }
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    super.backgroundColor = [UIColor clearColor];
    _bounces = YES;
    _scrollEnabled = YES;
    _showsHorizontalScrollIndicator = YES;
    _showsVerticalScrollIndicator = YES;
    _directionalLockEnabled = YES;
    _automaticallyAdjustContentInsets = YES;
    _contentInset = UIEdgeInsetsZero;
    _savedKeyboardDisplayRequiresUserAction = YES;
    _savedStatusBarStyle = RCTSharedApplication().statusBarStyle;
    _savedStatusBarHidden = RCTSharedApplication().statusBarHidden;

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&                                \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000 /* __IPHONE_11_0 */
    _savedContentInsetAdjustmentBehavior =
        UIScrollViewContentInsetAdjustmentNever;
#endif
  }

  if (@available(iOS 12.0, *)) {
    // Workaround for a keyboard dismissal bug present in iOS 12
    // https://openradar.appspot.com/radar?id=5018321736957952
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(keyboardWillHide)
               name:UIKeyboardWillHideNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(keyboardWillShow)
               name:UIKeyboardWillShowNotification
             object:nil];

    // Workaround for StatusBar appearance bug for iOS 12
    // https://github.com/react-native-community/react-native-webview/issues/62
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(showFullScreenVideoStatusBars:)
               name:UIWindowDidBecomeVisibleNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(hideFullScreenVideoStatusBars)
               name:UIWindowDidBecomeHiddenNotification
             object:nil];
  }

  NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"Settings"
                                                         ofType:@"bundle"];
  resourceBundle = [NSBundle bundleWithPath:bundlePath];
  initiated = NO;

  return self;
}

- (id)initWithConfiguration:(WKWebViewConfiguration *)configuration
                       from:(RNCWebView *)parentView {
  if (self = [self initWithFrame:parentView.frame]) {
    wkWebViewConfig = configuration;
    [self setupConfiguration:parentView];
    _webView = [[WKWebView alloc] initWithFrame:self.bounds
                                  configuration:wkWebViewConfig];
    _webView.UIDelegate = self;
    _webView.navigationDelegate = self;
    _webView.inspectable = YES; // to inspect webview for ios 16.4+
    if (parentView.userAgent) {
      _webView.customUserAgent = parentView.userAgent;
    }
    if (@available(iOS 14.0, *)) {
        if(engine == NULL){
            Engine *e = [[Engine alloc] init];
            engine = e;
        }
    }
  }
  return self;
}

- (void)setupConfiguration:(RNCWebView *)sender {
  if (sender.incognito) {
    wkWebViewConfig.websiteDataStore =
        [WKWebsiteDataStore nonPersistentDataStore];
  } else if (sender.cacheEnabled) {
    wkWebViewConfig.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
  }
  if (sender.useSharedProcessPool) {
    wkWebViewConfig.processPool =
        [[RNCWKProcessPoolManager sharedManager] sharedProcessPool];
  }
  wkWebViewConfig.userContentController = [WKUserContentController new];

  if (sender.messagingEnabled) {
    [wkWebViewConfig.userContentController
        addScriptMessageHandler:self
                           name:MessageHandlerName];

    NSString *source = [NSString
        stringWithFormat:
            @"window.%@ = {"
             "  postMessage: function (data) {"
             "    window.webkit.messageHandlers.%@.postMessage(String(data));"
             "  }"
             "};",
            MessageHandlerName, MessageHandlerName];

    WKUserScript *script = [[WKUserScript alloc]
          initWithSource:source
           injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:YES];
    [wkWebViewConfig.userContentController addUserScript:script];
  }

  // override window.print script
  [wkWebViewConfig.userContentController
      addScriptMessageHandler:self
                         name:PrintScriptHandler];
  NSString *sourcePrintScript = [NSString
      stringWithFormat:
          @"window.print = function () {"
           "    window.webkit.messageHandlers.%@.postMessage(String());"
           "};",
          PrintScriptHandler];

  WKUserScript *scriptPrint = [[WKUserScript alloc]
        initWithSource:sourcePrintScript
         injectionTime:WKUserScriptInjectionTimeAtDocumentStart
      forMainFrameOnly:NO];
  [wkWebViewConfig.userContentController addUserScript:scriptPrint];

  wkWebViewConfig.allowsInlineMediaPlayback = sender.allowsInlineMediaPlayback;

  // feature: zooming webpage with any value of viewport = "... user-scalable=
  // no/yes " Enables Zoom in website by ignoring their javascript based
  // viewport Scale limits.
  wkWebViewConfig.ignoresViewportScaleLimits = true;

#if WEBKIT_IOS_10_APIS_AVAILABLE
  wkWebViewConfig.mediaTypesRequiringUserActionForPlayback =
      _mediaPlaybackRequiresUserAction ? WKAudiovisualMediaTypeAll
                                       : WKAudiovisualMediaTypeNone;
  wkWebViewConfig.dataDetectorTypes = _dataDetectorTypes;
#else
  if (_mediaPlaybackRequiresUserAction) {
    wkWebViewConfig.mediaPlaybackRequiresUserAction =
        _mediaPlaybackRequiresUserAction;
  }
#endif

  if (sender.applicationNameForUserAgent) {
    wkWebViewConfig.applicationNameForUserAgent = [NSString
        stringWithFormat:@"%@ %@", wkWebViewConfig.applicationNameForUserAgent,
                         sender.applicationNameForUserAgent];
  }

  if (sender.sharedCookiesEnabled) {
    // More info to sending cookies with WKWebView
    // https://stackoverflow.com/questions/26573137/can-i-set-the-cookies-to-be-used-by-a-wkwebview/26577303#26577303
    if (@available(iOS 11.0, *)) {
      // Set Cookies in iOS 11 and above, initialize websiteDataStore before
      // setting cookies See also
      // https://forums.developer.apple.com/thread/97194 check if
      // websiteDataStore has not been initialized before
      if (!sender.incognito && !sender.cacheEnabled) {
        wkWebViewConfig.websiteDataStore =
            [WKWebsiteDataStore nonPersistentDataStore];
      }
      for (NSHTTPCookie *cookie in
           [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        [wkWebViewConfig.websiteDataStore.httpCookieStore setCookie:cookie
                                                  completionHandler:nil];
      }
    } else {
      NSMutableString *script = [NSMutableString string];

      // Clear all existing cookies in a direct called function. This ensures
      // that no javascript error will break the web content javascript. We keep
      // this code here, if someone requires that Cookies are also removed
      // within the the WebView and want to extends the current
      // sharedCookiesEnabled option with an additional property. Generates JS:
      // document.cookie = "key=; Expires=Thu, 01 Jan 1970 00:00:01 GMT;" for
      // each cookie which is already available in the WebView context.
      /*
      [script appendString:@"(function () {\n"];
      [script appendString:@"  var cookies = document.cookie.split('; ');\n"];
      [script appendString:@"  for (var i = 0; i < cookies.length; i++) {\n"];
      [script appendString:@"    if (cookies[i].indexOf('=') !== -1) {\n"];
      [script appendString:@"      document.cookie = cookies[i].split('=')[0] +
      '=; Expires=Thu, 01 Jan 1970 00:00:01 GMT';\n"]; [script appendString:@"
      }\n"]; [script appendString:@"  }\n"]; [script appendString:@"})();\n\n"];
      */

      // Set cookies in a direct called function. This ensures that no
      // javascript error will break the web content javascript.
      // Generates JS: document.cookie = "key=value; Path=/; Expires=Thu, 01 Jan
      // 20xx 00:00:01 GMT;"
      // for each cookie which is available in the application context.
      [script appendString:@"(function () {\n"];
      for (NSHTTPCookie *cookie in
           [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        [script appendFormat:@"document.cookie = %@ + '=' + %@",
                             RCTJSONStringify(cookie.name, NULL),
                             RCTJSONStringify(cookie.value, NULL)];
        if (cookie.path) {
          [script appendFormat:@" + '; Path=' + %@",
                               RCTJSONStringify(cookie.path, NULL)];
        }
        if (cookie.expiresDate) {
          [script appendFormat:@" + '; Expires=' + new Date(%f).toUTCString()",
                               cookie.expiresDate.timeIntervalSince1970 * 1000];
        }
        [script appendString:@";\n"];
      }
      [script appendString:@"})();\n"];

      WKUserScript *cookieInScript = [[WKUserScript alloc]
            initWithSource:script
             injectionTime:WKUserScriptInjectionTimeAtDocumentStart
          forMainFrameOnly:YES];
      [wkWebViewConfig.userContentController addUserScript:cookieInScript];
    }
  }

  if (sender.injectedJavaScriptBeforeDocumentLoad) {
    WKUserScript *script = [[WKUserScript alloc]
          initWithSource:sender.injectedJavaScriptBeforeDocumentLoad
           injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:YES];
    [wkWebViewConfig.userContentController addUserScript:script];
  }

  if (sender.adBlockAllowList) {
    _adBlockAllowList = [NSArray arrayWithArray:sender.adBlockAllowList];
  }
    
  if (sender.contentRuleLists) {
    if (@available(iOS 14.0, *)) {
        if(engine!= NULL){
//            [engine getScripts:sender decidePolicyFor:navigationActionGlobal preferences:wkWebViewConfig.preferences completionHandler:^(NSString *status) {
//                isAddScriptByTypes = @(YES);
//                NSLog(@"%@", status);
//            }];
            
            [engine configRulesWithUserContentController:wkWebViewConfig.userContentController completionHandler:^(NSSet<WKContentRuleList *> *contentRuleList, NSError *error) {
                if (!error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (WKContentRuleList* rule in contentRuleList){
                            [self->wkWebViewConfig.userContentController addContentRuleList:rule];
                        }
                    });
                }
            }];
        }else{
            NSLog(@"engine null");
        }
        if (@available(iOS 14.0, *)) {
            WKContentWorld *scriptSandbox = [WKContentWorld pageWorld];
            [wkWebViewConfig.userContentController
                addScriptMessageHandlerWithReply:self
                                    contentWorld:scriptSandbox
                                            name:RequestBlockingScript];
            NSString *injectSecurityToken = [NSString
                stringWithFormat:
                    @"window.%@ = function (data) {"
                     "  return "
                     "    window.webkit.messageHandlers.%@.postMessage(String(data));"
                     "};",
                    RequestBlockingScript, RequestBlockingScript];

            scriptRequestBlocking = [[WKUserScript alloc]
                  initWithSource:injectSecurityToken
                   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                forMainFrameOnly:YES];

            [wkWebViewConfig.userContentController addUserScript:scriptRequestBlocking];
        }
        
    } else {
      _contentRuleLists = [NSArray arrayWithArray:sender.contentRuleLists];
      WKContentRuleListStore *contentRuleListStore =
          WKContentRuleListStore.defaultStore;

      [contentRuleListStore getAvailableContentRuleListIdentifiers:^(
                                NSArray<NSString *> *identifiers) {
        for (NSString *identifier in identifiers) {
          if ([sender.contentRuleLists containsObject:identifier]) {
            [contentRuleListStore
             lookUpContentRuleListForIdentifier:identifier completionHandler:^( WKContentRuleList *contentRuleList, NSError *error) {
                if (!error) {
                    [wkWebViewConfig.userContentController addContentRuleList:contentRuleList]; }
            }];
          }
        }
      }];
    }
  }
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 * See
 * https://stackoverflow.com/questions/25713069/why-is-wkwebview-not-opening-links-with-target-blank/25853806#25853806
 * for details.
 */
- (WKWebView *)webView:(WKWebView *)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
               forNavigationAction:(WKNavigationAction *)navigationAction
                    windowFeatures:(WKWindowFeatures *)windowFeatures {
  NSString *scheme = navigationAction.request.URL.scheme;
  navigationActionGlobal = navigationAction;
  if ((navigationAction.targetFrame.isMainFrame || _openNewWindowInWebView) &&
      ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] ||
       [scheme isEqualToString:@"about"])) {
    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary:@{
      @"url" : (navigationAction.request.URL).absoluteString,
      @"navigationType" : @(navigationAction.navigationType)
    }];
    RNCWebView *wkWebView = [self.delegate webView:self
                             shouldCreateNewWindow:event
                                 withConfiguration:configuration
                                      withCallback:_onShouldCreateNewWindow];
    if (!wkWebView) {
      [webView loadRequest:navigationAction.request];
    } else {
      return wkWebView.webview;
    }
  } /* else if (!navigationAction.targetFrame.isMainFrame) {
     [webView loadRequest:navigationAction.request];
   }*/
  else {
    UIApplication *app = [UIApplication sharedApplication];
    NSURL *url = navigationAction.request.URL;
    if ([app canOpenURL:url]) {
      [app openURL:url];
    }
  }
  return nil;
}

- (void)didMoveToWindow {
  if (self.window != nil && !initiated) {
    initiated = YES;
    if (wkWebViewConfig == nil) {
      wkWebViewConfig = [WKWebViewConfiguration new];
      WKPreferences *prefs = [[WKPreferences alloc] init];
      // Override javaScriptEnabled of configuration when create new window
      // would cause unexpected behaviour
      if (!_javaScriptEnabled) {
        prefs.javaScriptEnabled = NO;
        wkWebViewConfig.preferences = prefs;
      }
      [self setupConfiguration:self];
      _webView = [[WKWebView alloc] initWithFrame:self.bounds
                                    configuration:wkWebViewConfig];
      _webView.inspectable = YES; // to inspect webview for ios 16.4+
    }
    if (@available(iOS 14.0, *)) {
        if(engine == NULL){
            Engine *e =  [[Engine alloc] init];
            engine = e;
        }
    }
    [self setBackgroundColor:_savedBackgroundColor];
    _webView.scrollView.delegate = self;
    _webView.UIDelegate = self;
    _webView.navigationDelegate = self;
    _webView.scrollView.scrollEnabled = _scrollEnabled;
    _webView.scrollView.pagingEnabled = _pagingEnabled;
    _webView.scrollView.bounces = _bounces;
    _webView.scrollView.showsHorizontalScrollIndicator =
        _showsHorizontalScrollIndicator;
    _webView.scrollView.showsVerticalScrollIndicator =
        _showsVerticalScrollIndicator;
    _webView.scrollView.directionalLockEnabled = _directionalLockEnabled;
    _webView.allowsLinkPreview = _allowsLinkPreview;
    [_webView
        addObserver:self
         forKeyPath:@"estimatedProgress"
            options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
            context:nil];
    [_webView addObserver:self
               forKeyPath:@"title"
                  options:NSKeyValueObservingOptionNew
                  context:nil];
    [_webView addObserver:self
               forKeyPath:@"loading"
                  options:NSKeyValueObservingOptionNew
                  context:nil];
    [_webView addObserver:self
               forKeyPath:@"canGoBack"
                  options:NSKeyValueObservingOptionNew
                  context:nil];
    [_webView addObserver:self
               forKeyPath:@"canGoForward"
                  options:NSKeyValueObservingOptionNew
                  context:nil];
    [_webView addObserver:self
               forKeyPath:@"URL"
                  options:NSKeyValueObservingOptionNew
                  context:nil];
    _webView.allowsBackForwardNavigationGestures =
        _allowsBackForwardNavigationGestures;

    // add pull down to reload feature in scrollview of webview
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self
                       action:@selector(handleRefresh:)
             forControlEvents:UIControlEventValueChanged];
    [_webView.scrollView addSubview:refreshControl];

    if (_userAgent) {
      _webView.customUserAgent = _userAgent;
    }
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&                                \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000 /* __IPHONE_11_0 */
    if ([_webView.scrollView
            respondsToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
      _webView.scrollView.contentInsetAdjustmentBehavior =
          _savedContentInsetAdjustmentBehavior;
    }
#endif

    UILongPressGestureRecognizer *longGesture =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(longPressed:)];
    longGesture.delegate = self;
    [_webView addGestureRecognizer:longGesture];

    [self addSubview:_webView];
    [self setHideKeyboardAccessoryView:_savedHideKeyboardAccessoryView];
    [self setKeyboardDisplayRequiresUserAction:
              _savedKeyboardDisplayRequiresUserAction];
    [self visitSource];
  }
}

// Update webview property when the component prop changes.
- (void)setAllowsBackForwardNavigationGestures:
    (BOOL)allowsBackForwardNavigationGestures {
  _allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures;
  _webView.allowsBackForwardNavigationGestures =
      _allowsBackForwardNavigationGestures;
}

- (void)removeFromSuperview {
  if (_webView) {
    [_webView.configuration.userContentController
        removeScriptMessageHandlerForName:MessageHandlerName];
    [_webView.configuration.userContentController
        removeScriptMessageHandlerForName:RequestBlockingScript];
    [_webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [_webView removeObserver:self forKeyPath:@"title"];
    [_webView removeObserver:self forKeyPath:@"loading"];
    [_webView removeObserver:self forKeyPath:@"canGoBack"];
    [_webView removeObserver:self forKeyPath:@"canGoForward"];
    [_webView removeObserver:self forKeyPath:@"URL"];
    [_webView removeFromSuperview];
    _webView.scrollView.delegate = nil;
    _webView = nil;
  }

  [super removeFromSuperview];
}

- (void)showFullScreenVideoStatusBars:(NSNotification *)notification {
  if ([notification.object class] != [UIWindow class]) {
    return;
  }
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  _isFullScreenVideoOpen = YES;
  RCTUnsafeExecuteOnMainQueueSync(^{
    [RCTSharedApplication() setStatusBarStyle:UIStatusBarStyleLightContent
                                     animated:YES];
  });
#pragma clang diagnostic pop
}

- (void)hideFullScreenVideoStatusBars {
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  _isFullScreenVideoOpen = NO;
  RCTUnsafeExecuteOnMainQueueSync(^{
    [RCTSharedApplication() setStatusBarHidden:self->_savedStatusBarHidden
                                      animated:YES];
    [RCTSharedApplication() setStatusBarStyle:self->_savedStatusBarStyle
                                     animated:YES];
  });
#pragma clang diagnostic pop
}

- (void)keyboardWillHide {
  keyboardTimer =
      [NSTimer scheduledTimerWithTimeInterval:0
                                       target:self
                                     selector:@selector(keyboardDisplacementFix)
                                     userInfo:nil
                                      repeats:false];
  [[NSRunLoop mainRunLoop] addTimer:keyboardTimer forMode:NSRunLoopCommonModes];
}
- (void)keyboardWillShow {
  if (keyboardTimer != nil) {
    [keyboardTimer invalidate];
  }
}
- (void)keyboardDisplacementFix {
  // Additional viewport checks to prevent unintentional scrolls
  UIScrollView *scrollView = self.webView.scrollView;
  double maxContentOffset =
      scrollView.contentSize.height - scrollView.frame.size.height;
  if (maxContentOffset < 0) {
    maxContentOffset = 0;
  }
  if (scrollView.contentOffset.y > maxContentOffset) {
    // https://stackoverflow.com/a/9637807/824966
    [UIView animateWithDuration:.25
                     animations:^{
                       scrollView.contentOffset =
                           CGPointMake(0, maxContentOffset);
                     }];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  if ([keyPath isEqual:@"estimatedProgress"] && object == self.webView) {
    if (_onLoadingProgress) {
      NSMutableDictionary<NSString *, id> *event = [self baseEvent];
      [event addEntriesFromDictionary:@{
        @"progress" : [NSNumber numberWithDouble:self.webView.estimatedProgress]
      }];
      _onLoadingProgress(event);
    }
  } else if ([keyPath isEqualToString:@"title"] ||
             [keyPath isEqualToString:@"loading"] ||
             [keyPath isEqualToString:@"canGoBack"] ||
             [keyPath isEqualToString:@"canGoForward"] ||
             [keyPath isEqualToString:@"URL"]) {
    if (_onNavigationStateChange) {
      _onNavigationStateChange([self baseEvent]);
    }
  } else {
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
  }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
  _savedBackgroundColor = backgroundColor;
  if (_webView == nil) {
    return;
  }

  CGFloat alpha = CGColorGetAlpha(backgroundColor.CGColor);
  self.opaque = _webView.opaque = (alpha == 1.0);
  _webView.scrollView.backgroundColor = backgroundColor;
  _webView.backgroundColor = backgroundColor;
}

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&                                \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000 /* __IPHONE_11_0 */
- (void)setContentInsetAdjustmentBehavior:
    (UIScrollViewContentInsetAdjustmentBehavior)behavior {
  _savedContentInsetAdjustmentBehavior = behavior;
  if (_webView == nil) {
    return;
  }

  if ([_webView.scrollView
          respondsToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
    CGPoint contentOffset = _webView.scrollView.contentOffset;
    _webView.scrollView.contentInsetAdjustmentBehavior = behavior;
    _webView.scrollView.contentOffset = contentOffset;
  }
}
#endif

/**
 * This method is called whenever JavaScript running within the web view calls:
 *   - window.webkit.messageHandlers[MessageHandlerName].postMessage
 *   - window.webkit.messageHandlers[PrintScriptHandler].postMessage
 */
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
  if (message.name == MessageHandlerName) {
    if (_onMessage != nil) {
      NSMutableDictionary<NSString *, id> *event = [self baseEvent];
      [event addEntriesFromDictionary:@{@"data" : message.body}];
      _onMessage(event);
    }
  } else if (message.name == PrintScriptHandler) {
    [self printContent];
  }
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
                 replyHandler:
                     (void (^)(id _Nullable reply,
                               NSString *_Nullable errorMessage))replyHandler {

  if (message.name == RequestBlockingScript) {
    [self handleRequestBlocking:message.body replyHandler:replyHandler];
  }
}

- (void)handleRequestBlocking:(id)body replyHandler: (void (^)(id _Nullable reply, NSString *_Nullable errorMessage))replyHandler {
    NSData *jsonData = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if (error) {
        NSLog(@"Failed to parse JSON: %@", error.localizedDescription);
    } else {
        NSString *securityToken = jsonDict[@"securityToken"];
        NSDictionary *data = jsonDict[@"data"];
        NSURL *requestURL = [NSURL URLWithString:data[@"resourceURL"]];
        NSURL *sourceURL = [NSURL URLWithString:data[@"sourceURL"]];
        NSString *resourceType = data[@"resourceType"];
        NSString *requestHost = requestURL.host;
        
        [engine checkBlockingWithRequestURL:requestURL sourceURL:sourceURL resourceType:resourceType replyHandler:replyHandler];
    }
}

- (void)setSource:(NSDictionary *)source {
  if (![_source isEqualToDictionary:source]) {
    _source = [source copy];

    if (_webView != nil) {
      [self visitSource];
    }
  }
}

- (void)setUserAgent:(NSString *)userAgent {
  _userAgent = userAgent;
  if (_webView != nil) {
    _webView.customUserAgent = userAgent;
  }
}

- (void)setDownloadConfig:(NSDictionary *)downloadConfig {
  _downloadConfig = downloadConfig;
  [Utility setDownloadConfig:downloadConfig];
}

- (void)setAllowingReadAccessToURL:(NSString *)allowingReadAccessToURL {
  if (![_allowingReadAccessToURL isEqualToString:allowingReadAccessToURL]) {
    _allowingReadAccessToURL = [allowingReadAccessToURL copy];

    if (_webView != nil) {
      [self visitSource];
    }
  }
}

- (void)setAdditionalUserAgent:(NSArray<NSDictionary *> *)additionalUserAgent {
  _additionalUserAgent = additionalUserAgent;
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
  _contentInset = contentInset;
  [RCTView autoAdjustInsetsForView:self
                    withScrollView:_webView.scrollView
                      updateOffset:NO];
}

- (void)refreshContentInset {
  [RCTView autoAdjustInsetsForView:self
                    withScrollView:_webView.scrollView
                      updateOffset:YES];
}

- (void)visitSource {
  // Check for a static html source first
  NSString *html = [RCTConvert NSString:_source[@"html"]];
  if (html) {
    NSURL *baseURL = [RCTConvert NSURL:_source[@"baseUrl"]];
    if (!baseURL) {
      baseURL = [NSURL URLWithString:@"about:blank"];
    }
    [_webView loadHTMLString:html baseURL:baseURL];
    return;
  }

  // Some child windows (created by createWebViewWithConfiguration)
  // open about:blank at first before navigate to upcoming request,
  // the method may run before the upcoming request is navigated
  // and will cause error "about:blank is not a valid file URL"
  // If you want to open a blank page, you should pass source = { html: '' }
  NSString *uri = [RCTConvert NSString:_source[@"uri"]];
  if ([uri isEqualToString:@"about:blank"]) {
    return;
  }

  NSURLRequest *request = [self requestForSource:_source];
  // Because of the way React works, as pages redirect, we actually end up
  // passing the redirect urls back here, so we ignore them if trying to load
  // the same url. We'll expose a call to 'reload' to allow a user to load
  // the existing page.
  if ([request.URL isEqual:_webView.URL]) {
    return;
  }
  if (!request.URL) {
    // Clear the webview
    [_webView loadHTMLString:@"" baseURL:nil];
    return;
  }
  if (request.URL.host) {
    [_webView loadRequest:request];
  } else {
    NSURL *readAccessUrl = _allowingReadAccessToURL
                               ? [RCTConvert NSURL:_allowingReadAccessToURL]
                               : request.URL;
    [_webView loadFileURL:request.URL allowingReadAccessToURL:readAccessUrl];
  }
}

- (void)setKeyboardDisplayRequiresUserAction:
    (BOOL)keyboardDisplayRequiresUserAction {
  if (_webView == nil) {
    _savedKeyboardDisplayRequiresUserAction = keyboardDisplayRequiresUserAction;
    return;
  }

  if (_savedKeyboardDisplayRequiresUserAction == true) {
    return;
  }

  UIView *subview;

  for (UIView *view in _webView.scrollView.subviews) {
    if ([[view.class description] hasPrefix:@"WK"])
      subview = view;
  }

  if (subview == nil)
    return;

  Class class = subview.class;

  NSOperatingSystemVersion iOS_11_3_0 = (NSOperatingSystemVersion){11, 3, 0};
  NSOperatingSystemVersion iOS_12_2_0 = (NSOperatingSystemVersion){12, 2, 0};
  NSOperatingSystemVersion iOS_13_0_0 = (NSOperatingSystemVersion){13, 0, 0};

  Method method;
  IMP override;

  if ([[NSProcessInfo processInfo]
          isOperatingSystemAtLeastVersion:iOS_13_0_0]) {
    // iOS 13.0.0 - Future
    SEL selector =
        sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:"
                   "activityStateChanges:userObject:");
    method = class_getInstanceMethod(class, selector);
    IMP original = method_getImplementation(method);
    override = imp_implementationWithBlock(
        ^void(id me, void *arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
          ((void (*)(id, SEL, void *, BOOL, BOOL, BOOL, id))original)(
              me, selector, arg0, TRUE, arg2, arg3, arg4);
        });
  } else if ([[NSProcessInfo processInfo]
                 isOperatingSystemAtLeastVersion:iOS_12_2_0]) {
    // iOS 12.2.0 - iOS 13.0.0
    SEL selector =
        sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:"
                   "changingActivityState:userObject:");
    method = class_getInstanceMethod(class, selector);
    IMP original = method_getImplementation(method);
    override = imp_implementationWithBlock(
        ^void(id me, void *arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
          ((void (*)(id, SEL, void *, BOOL, BOOL, BOOL, id))original)(
              me, selector, arg0, TRUE, arg2, arg3, arg4);
        });
  } else if ([[NSProcessInfo processInfo]
                 isOperatingSystemAtLeastVersion:iOS_11_3_0]) {
    // iOS 11.3.0 - 12.2.0
    SEL selector =
        sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:"
                   "changingActivityState:userObject:");
    method = class_getInstanceMethod(class, selector);
    IMP original = method_getImplementation(method);
    override = imp_implementationWithBlock(
        ^void(id me, void *arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
          ((void (*)(id, SEL, void *, BOOL, BOOL, BOOL, id))original)(
              me, selector, arg0, TRUE, arg2, arg3, arg4);
        });
  } else {
    // iOS 9.0 - 11.3.0
    SEL selector = sel_getUid(
        "_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:");
    method = class_getInstanceMethod(class, selector);
    IMP original = method_getImplementation(method);
    override = imp_implementationWithBlock(^void(id me, void *arg0, BOOL arg1,
                                                 BOOL arg2, id arg3) {
      ((void (*)(id, SEL, void *, BOOL, BOOL, id))original)(me, selector, arg0,
                                                            TRUE, arg2, arg3);
    });
  }

  method_setImplementation(method, override);
}

- (void)setHideKeyboardAccessoryView:(BOOL)hideKeyboardAccessoryView {
  if (_webView == nil) {
    _savedHideKeyboardAccessoryView = hideKeyboardAccessoryView;
    return;
  }

  if (_savedHideKeyboardAccessoryView == false) {
    return;
  }

  UIView *subview;

  for (UIView *view in _webView.scrollView.subviews) {
    if ([[view.class description] hasPrefix:@"WK"])
      subview = view;
  }

  if (subview == nil)
    return;

  NSString *name = [NSString
      stringWithFormat:@"%@_SwizzleHelperWK", subview.class.superclass];
  Class newClass = NSClassFromString(name);

  if (newClass == nil) {
    newClass = objc_allocateClassPair(
        subview.class, [name cStringUsingEncoding:NSASCIIStringEncoding], 0);
    if (!newClass)
      return;

    Method method = class_getInstanceMethod([_SwizzleHelperWK class],
                                            @selector(inputAccessoryView));
    class_addMethod(newClass, @selector(inputAccessoryView),
                    method_getImplementation(method),
                    method_getTypeEncoding(method));

    objc_registerClassPair(newClass);
  }

  object_setClass(subview, newClass);
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
  scrollView.decelerationRate = _decelerationRate;

  decelerating = NO;
  dragging = YES;

  NSDictionary *event = [self onScrollEvent:scrollView.contentOffset
                               moveDistance:CGPointMake(0, 0)];
  _onMessage(@{
    @"name" : @"reactNative",
    @"data" : @{@"type" : @"onScrollBeginDrag", @"data" : event}
  });
}

- (void)setScrollEnabled:(BOOL)scrollEnabled {
  _scrollEnabled = scrollEnabled;
  _webView.scrollView.scrollEnabled = scrollEnabled;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  // Don't allow scrolling the scrollView.
  if (!_scrollEnabled) {
    scrollView.bounds = _webView.bounds;
  } else if (_onScroll != nil) {
    NSDictionary *event = @{
      @"contentOffset" : @{
        @"x" : @(scrollView.contentOffset.x),
        @"y" : @(scrollView.contentOffset.y)
      },
      @"contentInset" : @{
        @"top" : @(scrollView.contentInset.top),
        @"left" : @(scrollView.contentInset.left),
        @"bottom" : @(scrollView.contentInset.bottom),
        @"right" : @(scrollView.contentInset.right)
      },
      @"contentSize" : @{
        @"width" : @(scrollView.contentSize.width),
        @"height" : @(scrollView.contentSize.height)
      },
      @"layoutMeasurement" : @{
        @"width" : @(scrollView.frame.size.width),
        @"height" : @(scrollView.frame.size.height)
      },
      @"zoomScale" : @(scrollView.zoomScale ?: 1),
    };
    _onScroll(event);
  }

  CGPoint offset = scrollView.contentOffset;
  if (!decelerating && !dragging && !scrollingToTop) {
    NSLog(@"scrollViewDidScroll dont fire event");
    lastOffset = offset;
    return;
  }

  CGFloat dy = offset.y - lastOffset.y;
  lastOffset = offset;

  CGSize frameSize = scrollView.frame.size;
  CGFloat offsetMin = 0;
  CGFloat offsetMax = scrollView.contentSize.height - frameSize.height;
  if ((lastOffset.y <= offsetMin && dy > 0) ||
      (lastOffset.y >= offsetMax && dy < 0)) {
    return;
  }

  NSDictionary *event =
      [self onScrollEvent:offset
             moveDistance:CGPointMake(offset.x - lastOffset.x, dy)];
  _onMessage(@{
    @"name" : @"reactNative",
    @"data" : @{@"type" : @"onScroll", @"data" : event}
  });
}

- (NSDictionary *)onScrollEvent:(CGPoint)currentOffset
                   moveDistance:(CGPoint)distance {
  UIScrollView *scrollView = _webView.scrollView;
  CGSize frameSize = scrollView.frame.size;

  NSMutableDictionary<NSString *, id> *event = [self baseEvent];
  [event addEntriesFromDictionary:@{
    @"contentOffset" : @{@"x" : @(currentOffset.x), @"y" : @(currentOffset.y)}
  }];
  [event addEntriesFromDictionary:@{
    @"scroll" : @{
      @"decelerating" : @(decelerating || scrollingToTop),
      @"width" : @(frameSize.width),
      @"height" : @(frameSize.height)
    }
  }];
  [event addEntriesFromDictionary:@{
    @"contentSize" : @{
      @"width" : @(scrollView.contentSize.width),
      @"height" : @(scrollView.contentSize.height)
    }
  }];

  [event addEntriesFromDictionary:@{
    @"offset" : @{@"dx" : @(distance.x), @"dy" : @(distance.y)}
  }];
  return event;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
  decelerating = decelerate;
  dragging = NO;

  NSDictionary *event = [self onScrollEvent:scrollView.contentOffset
                               moveDistance:CGPointMake(0, 0)];
  _onMessage(@{
    @"name" : @"reactNative",
    @"data" : @{@"type" : @"onScrollEndDrag", @"data" : event}
  });
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
  decelerating = NO;

  NSDictionary *event = [self onScrollEvent:scrollView.contentOffset
                               moveDistance:CGPointMake(0, 0)];
  _onMessage(@{
    @"name" : @"reactNative",
    @"data" : @{@"type" : @"onScrollEndDecelerating", @"data" : event}
  });
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
  scrollingToTop = _webView.scrollView.scrollsToTop;
  return _webView.scrollView.scrollsToTop;
}

- (void)setAdjustOffset:(CGPoint)adjustOffset {
  CGRect scrollBounds = _webView.scrollView.bounds;
  scrollBounds.origin =
      CGPointMake(_webView.scrollView.contentOffset.x + adjustOffset.x,
                  _webView.scrollView.contentOffset.y + adjustOffset.y);
  _webView.scrollView.bounds = scrollBounds;

  lastOffset = _webView.scrollView.contentOffset;
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
  scrollingToTop = NO;

  NSDictionary *event = [self onScrollEvent:scrollView.contentOffset
                               moveDistance:CGPointMake(0, 0)];
  _onMessage(@{
    @"name" : @"reactNative",
    @"data" : @{@"type" : @"onScrollEndDecelerating", @"data" : event}
  });
}

- (void)setDirectionalLockEnabled:(BOOL)directionalLockEnabled {
  _directionalLockEnabled = directionalLockEnabled;
  _webView.scrollView.directionalLockEnabled = directionalLockEnabled;
}

- (void)setShowsHorizontalScrollIndicator:(BOOL)showsHorizontalScrollIndicator {
  _showsHorizontalScrollIndicator = showsHorizontalScrollIndicator;
  _webView.scrollView.showsHorizontalScrollIndicator =
      showsHorizontalScrollIndicator;
}

- (void)setShowsVerticalScrollIndicator:(BOOL)showsVerticalScrollIndicator {
  _showsVerticalScrollIndicator = showsVerticalScrollIndicator;
  _webView.scrollView.showsVerticalScrollIndicator =
      showsVerticalScrollIndicator;
}

- (void)postMessage:(NSString *)message {
  NSDictionary *eventInitDict = @{@"data" : message};
  NSString *source =
      [NSString stringWithFormat:
                    @"window.dispatchEvent(new MessageEvent('message', %@));",
                    RCTJSONStringify(eventInitDict, NULL)];
  [self injectJavaScript:source];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  // Ensure webview takes the position and dimensions of RNCWebView
  _webView.frame = self.bounds;
  _webView.scrollView.contentInset = _contentInset;
}

- (NSMutableDictionary<NSString *, id> *)baseEvent {
  NSDictionary *event = @{
    @"url" : _webView.URL.absoluteString ?: @"",
    @"title" : _webView.title ?: @"",
    @"loading" : @(_webView.loading),
    @"canGoBack" : @(_webView.canGoBack),
    @"progress" : @(_webView.estimatedProgress),
    @"canGoForward" : @(_webView.canGoForward)
  };
  return [[NSMutableDictionary alloc] initWithDictionary:event];
}

+ (void)setClientAuthenticationCredential:
    (nullable NSURLCredential *)credential {
  clientAuthenticationCredential = credential;
}

+ (void)setCustomCertificatesForHost:(nullable NSDictionary *)certificates {
  customCertificatesForHost = certificates;
}

- (void)webView:(WKWebView *)webView
    didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
                    completionHandler:
                        (void (^)(
                            NSURLSessionAuthChallengeDisposition disposition,
                            NSURLCredential *_Nullable))completionHandler {
  NSString *host = nil;
  if (webView.URL != nil) {
    host = webView.URL.host;
  }
  NSString *authMethod = challenge.protectionSpace.authenticationMethod;
  if (authMethod == NSURLAuthenticationMethodClientCertificate) {
    completionHandler(NSURLSessionAuthChallengeUseCredential,
                      clientAuthenticationCredential);
    return;
  } else if ([authMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic]) {
    UIAlertController *alertView = [UIAlertController
        alertControllerWithTitle:
            [LocalizeString(@"Login_title")
                stringByReplacingOccurrencesOfString:@"%s"
                                          withString:challenge.protectionSpace
                                                         .host]
                         message:@""
                  preferredStyle:UIAlertControllerStyleAlert];
    [alertView addTextFieldWithConfigurationHandler:^(
                   UITextField *_Nonnull textField) {
      textField.placeholder = LocalizeString(@"Username");
    }];
    [alertView addTextFieldWithConfigurationHandler:^(
                   UITextField *_Nonnull textField) {
      textField.placeholder = LocalizeString(@"Password");
      textField.secureTextEntry = YES;
    }];
    [alertView
        addAction:
            [UIAlertAction
                actionWithTitle:LocalizeString(@"Cancel")
                          style:UIAlertActionStyleCancel
                        handler:^(UIAlertAction *_Nonnull action) {
                          completionHandler(
                              NSURLSessionAuthChallengeCancelAuthenticationChallenge,
                              nil);
                        }]];

    [alertView
        addAction:
            [UIAlertAction
                actionWithTitle:LocalizeString(@"Login")
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *_Nonnull action) {
                          UITextField *userField =
                              alertView.textFields.firstObject;
                          UITextField *passField =
                              alertView.textFields.lastObject;
                          NSURLCredential *credential = [NSURLCredential
                              credentialWithUser:userField.text
                                        password:passField.text
                                     persistence:
                                         NSURLCredentialPersistenceForSession];
                          @try {
                            [challenge.sender useCredential:credential
                                 forAuthenticationChallenge:challenge];
                          } @catch (NSException *exception) {
                            NSLog(@"%@", exception.description);
                          } @finally {
                            completionHandler(
                                NSURLSessionAuthChallengeUseCredential,
                                credential);
                          }
                        }]];
    return
        [[[UIApplication sharedApplication].delegate window].rootViewController
            presentViewController:alertView
                         animated:YES
                       completion:nil];
  }
  if ([[challenge protectionSpace] serverTrust] != nil &&
      customCertificatesForHost != nil && host != nil) {
    SecCertificateRef localCertificate = (__bridge SecCertificateRef)(
        [customCertificatesForHost objectForKey:host]);
    if (localCertificate != nil) {
      NSData *localCertificateData =
          (NSData *)CFBridgingRelease(SecCertificateCopyData(localCertificate));
      SecTrustRef trust = [[challenge protectionSpace] serverTrust];
      long count = SecTrustGetCertificateCount(trust);
      for (long i = 0; i < count; i++) {
        SecCertificateRef serverCertificate =
            SecTrustGetCertificateAtIndex(trust, i);
        if (serverCertificate == nil) {
          continue;
        }
        NSData *serverCertificateData = (NSData *)CFBridgingRelease(
            SecCertificateCopyData(serverCertificate));
        if ([serverCertificateData isEqualToData:localCertificateData]) {
          NSURLCredential *useCredential =
              [NSURLCredential credentialForTrust:trust];
          if (challenge.sender != nil) {
            [challenge.sender useCredential:useCredential
                 forAuthenticationChallenge:challenge];
          }
          completionHandler(NSURLSessionAuthChallengeUseCredential,
                            useCredential);
          return;
        }
      }
    }
  }
  completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

#pragma mark - WKNavigationDelegate methods

/**
 * alert
 */
- (void)webView:(WKWebView *)webView
    runJavaScriptAlertPanelWithMessage:(NSString *)message
                      initiatedByFrame:(WKFrameInfo *)frame
                     completionHandler:(void (^)(void))completionHandler {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@""
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Ok"
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *action) {
                                            completionHandler();
                                          }]];
  [[self topViewController] presentViewController:alert
                                         animated:YES
                                       completion:NULL];
}

/**
 * confirm
 */
- (void)webView:(WKWebView *)webView
    runJavaScriptConfirmPanelWithMessage:(NSString *)message
                        initiatedByFrame:(WKFrameInfo *)frame
                       completionHandler:(void (^)(BOOL))completionHandler {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@""
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Ok"
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *action) {
                                            completionHandler(YES);
                                          }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                            style:UIAlertActionStyleCancel
                                          handler:^(UIAlertAction *action) {
                                            completionHandler(NO);
                                          }]];
  [[self topViewController] presentViewController:alert
                                         animated:YES
                                       completion:NULL];
}

/**
 * prompt
 */
- (void)webView:(WKWebView *)webView
    runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt
                              defaultText:(NSString *)defaultText
                         initiatedByFrame:(WKFrameInfo *)frame
                        completionHandler:
                            (void (^)(NSString *))completionHandler {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@""
                                          message:prompt
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    textField.text = defaultText;
  }];
  UIAlertAction *okAction = [UIAlertAction
      actionWithTitle:@"Ok"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                completionHandler([[alert.textFields lastObject] text]);
              }];
  [alert addAction:okAction];
  UIAlertAction *cancelAction =
      [UIAlertAction actionWithTitle:@"Cancel"
                               style:UIAlertActionStyleCancel
                             handler:^(UIAlertAction *action) {
                               completionHandler(nil);
                             }];
  [alert addAction:cancelAction];
  alert.preferredAction = okAction;
  [[self topViewController] presentViewController:alert
                                         animated:YES
                                       completion:NULL];
}

/**
 * topViewController
 */
- (UIViewController *)topViewController {
  return RCTPresentedViewController();
}

/**
 * Decides whether to allow or cancel a navigation.
 * @see https://fburl.com/42r9fxob
 */
- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:
                        (void (^)(WKNavigationActionPolicy))decisionHandler {

  static NSDictionary<NSNumber *, NSString *> *navigationTypes;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    navigationTypes = @{
      @(WKNavigationTypeLinkActivated) : @"click",
      @(WKNavigationTypeFormSubmitted) : @"formsubmit",
      @(WKNavigationTypeBackForward) : @"backforward",
      @(WKNavigationTypeReload) : @"reload",
      @(WKNavigationTypeFormResubmitted) : @"formresubmit",
      @(WKNavigationTypeOther) : @"other",
    };
  });

  if (longPress) {
    longPress = NO;
    return decisionHandler(WKNavigationActionPolicyCancel);
  }

  WKNavigationType navigationType = navigationAction.navigationType;
  NSURLRequest *request = navigationAction.request;
  NSURL *requestURL = request.URL;
  if (request && requestURL) {
    NSArray *downloadSchemes =
        @[ @"http", @"https", @"data", @"blob", @"file" ];
    if ([downloadSchemes containsObject:requestURL.scheme]) {
      [[DownloadHelper pendingRequests] setObject:navigationAction.request
                                           forKey:requestURL.absoluteString];
    }

    NSArray *allowSchemes = @[ @"data", @"blob" ];
    if ([allowSchemes containsObject:requestURL.scheme]) {
      decisionHandler(WKNavigationActionPolicyAllow);
      return;
    }
  }

  if (_onShouldStartLoadWithRequest) {
    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary:@{
      @"url" : (request.URL).absoluteString,
      @"mainDocumentURL" : (request.mainDocumentURL).absoluteString,
      @"navigationType" : navigationTypes[@(navigationType)]
    }];
    if (![self.delegate webView:self
            shouldStartLoadForRequest:event
                         withCallback:_onShouldStartLoadWithRequest]) {
      decisionHandler(WKNavigationActionPolicyCancel);
      return;
    }
  }

  if (_onLoadingStart) {
    // We have this check to filter out iframe requests and whatnot
    BOOL isTopFrame = [request.URL isEqual:request.mainDocumentURL];
    // Do not notify event if the request is for new window
    BOOL isMainFrame = navigationAction.targetFrame.isMainFrame;
    if (isTopFrame && isMainFrame) {
      NSMutableDictionary<NSString *, id> *event = [self baseEvent];
      [event addEntriesFromDictionary:@{
        @"url" : (request.URL).absoluteString,
        @"navigationType" : navigationTypes[@(navigationType)]
      }];
      _onLoadingStart(event);
    }
  }

  // allowlist function
  if (@available(iOS 11.0, *)) {
    BOOL isAllowWebsite = false;
    if (scriptYoutubeAdblock == nil) {
      NSString *jsFileYoutubeAdblock = @"__youtubeAdblock__";
      NSString *jsFilePathYoutubeAdblock =
          [resourceBundle pathForResource:jsFileYoutubeAdblock ofType:@"js"];
      NSURL *jsURLYoutubeAdblock =
          [NSURL fileURLWithPath:jsFilePathYoutubeAdblock];
      NSString *javascriptCodeYoutubeAdblock =
          [NSString stringWithContentsOfFile:jsURLYoutubeAdblock.path
                                    encoding:NSUTF8StringEncoding
                                       error:nil];
      scriptYoutubeAdblock = [[WKUserScript alloc]
            initWithSource:javascriptCodeYoutubeAdblock
             injectionTime:WKUserScriptInjectionTimeAtDocumentStart
          forMainFrameOnly:YES];
    }

    if (_adBlockAllowList != nil && _adBlockAllowList.count > 0) {
      isAllowWebsite =  [_adBlockAllowList containsObject:request.mainDocumentURL.host];
    }

      bool isExistedScriptAdblock = [webView.configuration.userContentController.userScripts containsObject:scriptYoutubeAdblock];
      if (_contentRuleLists != nil && _contentRuleLists.count > 0 && isAllowWebsite == false) {
          
          if (@available(iOS 14.0.0, *)) {
              if(engine!= NULL){
                  [engine getScripts:webView decidePolicyFor:navigationAction preferences:wkWebViewConfig.preferences completionHandler:^(NSString *status) {
                      self->isAddScriptByTypes = @(YES);
                      NSLog(@"bách %@", status);
                  }];
                  
                  [engine configRulesWithUserContentController:wkWebViewConfig.userContentController  completionHandler:^(NSSet<WKContentRuleList *> *contentRuleList, NSError *error) {
                      if (!error) {
                          dispatch_async(dispatch_get_main_queue(), ^{
                              for (WKContentRuleList* rule in contentRuleList){
                                  [webView.configuration.userContentController addContentRuleList:rule];
                              }
                          });
                      }
                  }];
              }else{
                  NSLog(@"engine null");
              }
          }else{
              WKContentRuleListStore *contentRuleListStore = WKContentRuleListStore.defaultStore;
              [contentRuleListStore getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
                  for (NSString *identifier in identifiers) {
                      if ([self->_contentRuleLists containsObject:identifier]) {
                          [contentRuleListStore lookUpContentRuleListForIdentifier:identifier completionHandler:^(WKContentRuleList *contentRuleList, NSError *error) {
                              if (!error) {
                                  [webView.configuration.userContentController addContentRuleList:contentRuleList];
                              }
                          }];
                      }
                  }
              }];
              
//              add youtubeAdblock
              if(request.mainDocumentURL.host != nil && [self
                                                         isYoutubeWebsite:request.mainDocumentURL.host] && isExistedScriptAdblock == false){
                  [webView.configuration.userContentController addUserScript:scriptYoutubeAdblock];
              }
          }
      } else {
          [webView.configuration.userContentController removeAllContentRuleLists];
          if (@available(iOS 14.0.0, *)) {
//              if(isAddScriptByTypes){
//                  [self resetupScripts:_webView.configuration];
//                  isAddScriptByTypes = @(NO);
//              }
          }
        // remove youtubeAdblock --> remove all userScripts and then add common scripts
          if(request.mainDocumentURL.host != nil && [self isYoutubeWebsite:request.mainDocumentURL.host] && isExistedScriptAdblock == true){
              [self resetupScripts:_webView.configuration];
          }
      }
          
  }

  if (@available(iOS 13.0, *)) {
    if (scriptNightMode == nil) {
      NSString *jsFileNightMode = @"__NightModeScript__";
      NSString *jsFilePathNightMode =
          [resourceBundle pathForResource:jsFileNightMode ofType:@"js"];
      NSURL *jsURLNightMode = [NSURL fileURLWithPath:jsFilePathNightMode];
      NSString *javascriptCodeNightMode =
          [NSString stringWithContentsOfFile:jsURLNightMode.path
                                    encoding:NSUTF8StringEncoding
                                       error:nil];
      scriptNightMode = [[WKUserScript alloc]
            initWithSource:javascriptCodeNightMode
             injectionTime:WKUserScriptInjectionTimeAtDocumentStart
          forMainFrameOnly:YES];
    }
    if ([webView.configuration.userContentController.userScripts
            containsObject:scriptNightMode] == false) {
      [wkWebViewConfig.userContentController addUserScript:scriptNightMode];
    }
  }

  // enable picture-in-picture feature on youtube page
  // only use this script for youtube page. if you use this script for other
  // pages, some websites will not run some js scripts Ref:
  // https://github.com/brave/brave-ios
  // /blob/development/Client/Frontend/Browser/UserScriptManager.swift#L64
  if (@available(iOS 14.0, *)) {
    if (request.mainDocumentURL.host != nil) {
      if ([self isYoutubeWebsite:request.mainDocumentURL.host]) {
        if (scriptYoutubePictureInPicture == nil) {
          NSString *jsFile = @"__firefox__";
          NSString *jsFilePath = [resourceBundle pathForResource:jsFile
                                                          ofType:@"js"];
          NSURL *jsURL = [NSURL fileURLWithPath:jsFilePath];
          NSString *javascriptCode =
              [NSString stringWithContentsOfFile:jsURL.path
                                        encoding:NSUTF8StringEncoding
                                           error:nil];
          scriptYoutubePictureInPicture = [[WKUserScript alloc]
                initWithSource:javascriptCode
                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
              forMainFrameOnly:YES];
        }
        if ([webView.configuration.userContentController.userScripts
                containsObject:scriptYoutubePictureInPicture] == false) {
          [wkWebViewConfig.userContentController
              addUserScript:scriptYoutubePictureInPicture];
        }
      }
    }
  }

  // set the additionalUserAgent
  int count = (int)[_additionalUserAgent count];
  for (int i = 0; i < count; i++) {
    NSDictionary *item = [_additionalUserAgent objectAtIndex:i];
    NSString *domain = [item objectForKey:@"domain"];

    if (domain != nil && [request.mainDocumentURL.host isEqual:domain]) {
      NSString *extendedUserAgent = [item objectForKey:@"extendedUserAgent"];
      if (_userAgent != nil && extendedUserAgent != nil) {
        NSMutableString *newUserAgent = [[NSMutableString alloc]
            initWithFormat:@"%@ %@", _userAgent, extendedUserAgent];
        webView.customUserAgent = newUserAgent;
        break;
      }
    }
  }

  // Allow all navigation by default
  decisionHandler(WKNavigationActionPolicyAllow);
}

- (bool)isYoutubeWebsite:(NSString *)domain {
  return [domain isEqual:@"m.youtube.com"] ||
         [domain isEqual:@"www.youtube.com"] ||
         [domain isEqual:@"music.youtube.com"];
}

/**
 * Called when the web view’s content process is terminated.
 * @see
 * https://developer.apple.com/documentation/webkit/wknavigationdelegate/1455639-webviewwebcontentprocessdidtermi?language=objc
 */
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
  RCTLogWarn(@"Webview Process Terminated");
  if (_onContentProcessDidTerminate) {
    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    _onContentProcessDidTerminate(event);
  }
}

/**
 * Decides whether to allow or cancel a navigation after its response is known.
 * @see
 * https://developer.apple.com/documentation/webkit/wknavigationdelegate/1455643-webview?language=objc
 */
- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
                      decisionHandler:(void (^)(WKNavigationResponsePolicy))
                                          decisionHandler {
  WKNavigationResponsePolicy policy = WKNavigationResponsePolicyAllow;
  if (_onHttpError && navigationResponse.forMainFrame) {
    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
      NSHTTPURLResponse *response =
          (NSHTTPURLResponse *)navigationResponse.response;
      NSInteger statusCode = response.statusCode;

      if (statusCode >= 400) {
        NSMutableDictionary<NSString *, id> *event = [self baseEvent];
        [event addEntriesFromDictionary:@{
          @"url" : response.URL.absoluteString,
          @"statusCode" : @(statusCode)
        }];

        _onHttpError(event);
      }
    }
  }

  NSURLResponse *response = navigationResponse.response;
  NSURL *responseURL = [response URL];

  BOOL canShowInWebView = navigationResponse.canShowMIMEType;
  WKWebsiteDataStore *dataStore = webView.configuration.websiteDataStore;
  WKHTTPCookieStore *cookieStore = dataStore.httpCookieStore;

  if ([PassBookHelper canOpenPassBookWithResponse:response]) {
    PassBookHelper *passBookHelper =
        [[PassBookHelper alloc] initWithResponse:response
                                     cookieStore:cookieStore
                                  viewController:[self topViewController]];
    // Open our helper and nullify the helper when done with it
    [passBookHelper open];
    passBookHelper.delegate = [DownloadModule sharedInstance];

    // Cancel this response from the webview.
    decisionHandler(WKNavigationActionPolicyCancel);
    return;
  }

  NSURLRequest *request = nil;
  if (responseURL) {
    request = [[DownloadHelper pendingRequests]
        objectForKey:responseURL.absoluteString];
    [[DownloadHelper pendingRequests]
        removeObjectForKey:responseURL.absoluteString];
  }

  DownloadHelper *downloadHelper =
      [[DownloadHelper alloc] initWithRequest:request
                                     response:response
                                  cookieStore:cookieStore
                             canShowInWebView:canShowInWebView];
  if (downloadHelper) {
    id downloadAlertAction = ^(HTTPDownload *download) {
      [[DownloadQueue downloadQueue] appendSessionInfo];
      [[DownloadQueue downloadQueue] enqueue:download];
    };
    UIViewController *rootVC =
        [[UIApplication sharedApplication].delegate window].rootViewController;
    UIAlertController *alertView =
        [downloadHelper downloadAlertFromView:rootVC.view
                                     okAction:downloadAlertAction];
    if (alertView) {
      [rootVC presentViewController:alertView animated:YES completion:nil];
    }
    policy = WKNavigationResponsePolicyCancel;
  }

  decisionHandler(policy);
}

/**
 * Called when an error occurs while the web view is loading content.
 * @see https://fburl.com/km6vqenw
 */
- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
  if (_onLoadingError) {
    if ([error.domain isEqualToString:NSURLErrorDomain] &&
        error.code == NSURLErrorCancelled) {
      // NSURLErrorCancelled is reported when a page has a redirect OR if you
      // load a new URL in the WebView before the previous one came back. We can
      // just ignore these since they aren't real errors.
      // http://stackoverflow.com/questions/1024748/how-do-i-fix-nsurlerrordomain-error-999-in-iphone-3-0-os
      return;
    }

    if ([error.domain isEqualToString:@"WebKitErrorDomain"] &&
        error.code == 102) {
      // Error code 102 "Frame load interrupted" is raised by the WKWebView
      // when the URL is from an http redirect. This is a common pattern when
      // implementing OAuth with a WebView.
      return;
    }

    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary:@{
      @"didFailProvisionalNavigation" : @YES,
      @"domain" : error.domain,
      @"code" : @(error.code),
      @"description" : error.localizedDescription,
    }];
    _onLoadingError(event);
  }
}

- (void)evaluateJS:(NSString *)js thenCall:(void (^)(NSString *))callback {
  [self.webView
      evaluateJavaScript:js
       completionHandler:^(id result, NSError *error) {
         if (callback != nil) {
           callback([NSString stringWithFormat:@"%@", result]);
         }
         if (error != nil) {
           RCTLogWarn(
               @"%@",
               [NSString
                   stringWithFormat:
                       @"Error evaluating injectedJavaScript: This is possibly "
                       @"due to an unsupported return type. Try adding true to "
                       @"the end of your injectedJavaScript string. %@",
                       error]);
         }
       }];
}

/**
 * Called when the navigation is complete.
 * @see https://fburl.com/rtys6jlb
 */
- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
  if (resourceBundle) {
    NSString *jsFile = @"_webview";

    NSString *jsFilePath = [resourceBundle pathForResource:jsFile ofType:@"js"];
    NSURL *jsURL = [NSURL fileURLWithPath:jsFilePath];
    NSString *javascriptCode =
        [NSString stringWithContentsOfFile:jsURL.path
                                  encoding:NSUTF8StringEncoding
                                     error:nil];
    [_webView stringByEvaluatingJavaScriptFromString:javascriptCode];
  }
  if (_injectedJavaScript) {
    [self evaluateJS:_injectedJavaScript
            thenCall:^(NSString *jsEvaluationValue) {
              NSMutableDictionary *event = [self baseEvent];
              event[@"jsEvaluationValue"] = jsEvaluationValue;

              if (self.onLoadingFinish) {
                self.onLoadingFinish(event);
              }
            }];
  } else if (_onLoadingFinish) {
    _onLoadingFinish([self baseEvent]);
  }

  // Disable default long press menu
  [webView evaluateJavaScript:@"document.body.style.webkitTouchCallout='none';"
            completionHandler:nil];

  NSString *favicon =
      [_webView stringByEvaluatingJavaScriptFromString:@"getFavicons();"];
  NSDictionary *event = @{@"data" : favicon ? favicon : @""};
  if (_onGetFavicon != nil) {
    _onGetFavicon(event);
  }
}

- (void)injectJavaScript:(NSString *)script {
  [self evaluateJS:script thenCall:nil];
}

- (void)goForward {
  [_webView goForward];
}

- (void)goBack {
  [_webView goBack];
}

- (void)reload {
  /**
   * When the initial load fails due to network connectivity issues,
   * [_webView reload] doesn't reload the webpage. Therefore, we must
   * manually call [_webView loadRequest:request].
   */
  NSURLRequest *request = [self requestForSource:self.source];

  if (request.URL && !_webView.URL.absoluteString.length) {
    [_webView loadRequest:request];
  } else {
    [_webView reload];
  }
}

- (void)stopLoading {
  [_webView stopLoading];
}

- (void)setBounces:(BOOL)bounces {
  _bounces = bounces;
  _webView.scrollView.bounces = bounces;
}

// similar setupConfiguration
- (void)resetupScripts:(WKWebViewConfiguration *)wkWebViewConfig {
  [wkWebViewConfig.userContentController removeAllUserScripts];
  [wkWebViewConfig.userContentController
      removeScriptMessageHandlerForName:MessageHandlerName];
  [wkWebViewConfig.userContentController
      removeScriptMessageHandlerForName:RequestBlockingScript];
  [wkWebViewConfig.userContentController
      removeScriptMessageHandlerForName:PrintScriptHandler];

  if (_sharedCookiesEnabled) {
    // More info to sending cookies with WKWebView
    // https://stackoverflow.com/questions/26573137/can-i-set-the-cookies-to-be-used-by-a-wkwebview/26577303#26577303
    if (@available(iOS 11.0, *)) {
      // Set Cookies in iOS 11 and above, initialize websiteDataStore before
      // setting cookies See also
      // https://forums.developer.apple.com/thread/97194 check if
      // websiteDataStore has not been initialized before
      if (!_incognito && !_cacheEnabled) {
        wkWebViewConfig.websiteDataStore =
            [WKWebsiteDataStore nonPersistentDataStore];
      }
      for (NSHTTPCookie *cookie in
           [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        [wkWebViewConfig.websiteDataStore.httpCookieStore setCookie:cookie
                                                  completionHandler:nil];
      }
    } else {
      NSMutableString *script = [NSMutableString string];

      // Clear all existing cookies in a direct called function. This ensures
      // that no javascript error will break the web content javascript. We keep
      // this code here, if someone requires that Cookies are also removed
      // within the the WebView and want to extends the current
      // sharedCookiesEnabled option with an additional property. Generates JS:
      // document.cookie = "key=; Expires=Thu, 01 Jan 1970 00:00:01 GMT;" for
      // each cookie which is already available in the WebView context.
      /*
       [script appendString:@"(function () {\n"];
       [script appendString:@"  var cookies = document.cookie.split('; ');\n"];
       [script appendString:@"  for (var i = 0; i < cookies.length; i++) {\n"];
       [script appendString:@"    if (cookies[i].indexOf('=') !== -1) {\n"];
       [script appendString:@"      document.cookie = cookies[i].split('=')[0] +
       '=; Expires=Thu, 01 Jan 1970 00:00:01 GMT';\n"]; [script appendString:@"
       }\n"]; [script appendString:@"  }\n"]; [script
       appendString:@"})();\n\n"];
       */

      // Set cookies in a direct called function. This ensures that no
      // javascript error will break the web content javascript.
      // Generates JS: document.cookie = "key=value; Path=/; Expires=Thu, 01 Jan
      // 20xx 00:00:01 GMT;" for each cookie which is available in the
      // application context.
      [script appendString:@"(function () {\n"];
      for (NSHTTPCookie *cookie in
           [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        [script appendFormat:@"document.cookie = %@ + '=' + %@",
                             RCTJSONStringify(cookie.name, NULL),
                             RCTJSONStringify(cookie.value, NULL)];
        if (cookie.path) {
          [script appendFormat:@" + '; Path=' + %@",
                               RCTJSONStringify(cookie.path, NULL)];
        }
        if (cookie.expiresDate) {
          [script appendFormat:@" + '; Expires=' + new Date(%f).toUTCString()",
                               cookie.expiresDate.timeIntervalSince1970 * 1000];
        }
        [script appendString:@";\n"];
      }
      [script appendString:@"})();\n"];

      WKUserScript *cookieInScript = [[WKUserScript alloc]
            initWithSource:script
             injectionTime:WKUserScriptInjectionTimeAtDocumentStart
          forMainFrameOnly:YES];
      [wkWebViewConfig.userContentController addUserScript:cookieInScript];
    }
  }

  if (_messagingEnabled) {
    [wkWebViewConfig.userContentController
        addScriptMessageHandler:self
                           name:MessageHandlerName];

    NSString *source = [NSString
        stringWithFormat:
            @"window.%@ = {"
             "  postMessage: function (data) {"
             "    window.webkit.messageHandlers.%@.postMessage(String(data));"
             "  }"
             "};",
            MessageHandlerName, MessageHandlerName];

    WKUserScript *script = [[WKUserScript alloc]
          initWithSource:source
           injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:YES];
    [wkWebViewConfig.userContentController addUserScript:script];
  }

  if (@available(iOS 14.0, *)) {
    WKContentWorld *scriptSandbox = [WKContentWorld pageWorld];

    [wkWebViewConfig.userContentController
        addScriptMessageHandlerWithReply:self
                            contentWorld:scriptSandbox
                                    name:RequestBlockingScript];
    NSString *sourceBlockingScript = [NSString
        stringWithFormat:
            @"window.%@ = function (data) {"
             "  return "
             "window.webkit.messageHandlers.%@.postMessage(String(data));"
             "};",
            RequestBlockingScript, RequestBlockingScript];

    WKUserScript *scriptBlocking = [[WKUserScript alloc]
          initWithSource:sourceBlockingScript
           injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:NO];
    [wkWebViewConfig.userContentController addUserScript:scriptBlocking];
  }

  // override window.print script
  [wkWebViewConfig.userContentController
      addScriptMessageHandler:self
                         name:PrintScriptHandler];
  NSString *sourcePrintScript = [NSString
      stringWithFormat:
          @"window.print = function () {"
           "    window.webkit.messageHandlers.%@.postMessage(String());"
           "};",
          PrintScriptHandler];

  WKUserScript *scriptPrint = [[WKUserScript alloc]
        initWithSource:sourcePrintScript
         injectionTime:WKUserScriptInjectionTimeAtDocumentStart
      forMainFrameOnly:NO];
  [wkWebViewConfig.userContentController addUserScript:scriptPrint];

  if (_injectedJavaScriptBeforeDocumentLoad) {
    WKUserScript *script = [[WKUserScript alloc]
          initWithSource:_injectedJavaScriptBeforeDocumentLoad
           injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:YES];
    [wkWebViewConfig.userContentController addUserScript:script];
  }
}

- (NSURLRequest *)requestForSource:(id)json {
  NSURLRequest *request = [RCTConvert NSURLRequest:self.source];

  // If sharedCookiesEnabled we automatically add all application cookies to the
  // http request. This is automatically done on iOS 11+ in the WebView
  // constructor. Se we need to manually add these shared cookies here only for
  // iOS versions < 11.
  if (_sharedCookiesEnabled) {
    if (@available(iOS 11.0, *)) {
      // see WKWebView initialization for added cookies
    } else {
      NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage]
          cookiesForURL:request.URL];
      NSDictionary<NSString *, NSString *> *cookieHeader =
          [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
      NSMutableURLRequest *mutableRequest = [request mutableCopy];
      [mutableRequest setAllHTTPHeaderFields:cookieHeader];
      return mutableRequest;
    }
  }
  return request;
}

#pragma mark - Custom Lunascape functions
- (WKWebView *)webview {
  return _webView;
}
- (void)setScrollToTop:(BOOL)scrollToTop {
  _webView.scrollView.scrollsToTop = scrollToTop;
}

- (void)evaluateJavaScript:(NSString *)javaScriptString
         completionHandler:(void (^)(id, NSError *error))completionHandler {
  [_webView evaluateJavaScript:javaScriptString
             completionHandler:completionHandler];
}

- (void)findInPage:(NSString *)searchString {
  if (searchString && searchString.length > 0) {
    [_webView highlightAllOccurencesOfString:searchString];
  }
}

- (void)findNext {
  [_webView findNext];
}

- (void)findPrevious {
  [_webView findPrevious];
}

- (void)removeAllHighlights {
  [_webView removeAllHighlights];
}

- (void)setFontSize:(nonnull NSNumber *)size {
  double fontSize = [size doubleValue];
  [_webView setValue:[NSNumber numberWithDouble:fontSize] forKey:@"viewScale"];
}

- (void)captureScreen:(void (^_Nonnull)(NSString *_Nullable path))callback {
  [_webView contentFrameCapture:^(UIImage *capturedImage) {
    NSDate *date = [NSDate new];
    NSString *fileName =
        [NSString stringWithFormat:@"%f.png", date.timeIntervalSince1970];
    NSString *path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSData *binaryImageData = UIImagePNGRepresentation(capturedImage);
    BOOL isWrited = [binaryImageData writeToFile:path atomically:YES];
    if (isWrited) {
      callback(path);
    } else { // Error while capturing the screen
      callback(nil);
    };
  }];
}

- (void)capturePage:(void (^_Nonnull)(NSString *_Nullable path))callback {
  [_webView contentScrollCapture:^(UIImage *capturedImage) {
    NSDate *date = [NSDate new];
    NSString *fileName =
        [NSString stringWithFormat:@"%f.png", date.timeIntervalSince1970];
    NSString *path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSData *binaryImageData = UIImagePNGRepresentation(capturedImage);
    BOOL isWrited = [binaryImageData writeToFile:path atomically:YES];
    if (isWrited) {
      callback(path);
    } else {
      callback(nil);
    }
  }];
}

- (void)printContent {
  UIPrintInteractionController *controller =
      [UIPrintInteractionController sharedPrintController];
  UIPrintInfo *printInfo = [UIPrintInfo printInfo];
  printInfo.outputType = UIPrintInfoOutputGeneral;
  printInfo.jobName = _webView.URL.absoluteString;
  printInfo.duplex = UIPrintInfoDuplexLongEdge;
  controller.printInfo = printInfo;
  controller.showsPageRange = YES;

  UIViewPrintFormatter *viewFormatter = [_webView viewPrintFormatter];
  viewFormatter.startPage = 0;
  viewFormatter.contentInsets = UIEdgeInsetsMake(25.0, 25.0, 25.0, 25.0);
  controller.printFormatter = viewFormatter;

  [controller
        presentAnimated:YES
      completionHandler:^(
          UIPrintInteractionController *_Nonnull printInteractionController,
          BOOL completed, NSError *_Nullable error) {
        if (!completed || error) {
          NSLog(@"Print FAILED! with error: %@", error.localizedDescription);
        }
      }];
}

- (void)longPressed:(UILongPressGestureRecognizer *)sender {
  if (sender.state == UIGestureRecognizerStateBegan) {
    longPress = YES;

    NSUInteger touchCount = [sender numberOfTouches];
    if (touchCount) {
      CGPoint point = [sender locationOfTouch:0 inView:sender.view];
      if ([_webView
              respondsToSelector:@selector(respondToTapAndHoldAtLocation:)]) {
        NSDictionary *urlResult =
            [_webView respondToTapAndHoldAtLocation:point];
        if (urlResult.allKeys.count == 0) {
          longPress = NO;
        }
        _onMessage(@{
          @"name" : @"reactNative",
          @"data" : @{@"type" : @"contextMenu", @"data" : urlResult}
        });
      }
    }
  }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
        (UIGestureRecognizer *)otherGestureRecognizer {
  return YES;
}

- (void)handleRefresh:(UIRefreshControl *)refresh {
  // reload webview
  [_webView reload];
  [refresh endRefreshing];
}

// Disable previews for the given element.
- (BOOL)webView:(WKWebView *)webView
    shouldPreviewElement:(WKPreviewElementInfo *)elementInfo
    API_AVAILABLE(ios(10.0)) {
  return NO;
}

- (void)setEnableNightMode:(NSString *)enable {
  [_webView setEnableNightMode:enable];
}

@end
