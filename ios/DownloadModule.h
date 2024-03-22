#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "PassBookHelper.h"
@interface DownloadModule : RCTEventEmitter <RCTBridgeModule, PassBookHelperDelegate>

+ (instancetype)sharedInstance;
@end
