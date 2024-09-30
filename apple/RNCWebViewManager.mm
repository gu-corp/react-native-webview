#import <React/RCTUIManager.h>

#import "RNCWebViewManager.h"
#import "RNCWebViewImpl.h"
#import <React/RCTDefines.h>

#if TARGET_OS_OSX
#define RNCView NSView
@class NSView;
#else
#define RNCView UIView
@class UIView;
#endif  // TARGET_OS_OSX

@interface RNCWebViewManager () <RNCWebViewDelegate>
@end

@implementation RCTConvert (WKWebView)
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 /* iOS 13 */
RCT_ENUM_CONVERTER(WKContentMode, (@{
  @"recommended": @(WKContentModeRecommended),
  @"mobile": @(WKContentModeMobile),
  @"desktop": @(WKContentModeDesktop),
}), WKContentModeRecommended, integerValue)
#endif

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 150000 /* iOS 15 */
RCT_ENUM_CONVERTER(RNCWebViewPermissionGrantType, (@{
  @"grantIfSameHostElsePrompt": @(RNCWebViewPermissionGrantType_GrantIfSameHost_ElsePrompt),
  @"grantIfSameHostElseDeny": @(RNCWebViewPermissionGrantType_GrantIfSameHost_ElseDeny),
  @"deny": @(RNCWebViewPermissionGrantType_Deny),
  @"grant": @(RNCWebViewPermissionGrantType_Grant),
  @"prompt": @(RNCWebViewPermissionGrantType_Prompt),
}), RNCWebViewPermissionGrantType_Prompt, integerValue)
#endif
@end

@implementation RNCWebViewManager

RCT_EXPORT_MODULE(RNCWebView)

- (RNCView *)view
{
  return [[RNCWebViewImpl alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(source, NSDictionary)
// New arch only
RCT_CUSTOM_VIEW_PROPERTY(newSource, NSDictionary, RNCWebViewImpl) {}
RCT_EXPORT_VIEW_PROPERTY(onFileDownload, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingFinish, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingProgress, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onHttpError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onShouldStartLoadWithRequest, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onContentProcessDidTerminate, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onOpenWindow, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(injectedJavaScript, NSString)
RCT_EXPORT_VIEW_PROPERTY(injectedJavaScriptBeforeContentLoaded, NSString)
RCT_EXPORT_VIEW_PROPERTY(injectedJavaScriptForMainFrameOnly, BOOL)
RCT_EXPORT_VIEW_PROPERTY(injectedJavaScriptBeforeContentLoadedForMainFrameOnly, BOOL)
RCT_EXPORT_VIEW_PROPERTY(injectedJavaScriptObject, NSString)
RCT_EXPORT_VIEW_PROPERTY(javaScriptEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(javaScriptCanOpenWindowsAutomatically, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowFileAccessFromFileURLs, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowUniversalAccessFromFileURLs, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowsInlineMediaPlayback, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowsPictureInPictureMediaPlayback, BOOL)
RCT_EXPORT_VIEW_PROPERTY(webviewDebuggingEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowsAirPlayForMediaPlayback, BOOL)
RCT_EXPORT_VIEW_PROPERTY(mediaPlaybackRequiresUserAction, BOOL)
RCT_EXPORT_VIEW_PROPERTY(dataDetectorTypes, WKDataDetectorTypes)
RCT_EXPORT_VIEW_PROPERTY(contentInset, UIEdgeInsets)
RCT_EXPORT_VIEW_PROPERTY(automaticallyAdjustContentInsets, BOOL)
RCT_EXPORT_VIEW_PROPERTY(autoManageStatusBarEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(hideKeyboardAccessoryView, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowsBackForwardNavigationGestures, BOOL)
RCT_EXPORT_VIEW_PROPERTY(incognito, BOOL)
RCT_EXPORT_VIEW_PROPERTY(pagingEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(applicationNameForUserAgent, NSString)
RCT_EXPORT_VIEW_PROPERTY(cacheEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowsLinkPreview, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowingReadAccessToURL, NSString)
RCT_EXPORT_VIEW_PROPERTY(basicAuthCredential, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(additionalUserAgent, NSArray<NSDictionary>)

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000 /* __IPHONE_11_0 */
RCT_EXPORT_VIEW_PROPERTY(contentInsetAdjustmentBehavior, UIScrollViewContentInsetAdjustmentBehavior)
#endif
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 /* __IPHONE_13_0 */
RCT_EXPORT_VIEW_PROPERTY(automaticallyAdjustsScrollIndicatorInsets, BOOL)
#endif

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 /* iOS 13 */
RCT_EXPORT_VIEW_PROPERTY(contentMode, WKContentMode)
#endif

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000 /* iOS 14 */
RCT_EXPORT_VIEW_PROPERTY(limitsNavigationsToAppBoundDomains, BOOL)
#endif

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 140500 /* iOS 14.5 */
RCT_EXPORT_VIEW_PROPERTY(textInteractionEnabled, BOOL)
#endif

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 150000 /* iOS 15 */
RCT_EXPORT_VIEW_PROPERTY(mediaCapturePermissionGrantType, RNCWebViewPermissionGrantType)
#endif

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 /* iOS 13 */
RCT_EXPORT_VIEW_PROPERTY(fraudulentWebsiteWarningEnabled, BOOL)
#endif

/**
 * Expose methods to enable messaging the webview.
 */
RCT_EXPORT_VIEW_PROPERTY(messagingEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(onMessage, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onScroll, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(enableApplePay, BOOL)
RCT_EXPORT_VIEW_PROPERTY(menuItems, NSArray);
RCT_EXPORT_VIEW_PROPERTY(suppressMenuItems, NSArray);
RCT_EXPORT_VIEW_PROPERTY(onGetFavicon, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onCaptureScreen, RCTDirectEventBlock)

// New arch only
RCT_CUSTOM_VIEW_PROPERTY(hasOnFileDownload, BOOL, RNCWebViewImpl) {}
RCT_CUSTOM_VIEW_PROPERTY(hasOnOpenWindowEvent, BOOL, RNCWebViewImpl) {}

RCT_EXPORT_VIEW_PROPERTY(onCustomMenuSelection, RCTDirectEventBlock)
RCT_CUSTOM_VIEW_PROPERTY(pullToRefreshEnabled, BOOL, RNCWebViewImpl) {
  view.pullToRefreshEnabled = json == nil ? false : [RCTConvert BOOL: json];
}
RCT_CUSTOM_VIEW_PROPERTY(refreshControlLightMode, BOOL, RNCWebViewImpl) {
    view.refreshControlLightMode = json == nil ? false : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(bounces, BOOL, RNCWebViewImpl) {
  view.bounces = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(useSharedProcessPool, BOOL, RNCWebViewImpl) {
  view.useSharedProcessPool = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(userAgent, NSString, RNCWebViewImpl) {
  view.userAgent = [RCTConvert NSString: json];
}

RCT_CUSTOM_VIEW_PROPERTY(scrollEnabled, BOOL, RNCWebViewImpl) {
  view.scrollEnabled = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(sharedCookiesEnabled, BOOL, RNCWebViewImpl) {
  view.sharedCookiesEnabled = json == nil ? false : [RCTConvert BOOL: json];
}

#if !TARGET_OS_OSX
RCT_CUSTOM_VIEW_PROPERTY(decelerationRate, CGFloat, RNCWebViewImpl) {
  view.decelerationRate = json == nil ? UIScrollViewDecelerationRateNormal : [RCTConvert CGFloat: json];
}
#endif // !TARGET_OS_OSX

RCT_CUSTOM_VIEW_PROPERTY(directionalLockEnabled, BOOL, RNCWebViewImpl) {
  view.directionalLockEnabled = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(showsHorizontalScrollIndicator, BOOL, RNCWebViewImpl) {
  view.showsHorizontalScrollIndicator = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(showsVerticalScrollIndicator, BOOL, RNCWebViewImpl) {
  view.showsVerticalScrollIndicator = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(keyboardDisplayRequiresUserAction, BOOL, RNCWebViewImpl) {
  view.keyboardDisplayRequiresUserAction = json == nil ? true : [RCTConvert BOOL: json];
}

#if !TARGET_OS_OSX
    #define BASE_VIEW_PER_OS() UIView
#else
    #define BASE_VIEW_PER_OS() NSView
#endif

#define QUICK_RCT_EXPORT_COMMAND_METHOD(name)                                                                                           \
RCT_EXPORT_METHOD(name:(nonnull NSNumber *)reactTag)                                                                                    \
{                                                                                                                                       \
[self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, BASE_VIEW_PER_OS() *> *viewRegistry) {   \
    RNCWebViewImpl *view = (RNCWebViewImpl *)viewRegistry[reactTag];                                                                    \
    if (![view isKindOfClass:[RNCWebViewImpl class]]) {                                                                                 \
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);                                         \
    } else {                                                                                                                            \
      [view name];                                                                                                                      \
    }                                                                                                                                   \
  }];                                                                                                                                   \
}
#define QUICK_RCT_EXPORT_COMMAND_METHOD_PARAMS(name, in_param, out_param)                                                               \
RCT_EXPORT_METHOD(name:(nonnull NSNumber *)reactTag in_param)                                                                           \
{                                                                                                                                       \
[self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, BASE_VIEW_PER_OS() *> *viewRegistry) {   \
    RNCWebViewImpl *view = (RNCWebViewImpl *)viewRegistry[reactTag];                                                                    \
    if (![view isKindOfClass:[RNCWebViewImpl class]]) {                                                                                 \
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);                                         \
    } else {                                                                                                                            \
      [view name:out_param];                                                                                                            \
    }                                                                                                                                   \
  }];                                                                                                                                   \
}

QUICK_RCT_EXPORT_COMMAND_METHOD(reload)
QUICK_RCT_EXPORT_COMMAND_METHOD(goBack)
QUICK_RCT_EXPORT_COMMAND_METHOD(goForward)
QUICK_RCT_EXPORT_COMMAND_METHOD(stopLoading)
QUICK_RCT_EXPORT_COMMAND_METHOD(requestFocus)

QUICK_RCT_EXPORT_COMMAND_METHOD_PARAMS(postMessage, message:(NSString *)message, message)
QUICK_RCT_EXPORT_COMMAND_METHOD_PARAMS(injectJavaScript, script:(NSString *)script, script)
QUICK_RCT_EXPORT_COMMAND_METHOD_PARAMS(clearCache, includeDiskFiles:(BOOL)includeDiskFiles, includeDiskFiles)

// Lunascape
// Adblock
RCT_EXPORT_VIEW_PROPERTY(adblockRuleList, NSArray<NSString>)
RCT_EXPORT_VIEW_PROPERTY(adblockAllowList, NSArray<NSString>)
RCT_EXPORT_VIEW_PROPERTY(scrollToTop, BOOL)
RCT_EXPORT_VIEW_PROPERTY(openNewWindowInWebView, BOOL)
RCT_EXPORT_VIEW_PROPERTY(adjustOffset, CGPoint)

RCT_REMAP_METHOD(addContentRuleList,
                 addContentRuleList:(nonnull NSString *)name
                 contentRuleList:(NSString *)encodedContentRuleList
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 11.0, *)) {
            WKContentRuleListStore *contentRuleListStore = WKContentRuleListStore.defaultStore;
            [contentRuleListStore compileContentRuleListForIdentifier:name
                                               encodedContentRuleList:encodedContentRuleList
                                                    completionHandler:^(WKContentRuleList *contentRuleList, NSError *error) {
                if (error) {
                    reject(RCTErrorUnspecified, nil, error);
                } else {
                    resolve(nil);
                }
            }];
        }
    });
}

RCT_REMAP_METHOD(getContentRuleListNames,
                 getContentRuleListNamesWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 11.0, *)) {
        WKContentRuleListStore *contentRuleListStore = WKContentRuleListStore.defaultStore;
        [contentRuleListStore getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
            resolve(identifiers);
        }];
    }
}

RCT_REMAP_METHOD(removeContentRuleList,
                 removeContentRuleList:(nonnull NSString *)name
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 11.0, *)) {
        WKContentRuleListStore *contentRuleListStore = WKContentRuleListStore.defaultStore;
        [contentRuleListStore removeContentRuleListForIdentifier:name
                                               completionHandler:^(NSError *error) {
            if (error) {
                reject(RCTErrorUnspecified, nil, error);
            } else {
                resolve(nil);
            }
        }];
    }
}
// @end Adblock

RCT_EXPORT_METHOD(evaluateJavaScript:(nonnull NSNumber *)reactTag
                  js:(NSString *)js
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCView *> *viewRegistry) {
        RNCView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
        } else {
            [(RNCWebViewImpl *)view evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
                if (error) {
                    reject(@"js_error", @"Error occurred while evaluating Javascript", error);
                } else {
                    resolve(result);
                }
            }];
        }
    }];
}

RCT_EXPORT_METHOD(captureScreen:(nonnull NSNumber *)reactTag)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCView *> *viewRegistry) {
        RNCView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
        } else {
            [(RNCWebViewImpl *)view captureScreen];
        }
    }];
}

RCT_EXPORT_METHOD(findInPage:(nonnull NSNumber *)reactTag searchString:(NSString *)searchString)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCView *> *viewRegistry) {
        RNCView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
        } else {
            [(RNCWebViewImpl *)view findInPage:searchString];
        }
    }];
}

RCT_EXPORT_METHOD(findNext:(nonnull NSNumber *)reactTag) {
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCView *> *viewRegistry) {
        RNCView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
        } else {
            [(RNCWebViewImpl *)view findNext];
        }
    }];
}

RCT_EXPORT_METHOD(findPrevious:(nonnull NSNumber *)reactTag) {
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCView *> *viewRegistry) {
        RNCView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
        } else {
            [(RNCWebViewImpl *)view findPrevious];
        }
    }];
}

RCT_EXPORT_METHOD(removeAllHighlights:(nonnull NSNumber *)reactTag) {
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCView *> *viewRegistry) {
        RNCView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
        } else {
            [(RNCWebViewImpl *)view removeAllHighlights];
        }
    }];
}

RCT_EXPORT_METHOD(printContent:(nonnull NSNumber *)reactTag) {
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCView *> *viewRegistry) {
        RNCView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
        } else {
            [(RNCWebViewImpl *)view printContent];
        }
    }];
}

RCT_EXPORT_METHOD(setFontSize:(nonnull NSNumber *)reactTag size:(nonnull NSNumber *)size) {
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        if (![viewRegistry[reactTag] isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebViewImpl");
        } else {
            RNCWebViewImpl *view = (RNCWebViewImpl *)viewRegistry[reactTag];
            [view setFontSize:size];
        }
    }];
}

RCT_EXPORT_METHOD(setEnableNightMode:(nonnull NSNumber *)reactTag enable:(nonnull NSString *)enable)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCView *> *viewRegistry) {
        RNCView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
        } else {
            [(RNCWebViewImpl *)view setEnableNightMode:enable];
        }
    }];
}

RCT_EXPORT_METHOD(proceedUnsafeSite:(nonnull NSNumber *)reactTag url:(nonnull NSString *)url)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCView *> *viewRegistry) {
        RNCView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNCWebViewImpl class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
        } else {
            [(RNCWebViewImpl *)view proceedUnsafeSite:url];
        }
    }];
}

@end
