/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RNCWebViewManager.h"

#import <React/RCTUIManager.h>
#import <React/RCTDefines.h>
#import "RNCWebView.h"

@interface RNCWebViewManager () <RNCWebViewDelegate>
@end

@implementation RCTConvert (UIScrollView)

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000 /* __IPHONE_11_0 */
RCT_ENUM_CONVERTER(UIScrollViewContentInsetAdjustmentBehavior, (@{
                                                                  @"automatic": @(UIScrollViewContentInsetAdjustmentAutomatic),
                                                                  @"scrollableAxes": @(UIScrollViewContentInsetAdjustmentScrollableAxes),
                                                                  @"never": @(UIScrollViewContentInsetAdjustmentNever),
                                                                  @"always": @(UIScrollViewContentInsetAdjustmentAlways),
                                                                  }), UIScrollViewContentInsetAdjustmentNever, integerValue)
#endif

@end

@implementation RNCWebViewManager
{
  NSMutableDictionary* shouldStartRequestConditions;
  NSConditionLock *_shouldStartLoadLock;
  BOOL _shouldStartLoad;
  NSConditionLock* createNewWindowCondition;
  BOOL createNewWindowResult;
  RNCWebView* newWindow;
}

RCT_EXPORT_MODULE()

- (UIView *)view
{
  RNCWebView *webView = newWindow ? newWindow : [RNCWebView new];
  webView.delegate = self;
  newWindow = nil;
  return webView;
}

RCT_EXPORT_VIEW_PROPERTY(source, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(onLoadingStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingFinish, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingProgress, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onHttpError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onShouldStartLoadWithRequest, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onContentProcessDidTerminate, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(injectedJavaScript, NSString)
RCT_EXPORT_VIEW_PROPERTY(injectedJavaScriptBeforeDocumentLoad, NSString)
RCT_EXPORT_VIEW_PROPERTY(javaScriptEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowsInlineMediaPlayback, BOOL)
RCT_EXPORT_VIEW_PROPERTY(mediaPlaybackRequiresUserAction, BOOL)
#if WEBKIT_IOS_10_APIS_AVAILABLE
RCT_EXPORT_VIEW_PROPERTY(dataDetectorTypes, WKDataDetectorTypes)
#endif
RCT_EXPORT_VIEW_PROPERTY(contentInset, UIEdgeInsets)
RCT_EXPORT_VIEW_PROPERTY(automaticallyAdjustContentInsets, BOOL)
RCT_EXPORT_VIEW_PROPERTY(hideKeyboardAccessoryView, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowsBackForwardNavigationGestures, BOOL)
RCT_EXPORT_VIEW_PROPERTY(incognito, BOOL)
RCT_EXPORT_VIEW_PROPERTY(pagingEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(userAgent, NSString)
RCT_EXPORT_VIEW_PROPERTY(downloadConfig, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(applicationNameForUserAgent, NSString)
RCT_EXPORT_VIEW_PROPERTY(cacheEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowsLinkPreview, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowingReadAccessToURL, NSString)

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000 /* __IPHONE_11_0 */
RCT_EXPORT_VIEW_PROPERTY(contentInsetAdjustmentBehavior, UIScrollViewContentInsetAdjustmentBehavior)
#endif

RCT_EXPORT_VIEW_PROPERTY(scrollToTop, BOOL)
RCT_EXPORT_VIEW_PROPERTY(openNewWindowInWebView, BOOL)
RCT_EXPORT_VIEW_PROPERTY(adjustOffset, CGPoint)
RCT_EXPORT_VIEW_PROPERTY(onShouldCreateNewWindow, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onNavigationStateChange, RCTDirectEventBlock)

/**
 * Expose methods to enable messaging the webview.
 */
RCT_EXPORT_VIEW_PROPERTY(messagingEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(onMessage, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onGetFavicon, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onFileDownload, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onScroll, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onWebViewClosed, RCTDirectEventBlock)

RCT_EXPORT_VIEW_PROPERTY(contentRuleLists, NSArray<NSString>)
RCT_EXPORT_VIEW_PROPERTY(adBlockAllowList, NSArray<NSString>)
RCT_EXPORT_VIEW_PROPERTY(additionalUserAgent, NSArray<NSDictionary>)

RCT_EXPORT_METHOD(postMessage:(nonnull NSNumber *)reactTag message:(NSString *)message)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view postMessage:message];
    }
  }];
}

RCT_CUSTOM_VIEW_PROPERTY(bounces, BOOL, RNCWebView) {
  view.bounces = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(useSharedProcessPool, BOOL, RNCWebView) {
  view.useSharedProcessPool = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(scrollEnabled, BOOL, RNCWebView) {
  view.scrollEnabled = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(sharedCookiesEnabled, BOOL, RNCWebView) {
    view.sharedCookiesEnabled = json == nil ? false : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(decelerationRate, CGFloat, RNCWebView) {
  view.decelerationRate = json == nil ? UIScrollViewDecelerationRateNormal : [RCTConvert CGFloat: json];
}

RCT_CUSTOM_VIEW_PROPERTY(directionalLockEnabled, BOOL, RNCWebView) {
    view.directionalLockEnabled = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(showsHorizontalScrollIndicator, BOOL, RNCWebView) {
  view.showsHorizontalScrollIndicator = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(showsVerticalScrollIndicator, BOOL, RNCWebView) {
  view.showsVerticalScrollIndicator = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_CUSTOM_VIEW_PROPERTY(keyboardDisplayRequiresUserAction, BOOL, RNCWebView) {
  view.keyboardDisplayRequiresUserAction = json == nil ? true : [RCTConvert BOOL: json];
}

RCT_EXPORT_METHOD(injectJavaScript:(nonnull NSNumber *)reactTag script:(NSString *)script)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view injectJavaScript:script];
    }
  }];
}

RCT_EXPORT_METHOD(goBack:(nonnull NSNumber *)reactTag)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view goBack];
    }
  }];
}

RCT_EXPORT_METHOD(goForward:(nonnull NSNumber *)reactTag)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view goForward];
    }
  }];
}

RCT_EXPORT_METHOD(reload:(nonnull NSNumber *)reactTag)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view reload];
    }
  }];
}

RCT_EXPORT_METHOD(stopLoading:(nonnull NSNumber *)reactTag)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view stopLoading];
    }
  }];
}

RCT_EXPORT_METHOD(evaluateJavaScript:(nonnull NSNumber *)reactTag
                  js:(NSString *)js
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (error) {
          reject(@"js_error", @"Error occurred while evaluating Javascript", error);
        } else {
          resolve(result);
        }
      }];
    }
  }];
}

RCT_EXPORT_METHOD(captureScreen:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
        [view captureScreen:^(NSString * _Nullable path) {
            resolve(path);
        }];
    }
  }];
}

RCT_EXPORT_METHOD(capturePage:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view capturePage:^(NSString * _Nullable path) {
          resolve(path);
      }];
    }
  }];
}

RCT_EXPORT_METHOD(findInPage:(nonnull NSNumber *)reactTag searchString:(NSString *)searchString
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view findInPage:searchString];
    }
  }];
}
RCT_EXPORT_METHOD(setFontSize:(nonnull NSNumber *)reactTag size:(nonnull NSNumber *)size
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view setFontSize:size];
    }
  }];
}

RCT_EXPORT_METHOD(findNext:(nonnull NSNumber *)reactTag) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view findNext];
    }
  }];
}

RCT_EXPORT_METHOD(findPrevious:(nonnull NSNumber *)reactTag) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view findPrevious];
    }
  }];
}

RCT_EXPORT_METHOD(removeAllHighlights:(nonnull NSNumber *)reactTag) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view removeAllHighlights];
    }
  }];
}

RCT_EXPORT_METHOD(printContent:(nonnull NSNumber *)reactTag) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view printContent];
    }
  }];
}

RCT_EXPORT_METHOD(setEnableNightMode:(nonnull NSNumber *)reactTag enable:(NSString *)enable
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNCWebView *> *viewRegistry) {
    RNCWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RNCWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RNCWebView, got: %@", view);
    } else {
      [view setEnableNightMode:enable];
    }
  }];
}

#pragma mark - Exported synchronous methods

- (BOOL)          webView:(RNCWebView *)webView
shouldStartLoadForRequest:(NSMutableDictionary<NSString *, id> *)request
             withCallback:(RCTDirectEventBlock)callback
{
  NSConditionLock *condition = [[NSConditionLock alloc] initWithCondition:arc4random()];
  NSString* key = @(condition.condition).stringValue;
  if (!shouldStartRequestConditions) {
    shouldStartRequestConditions = @{}.mutableCopy;
  }
  [shouldStartRequestConditions setObject:@{@"result": @(YES), @"condition": condition} forKey:key];
  request[@"lockIdentifier"] = @(condition.condition);
  callback(request);
  
  // Block the main thread for a maximum of 250ms until the JS thread returns
  if ([condition lockWhenCondition:0 beforeDate:[NSDate dateWithTimeIntervalSinceNow:.25]]) {
    BOOL returnValue = [[[shouldStartRequestConditions objectForKey:key] objectForKey:@"result"] boolValue];
    [condition unlock];
    [shouldStartRequestConditions removeObjectForKey:key];
    return returnValue;
  } else {
    RCTLogWarn(@"Did not receive response to shouldStartLoad in time, defaulting to YES");
    return YES;
  }
}

RCT_EXPORT_METHOD(startLoadWithResult:(BOOL)result lockIdentifier:(NSInteger)lockIdentifier)
{
  NSString* key = @(lockIdentifier).stringValue;
  NSConditionLock* condition = [[shouldStartRequestConditions objectForKey:key] objectForKey:@"condition"];
  if (condition && [condition tryLockWhenCondition:lockIdentifier]) {
    [shouldStartRequestConditions setObject:@{@"result": @(result), @"condition": condition} forKey:key];
    [condition unlockWithCondition:0];
  } else {
    RCTLogWarn(@"startLoadWithResult invoked with invalid lockIdentifier: "
               "got %zd, expected %zd", lockIdentifier, condition.condition);
  }
}

- (RNCWebView*)webView:(__unused RNCWebView *)webView
 shouldCreateNewWindow:(NSMutableDictionary<NSString *, id> *)request
     withConfiguration:(WKWebViewConfiguration*)configuration
          withCallback:(RCTDirectEventBlock)callback
{
  createNewWindowCondition = [[NSConditionLock alloc] initWithCondition:arc4random()];
  createNewWindowResult = YES;
  request[@"lockIdentifier"] = @(createNewWindowCondition.condition);
  callback(request);
  
  // Block the main thread for a maximum of 250ms until the JS thread returns
  if ([createNewWindowCondition lockWhenCondition:0 beforeDate:[NSDate dateWithTimeIntervalSinceNow:.25]]) {
    [createNewWindowCondition unlock];
    createNewWindowCondition = nil;
    if (createNewWindowResult) {
      newWindow = [[RNCWebView alloc] initWithConfiguration:configuration from:webView];
      return newWindow;
    } else {
      return nil;
    }
  } else {
    RCTLogWarn(@"Did not receive response to shouldCreateNewWindow in time, defaulting to YES");
    newWindow = [[RNCWebView alloc] initWithConfiguration:configuration from:webView];
    return newWindow;
  }
}

RCT_EXPORT_METHOD(createNewWindowWithResult:(BOOL)result lockIdentifier:(NSInteger)lockIdentifier)
{
  if (createNewWindowCondition && [createNewWindowCondition tryLockWhenCondition:lockIdentifier]) {
    createNewWindowResult = result;
    [createNewWindowCondition unlockWithCondition:0];
  } else {
    RCTLogWarn(@"createNewWindowWithResult invoked with invalid lockIdentifier: "
              "got %zd, expected %zd", lockIdentifier, createNewWindowCondition.condition);
  }
}

RCT_REMAP_METHOD(addContentRuleList,
                 addContentRuleList:(nonnull NSString *)name
                 contentRuleList:(NSString *)encodedContentRuleList
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  WKContentRuleListStore *contentRuleListStore = WKContentRuleListStore.defaultStore;

  [contentRuleListStore compileContentRuleListForIdentifier:name encodedContentRuleList:encodedContentRuleList completionHandler:^(WKContentRuleList *contentRuleList, NSError *error) {
      if (error) {
          reject(RCTErrorUnspecified, nil, error);
      } else {
          resolve(nil);
      }
  }];
}

RCT_REMAP_METHOD(getContentRuleListNames,
                 getContentRuleListNamesWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{

  WKContentRuleListStore *contentRuleListStore = WKContentRuleListStore.defaultStore;

  [contentRuleListStore getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
    resolve(identifiers);
  }];
}

RCT_REMAP_METHOD(removeContentRuleList,
                 removeContentRuleList:(nonnull NSString *)name
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  WKContentRuleListStore *contentRuleListStore = WKContentRuleListStore.defaultStore;

  [contentRuleListStore removeContentRuleListForIdentifier:name completionHandler:^(NSError *error) {
      if (error) {
          reject(RCTErrorUnspecified, nil, error);
      } else {
          resolve(nil);
      }
  }];
}

@end
