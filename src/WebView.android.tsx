import React, {
  forwardRef,
  ReactElement,
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
} from 'react';

import { Image, View, ImageSourcePropType, HostComponent } from 'react-native';

import BatchedBridge from 'react-native/Libraries/BatchedBridge/BatchedBridge';
import EventEmitter from 'react-native/Libraries/vendor/emitter/EventEmitter';

import invariant from 'invariant';

import RNCWebView, { Commands, NativeProps } from './RNCWebViewNativeComponent';
import RNCWebViewModule from './NativeRNCWebViewModule';
import {
  defaultOriginWhitelist,
  defaultRenderError,
  defaultRenderLoading,
  useWebViewLogic,
} from './WebViewShared';
import {
  AndroidWebViewProps,
  WebViewSourceUri,
  type WebViewMessageEvent,
  type ShouldStartLoadRequestEvent,
  WebViewProgressEvent,
} from './WebViewTypes';

import styles from './WebView.styles';

const { resolveAssetSource } = Image;

const directEventEmitter = new EventEmitter();

const registerCallableModule: (name: string, module: Object) => void =
  // `registerCallableModule()` is available in React Native 0.74 and above.
  // Fallback to use `BatchedBridge.registerCallableModule()` for older versions.

  require('react-native').registerCallableModule ??
  BatchedBridge.registerCallableModule.bind(BatchedBridge);

registerCallableModule('RNCWebViewMessagingModule', {
  onShouldStartLoadWithRequest: (
    event: ShouldStartLoadRequestEvent & { messagingModuleName?: string }
  ) => {
    directEventEmitter.emit('onShouldStartLoadWithRequest', event);
  },
  onMessage: (
    event: WebViewMessageEvent & { messagingModuleName?: string }
  ) => {
    directEventEmitter.emit('onMessage', event);
  },
});

/**
 * A simple counter to uniquely identify WebView instances. Do not use this for anything else.
 */
let uniqueRef = 0;

const WebViewComponent = forwardRef<{}, AndroidWebViewProps>(
  (
    {
      overScrollMode = 'always',
      javaScriptEnabled = true,
      thirdPartyCookiesEnabled = true,
      scalesPageToFit = true,
      allowsFullscreenVideo = false,
      allowFileAccess = false,
      saveFormDataDisabled = false,
      cacheEnabled = true,
      androidLayerType = 'none',
      originWhitelist = defaultOriginWhitelist,
      setSupportMultipleWindows = true,
      setBuiltInZoomControls = true,
      setDisplayZoomControls = false,
      nestedScrollEnabled = false,
      startInLoadingState,
      onNavigationStateChange,
      onLoadStart,
      onError,
      onLoad,
      onLoadEnd,
      onLoadProgress,
      onHttpError: onHttpErrorProp,
      onRenderProcessGone: onRenderProcessGoneProp,
      onMessage: onMessageProp,
      onOpenWindow: onOpenWindowProp,
      renderLoading,
      renderError,
      style,
      containerStyle,
      source,
      nativeConfig,
      onShouldStartLoadWithRequest: onShouldStartLoadWithRequestProp,
      injectedJavaScriptObject,
      ...otherProps
    },
    ref
  ) => {
    const messagingModuleName = useRef<string>(
      `WebViewMessageHandler${(uniqueRef += 1)}`
    ).current;
    const webViewRef = useRef<React.ComponentRef<
      HostComponent<NativeProps>
    > | null>(null);

    const onShouldStartLoadWithRequestCallback = useCallback(
      (shouldStart: boolean, url: string, lockIdentifier?: number) => {
        if (lockIdentifier) {
          RNCWebViewModule.shouldStartLoadWithLockIdentifier(
            shouldStart,
            lockIdentifier
          );
        } else if (shouldStart && webViewRef.current) {
          Commands.loadUrl(webViewRef.current, url);
        }
      },
      []
    );

    const {
      onLoadingStart,
      onShouldStartLoadWithRequest,
      onMessage,
      viewState,
      setViewState,
      lastErrorEvent,
      onHttpError,
      onLoadingError,
      onLoadingFinish,
      onLoadingProgress,
      onOpenWindow,
      onRenderProcessGone,
    } = useWebViewLogic({
      onNavigationStateChange,
      onLoad,
      onError,
      onHttpErrorProp,
      onLoadEnd,
      onLoadProgress,
      onLoadStart,
      onRenderProcessGoneProp,
      onMessageProp,
      onOpenWindowProp,
      startInLoadingState,
      originWhitelist,
      onShouldStartLoadWithRequestProp,
      onShouldStartLoadWithRequestCallback,
    });

    useImperativeHandle(
      ref,
      () => ({
        goForward: () =>
          webViewRef.current && Commands.goForward(webViewRef.current),
        goBack: () => webViewRef.current && Commands.goBack(webViewRef.current),
        reload: () => {
          setViewState('LOADING');
          if (webViewRef.current) {
            Commands.reload(webViewRef.current);
          }
        },
        stopLoading: () =>
          webViewRef.current && Commands.stopLoading(webViewRef.current),
        postMessage: (data: string) =>
          webViewRef.current && Commands.postMessage(webViewRef.current, data),
        injectJavaScript: (data: string) =>
          webViewRef.current &&
          Commands.injectJavaScript(webViewRef.current, data),
        requestFocus: () =>
          webViewRef.current && Commands.requestFocus(webViewRef.current),
        clearFormData: () =>
          webViewRef.current && Commands.clearFormData(webViewRef.current),
        clearCache: (includeDiskFiles: boolean) =>
          webViewRef.current &&
          Commands.clearCache(webViewRef.current, includeDiskFiles),
        clearHistory: () =>
          webViewRef.current && Commands.clearHistory(webViewRef.current),
        requestWebViewStatus: () => {
          webViewRef.current &&
            Commands.requestWebViewStatus(webViewRef.current);
        },
        requestWebFavicon: () => {
          webViewRef.current && Commands.requestWebFavicon(webViewRef.current);
        },
        captureScreen: (type: string) => {
          webViewRef.current &&
            Commands.captureScreen(webViewRef.current, type);
        },
        findInPage: (data: string) => {
          webViewRef.current && Commands.findInPage(webViewRef.current, data);
        },
        findNext: () => {
          webViewRef.current && Commands.findNext(webViewRef.current);
        },
        findPrevious: () => {
          webViewRef.current && Commands.findPrevious(webViewRef.current);
        },
        removeAllHighlights: () => {
          webViewRef.current &&
            Commands.removeAllHighlights(webViewRef.current);
        },
      }),
      [setViewState, webViewRef]
    );

    useEffect(() => {
      const onShouldStartLoadWithRequestSubscription =
        directEventEmitter.addListener(
          'onShouldStartLoadWithRequest',
          (
            event: ShouldStartLoadRequestEvent & {
              messagingModuleName?: string;
            }
          ) => {
            if (event.messagingModuleName === messagingModuleName) {
              // eslint-disable-next-line @typescript-eslint/no-unused-vars
              const { messagingModuleName: _, ...rest } = event;
              onShouldStartLoadWithRequest(rest);
            }
          }
        );

      const onMessageSubscription = directEventEmitter.addListener(
        'onMessage',
        (event: WebViewMessageEvent & { messagingModuleName?: string }) => {
          if (event.messagingModuleName === messagingModuleName) {
            // eslint-disable-next-line @typescript-eslint/no-unused-vars
            const { messagingModuleName: _, ...rest } = event;
            onMessage(rest);
          }
        }
      );

      return () => {
        onShouldStartLoadWithRequestSubscription.remove();
        onMessageSubscription.remove();
      };
    }, [messagingModuleName, onMessage, onShouldStartLoadWithRequest]);

    let otherView: ReactElement | undefined;
    if (viewState === 'LOADING') {
      otherView = (renderLoading || defaultRenderLoading)();
    } else if (viewState === 'ERROR') {
      invariant(
        lastErrorEvent != null,
        'lastErrorEvent expected to be non-null'
      );
      if (lastErrorEvent) {
        otherView = (renderError || defaultRenderError)(
          lastErrorEvent.domain,
          lastErrorEvent.code,
          lastErrorEvent.description
        );
      }
    } else if (viewState !== 'IDLE') {
      console.error(`RNCWebView invalid state encountered: ${viewState}`);
    }

    const webViewStyles = [styles.container, styles.webView, style];
    const webViewContainerStyle = [styles.container, containerStyle];

    if (typeof source !== 'number' && source && 'method' in source) {
      if (source.method === 'POST' && source.headers) {
        console.warn(
          'WebView: `source.headers` is not supported when using POST.'
        );
      } else if (source.method === 'GET' && source.body) {
        console.warn('WebView: `source.body` is not supported when using GET.');
      }
    }

    const NativeWebView =
      (nativeConfig?.component as typeof RNCWebView | undefined) || RNCWebView;

    const sourceResolved = resolveAssetSource(source as ImageSourcePropType);
    const newSource =
      typeof sourceResolved === 'object'
        ? Object.entries(sourceResolved as WebViewSourceUri).reduce(
            (prev, [currKey, currValue]) => {
              return {
                ...prev,
                [currKey]:
                  currKey === 'headers' &&
                  currValue &&
                  typeof currValue === 'object'
                    ? Object.entries(currValue).map(([key, value]) => {
                        return {
                          name: key,
                          value,
                        };
                      })
                    : currValue,
              };
            },
            {}
          )
        : sourceResolved;

    const onReceiveWebViewStatus = (event: WebViewProgressEvent) => {
      if (otherProps?.onReceiveWebViewStatus) {
        otherProps?.onReceiveWebViewStatus(event);
      }
    };

    const onGetFavicon = (event: WebViewMessageEvent) => {
      if (otherProps?.onGetFavicon) {
        otherProps?.onGetFavicon(event);
      }
    };

    const onCaptureScreen = (event: WebViewMessageEvent) => {
      if (otherProps?.onCaptureScreen) {
        otherProps?.onCaptureScreen(event.nativeEvent);
      }
    };

    const webView = (
      <NativeWebView
        key="webViewKey"
        {...otherProps}
        messagingEnabled={typeof onMessageProp === 'function'}
        messagingModuleName={messagingModuleName}
        hasOnScroll={!!otherProps.onScroll}
        onLoadingError={onLoadingError}
        onLoadingFinish={onLoadingFinish}
        onLoadingProgress={onLoadingProgress}
        onLoadingStart={onLoadingStart}
        onHttpError={onHttpError}
        onRenderProcessGone={onRenderProcessGone}
        onMessage={onMessage}
        onOpenWindow={onOpenWindow}
        hasOnOpenWindowEvent={onOpenWindowProp !== undefined}
        onShouldStartLoadWithRequest={onShouldStartLoadWithRequest}
        ref={webViewRef}
        // TODO: find a better way to type this.
        // @ts-expect-error source is old arch
        source={sourceResolved}
        newSource={newSource}
        style={webViewStyles}
        overScrollMode={overScrollMode}
        javaScriptEnabled={javaScriptEnabled}
        thirdPartyCookiesEnabled={thirdPartyCookiesEnabled}
        scalesPageToFit={scalesPageToFit}
        allowsFullscreenVideo={allowsFullscreenVideo}
        allowFileAccess={allowFileAccess}
        saveFormDataDisabled={saveFormDataDisabled}
        cacheEnabled={cacheEnabled}
        androidLayerType={androidLayerType}
        setSupportMultipleWindows={setSupportMultipleWindows}
        setBuiltInZoomControls={setBuiltInZoomControls}
        setDisplayZoomControls={setDisplayZoomControls}
        nestedScrollEnabled={nestedScrollEnabled}
        injectedJavaScriptObject={JSON.stringify(injectedJavaScriptObject)}
        onGetFavicon={onGetFavicon}
        onReceiveWebViewStatus={onReceiveWebViewStatus}
        onCaptureScreen={onCaptureScreen}
        {...nativeConfig?.props}
      />
    );

    return (
      <View style={webViewContainerStyle}>
        {webView}
        {otherView}
      </View>
    );
  }
);

// native implementation should return "true" only for Android 5+
const { isFileUploadSupported } = RNCWebViewModule;

const WebView = Object.assign(WebViewComponent, { isFileUploadSupported });

export default WebView;
