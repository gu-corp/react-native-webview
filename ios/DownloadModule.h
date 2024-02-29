#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "DownloadQueue.h"
@interface DownloadModule : RCTEventEmitter <RCTBridgeModule, DownloadQueueDelegate>
@property (nonatomic, assign) int64_t combinedBytesDownloaded;
@property (nonatomic, strong) NSNumber *combinedTotalBytesExpected;
@property (nonatomic, assign) CGFloat percent;

+ (instancetype)sharedInstance;
- (void) addDownload: (Download *) download;
@end
