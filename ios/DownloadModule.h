#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "DownloadQueue.h"
#import "PassBookHelper.h"
@interface DownloadModule : RCTEventEmitter <RCTBridgeModule, DownloadQueueDelegate, PassBookHelperDelegate>

+ (instancetype)sharedInstance;
- (void) downloadingFileDidUpdate;
- (void)downloadingFileItemDidSuccess;
@end
