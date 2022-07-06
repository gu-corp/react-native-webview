import React, { forwardRef, useCallback, useImperativeHandle, useMemo, useRef } from 'react';
import {
  Image,
  View,
  NativeModules,
  findNodeHandle,
  ImageSourcePropType,
} from 'react-native';
import invariant from 'invariant';

// @ts-expect-error react-native doesn't have this type
import codegenNativeCommandsUntyped from 'react-native/Libraries/Utilities/codegenNativeCommands';
import RNCWebView from "./WebViewNativeComponent.ios";
import {
  defaultOriginWhitelist,
  defaultRenderError,
  defaultRenderLoading,
  createOnShouldCreateNewWindow,
  useWebWiewLogic,
} from './WebViewShared';
import {
  IOSWebViewProps,
  DecelerationRateConstant,
  NativeWebViewIOS,
  ViewManager,
} from './WebViewTypes';

import styles from './WebView.styles';


const codegenNativeCommands = codegenNativeCommandsUntyped as <T extends {}>(options: { supportedCommands: (keyof T)[] }) => T;

const Commands = codegenNativeCommands({
  supportedCommands: ['goBack', 'goForward', 'reload', 'stopLoading', 'injectJavaScript', 'requestFocus', 'postMessage', 'loadUrl', 'evaluateJavaScript', 'captureScreen', 'capturePage', 'printContent', 'findInPage', 'findNext', 'findPrevious', 'removeAllHighlights'],
});

const { resolveAssetSource } = Image;
const processDecelerationRate = (
  decelerationRate: DecelerationRateConstant | number | undefined,
) => {
  let newDecelerationRate = decelerationRate;
  if (newDecelerationRate === 'normal') {
    newDecelerationRate = 0.998;
  } else if (newDecelerationRate === 'fast') {
    newDecelerationRate = 0.99;
  }
  return newDecelerationRate;
};

const RNCWebViewManager = NativeModules.RNCWebViewManager as ViewManager;

const useWarnIfChanges = <T extends unknown>(value: T, name: string) => {
  const ref = useRef(value);
  if (ref.current !== value) {
    console.warn(`Changes to property ${name} do nothing after the initial render.`);
    ref.current = value;
  }
}

const WebViewComponent = forwardRef<{}, IOSWebViewProps>(({
  javaScriptEnabled = true,
  cacheEnabled = true,
  originWhitelist = defaultOriginWhitelist,
  useSharedProcessPool= true,
  textInteractionEnabled= true,
  injectedJavaScript,
  injectedJavaScriptBeforeContentLoaded,
  injectedJavaScriptForMainFrameOnly = true,
  injectedJavaScriptBeforeContentLoadedForMainFrameOnly = true,
  startInLoadingState,
  onNavigationStateChange,
  onLoadStart,
  onError,
  onLoad,
  onLoadEnd,
  onLoadProgress,
  onContentProcessDidTerminate: onContentProcessDidTerminateProp,
  onFileDownload,
  onHttpError: onHttpErrorProp,
  onMessage: onMessageProp,
  renderLoading,
  renderError,
  style,
  containerStyle,
  source,
  nativeConfig,
  allowsInlineMediaPlayback,
  allowsAirPlayForMediaPlayback,
  mediaPlaybackRequiresUserAction,
  dataDetectorTypes,
  incognito,
  decelerationRate: decelerationRateProp,
  onShouldStartLoadWithRequest: onShouldStartLoadWithRequestProp,
  onShouldCreateNewWindow: onShouldCreateNewWindowProp,
  ...otherProps
}, ref) => {
  const webViewRef = useRef<NativeWebViewIOS | null>(null);

  const onShouldStartLoadWithRequestCallback = useCallback((
    shouldStart: boolean,
    _url: string,
    lockIdentifier = 0,
  ) => {
    const viewManager
      = (nativeConfig?.viewManager)
      || RNCWebViewManager;

    viewManager.startLoadWithResult(!!shouldStart, lockIdentifier);
  }, [nativeConfig?.viewManager]);

  const getWebViewHandle = () => {
    const nodeHandle = findNodeHandle(webViewRef.current);
    invariant(nodeHandle != null, 'nodeHandle expected to be non-null');
    return nodeHandle as number;
  };

  const onShouldCreateNewWindowCallback = useCallback((
    shouldCreate: boolean,
    _url: string,
    lockIdentifier: number,
  ) => {
    const viewManager
      = (nativeConfig?.viewManager)
      || RNCWebViewManager;

    viewManager.createNewWindowWithResult(!!shouldCreate, lockIdentifier);
  }, [nativeConfig?.viewManager]);

  const { onLoadingStart, onShouldStartLoadWithRequest, onMessage, viewState, setViewState, lastErrorEvent, onHttpError, onLoadingError, onLoadingFinish, onLoadingProgress, onContentProcessDidTerminate } = useWebWiewLogic({
    onNavigationStateChange,
    onLoad,
    onError,
    onHttpErrorProp,
    onLoadEnd,
    onLoadProgress,
    onLoadStart,
    onMessageProp,
    startInLoadingState,
    originWhitelist,
    onShouldStartLoadWithRequestProp,
    onShouldStartLoadWithRequestCallback,
    onContentProcessDidTerminateProp,
  });

  useImperativeHandle(ref, () => ({
    goForward: () => Commands.goForward(webViewRef.current),
    goBack: () => Commands.goBack(webViewRef.current),
    reload: () => {
      setViewState(
        'LOADING',
      ); Commands.reload(webViewRef.current)
    },
    stopLoading: () => Commands.stopLoading(webViewRef.current),
    postMessage: (data: string) => Commands.postMessage(webViewRef.current, data),
    injectJavaScript: (data: string) => Commands.injectJavaScript(webViewRef.current, data),
    requestFocus: () => Commands.requestFocus(webViewRef.current),
    evaluateJavaScript: (js: string) => RNCWebViewManager.evaluateJavaScript(getWebViewHandle(), js),
    captureScreen: () => RNCWebViewManager.captureScreen(getWebViewHandle()),
    capturePage: () => RNCWebViewManager.capturePage(getWebViewHandle()),
    printContent: () => RNCWebViewManager.printContent(getWebViewHandle()),
    findInPage: (searchString: string) => RNCWebViewManager.findInPage(getWebViewHandle(), searchString),
    findNext: () => RNCWebViewManager.findNext(getWebViewHandle()),
    findPrevious: () => RNCWebViewManager.findPrevious(getWebViewHandle()),
    removeAllHighlights: () => RNCWebViewManager.removeAllHighlights(getWebViewHandle()),
    setNativeProps: (nativeProps: Partial<IOSWebViewProps>) => {
      try {
        if (webViewRef.current) {
          webViewRef.current.setNativeProps(nativeProps);
        }
      } catch (err) {
        console.log(err);
      }
    },
  }), [setViewState, webViewRef]);

  const onShouldCreateNewWindow = useMemo(() => createOnShouldCreateNewWindow(
    onShouldCreateNewWindowCallback,
    onShouldCreateNewWindowProp,
  ), [onShouldCreateNewWindowCallback, onShouldCreateNewWindowProp]);

  useWarnIfChanges(allowsInlineMediaPlayback, 'allowsInlineMediaPlayback');
  useWarnIfChanges(allowsAirPlayForMediaPlayback, 'allowsAirPlayForMediaPlayback');
  useWarnIfChanges(incognito, 'incognito');
  useWarnIfChanges(mediaPlaybackRequiresUserAction, 'mediaPlaybackRequiresUserAction');
  useWarnIfChanges(dataDetectorTypes, 'dataDetectorTypes');

  let otherView = null;
  if (viewState === 'LOADING') {
    otherView = (renderLoading || defaultRenderLoading)();
  } else if (viewState === 'ERROR') {
    invariant(lastErrorEvent != null, 'lastErrorEvent expected to be non-null');
    otherView = (renderError || defaultRenderError)(
      lastErrorEvent.domain,
      lastErrorEvent.code,
      lastErrorEvent.description,
    );
  } else if (viewState !== 'IDLE') {
    console.error(`RNCWebView invalid state encountered: ${viewState}`);
  }

  const webViewStyles = [styles.container, styles.webView, style];
  const webViewContainerStyle = [styles.container, containerStyle];

  const decelerationRate = processDecelerationRate(decelerationRateProp);

  const NativeWebView
  = (nativeConfig?.component as typeof NativeWebViewIOS | undefined)
  || RNCWebView;

  const webView = (
    <NativeWebView
      key="webViewKey"
      {...otherProps}
      javaScriptEnabled={javaScriptEnabled}
      cacheEnabled={cacheEnabled}
      useSharedProcessPool={useSharedProcessPool}
      textInteractionEnabled={textInteractionEnabled}
      decelerationRate={decelerationRate}
      messagingEnabled={typeof onMessage === 'function'}
      onLoadingError={onLoadingError}
      onLoadingFinish={onLoadingFinish}
      onLoadingProgress={onLoadingProgress}
      onFileDownload={onFileDownload}
      onLoadingStart={onLoadingStart}
      onHttpError={onHttpError}
      onMessage={onMessage}
      onShouldStartLoadWithRequest={onShouldStartLoadWithRequest}
      onShouldCreateNewWindow={onShouldCreateNewWindow}
      onContentProcessDidTerminate={onContentProcessDidTerminate}
      injectedJavaScript={injectedJavaScript}
      injectedJavaScriptBeforeContentLoaded={injectedJavaScriptBeforeContentLoaded}
      injectedJavaScriptForMainFrameOnly={injectedJavaScriptForMainFrameOnly}
      injectedJavaScriptBeforeContentLoadedForMainFrameOnly={injectedJavaScriptBeforeContentLoadedForMainFrameOnly}
      dataDetectorTypes={dataDetectorTypes}
      allowsAirPlayForMediaPlayback={allowsAirPlayForMediaPlayback}
      allowsInlineMediaPlayback={allowsInlineMediaPlayback}
      incognito={incognito}
      mediaPlaybackRequiresUserAction={mediaPlaybackRequiresUserAction}
      ref={webViewRef}
      // TODO: find a better way to type this.
      source={resolveAssetSource(source as ImageSourcePropType)}
      style={webViewStyles}
      {...nativeConfig?.props}
    />
  );

  return (
    <View style={webViewContainerStyle}>
      {webView}
      {otherView}
    </View>
  );})

// no native implementation for iOS, depends only on permissions
const isFileUploadSupported: () => Promise<boolean>
  = async () => true;

const WebView = Object.assign(WebViewComponent, {isFileUploadSupported});

export default WebView;
