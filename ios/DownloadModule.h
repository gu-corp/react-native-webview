#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "DownloadQueue.h"
#import "PassBookHelper.h"
@interface DownloadModule : RCTEventEmitter <RCTBridgeModule, DownloadQueueDelegate, PassBookHelperDelegate>
@property (nonatomic, assign) int64_t combinedBytesDownloaded;
@property (nonatomic, strong) NSNumber *combinedTotalBytesExpected;

+ (instancetype)sharedInstance;
- (void) addDownload: (Download *) download;
@end
