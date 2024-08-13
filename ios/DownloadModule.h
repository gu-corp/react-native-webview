#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "DownloadQueue.h"
#import "PassBookHelper.h"
#import "DownloadHelper.h"
@interface DownloadModule : RCTEventEmitter <RCTBridgeModule, PassBookHelperDelegate>

+ (instancetype)sharedInstance;
- (void) downloadingFileDidUpdate;
- (void)downloadingFileItemDidSuccess;
- (void)downloadingFileStatusDidUpdate:(NSNumber *)sessionId status:(NSString*)status;
@end
