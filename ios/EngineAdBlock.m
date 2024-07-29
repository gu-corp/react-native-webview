//
//  EngineAdBlock.m
//  react-native-webview
//
//  Created by Alobridge on 29/7/24.
//
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(EngineAd, RCTEventEmitter)

RCT_EXTERN_METHOD(startMonitoring)
RCT_EXTERN_METHOD(stopMonitoring)
@end
