import escapeStringRegexp from 'escape-string-regexp';
import React from 'react';
import { Linking, View, ActivityIndicator, Text, NativeModules } from 'react-native';
import {
  WebViewNavigationEvent,
  OnShouldStartLoadWithRequest,
  OnShouldCreateNewWindow,
} from './WebViewTypes';
import styles from './WebView.styles';


// eslint-disable-next-line prefer-destructuring
const RNCEngineAdBlock = NativeModules.RNCEngineAdBlock;

const defaultOriginWhitelist = ['http://*', 'https://*'];

const extractOrigin = (url: string): string => {
  const result = /^[A-Za-z][A-Za-z0-9+\-.]+:(\/\/)?[^/]*/.exec(url);
  return result === null ? '' : result[0];
};

const originWhitelistToRegex = (originWhitelist: string): string =>
  `^${escapeStringRegexp(originWhitelist).replace(/\\\*/g, '.*')}`;

const passesWhitelist = (
  compiledWhitelist: readonly string[],
  url: string,
) => {
  const origin = extractOrigin(url);
  return compiledWhitelist.some(x => new RegExp(x).test(origin));
};

const compileWhitelist = (
  originWhitelist: readonly string[],
): readonly string[] =>
  ['about:blank', ...(originWhitelist || [])].map(originWhitelistToRegex);

const createOnShouldStartLoadWithRequest = (
  loadRequest: (
    shouldStart: boolean,
    url: string,
    lockIdentifier: number,
  ) => void,
  originWhitelist: readonly string[],
  onShouldStartLoadWithRequest?: OnShouldStartLoadWithRequest,
) => {
  return ({ nativeEvent }: WebViewNavigationEvent) => {
    let shouldStart = true;
    const { url, lockIdentifier } = nativeEvent;

    if (!passesWhitelist(compileWhitelist(originWhitelist), url)) {
      Linking.openURL(url);
      shouldStart = false;
    }

    if (onShouldStartLoadWithRequest) {
      shouldStart = onShouldStartLoadWithRequest(nativeEvent);
    }

    loadRequest(shouldStart, url, lockIdentifier);
  };
};

const createOnShouldCreateNewWindow = (
  createNewWindow: (
    shouldCreate: boolean,
    url: string,
    lockIdentifier: number,
  ) => void,
  onShouldCreateNewWindow?: OnShouldCreateNewWindow,
) => {
  return ({ nativeEvent }: WebViewNavigationEvent) => {
    let shouldStart = true;
    const { url, lockIdentifier } = nativeEvent;

    if (onShouldCreateNewWindow) {
      shouldStart = onShouldCreateNewWindow(nativeEvent);
    }

    createNewWindow(shouldStart, url, lockIdentifier);
  };
};

const defaultRenderLoading = () => (
  <View style={styles.loadingOrErrorView}>
    <ActivityIndicator />
  </View>
);
const defaultRenderError = (
  errorDomain: string | undefined,
  errorCode: number,
  errorDesc: string,
) => (
  <View style={styles.loadingOrErrorView}>
    <Text style={styles.errorTextTitle}>Error loading page</Text>
    <Text style={styles.errorText}>{`Domain: ${errorDomain}`}</Text>
    <Text style={styles.errorText}>{`Error Code: ${errorCode}`}</Text>
    <Text style={styles.errorText}>{`Description: ${errorDesc}`}</Text>
  </View>
);

// #region Lunascape
const initialEngineAdBlock = () => {
  try {
    RNCEngineAdBlock.initialEngine();
  } catch (error) {
    console.log('error', error);
  }
};

// #endregion Lunascape

export {
  defaultOriginWhitelist,
  createOnShouldStartLoadWithRequest,
  createOnShouldCreateNewWindow,
  defaultRenderLoading,
  defaultRenderError,
  initialEngineAdBlock,
};
