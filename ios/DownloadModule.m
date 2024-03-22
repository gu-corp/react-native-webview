#import "DownloadModule.h"
#import "Utility.h"

@implementation DownloadModule

RCT_EXPORT_MODULE(DownloadModule);

- (NSArray<NSString *> *)supportedEvents {
    return @[@"PassBookError"];
}

static DownloadModule *sharedInstance = nil;

+ (instancetype)sharedInstance {
    if (sharedInstance) {
        return sharedInstance;
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        sharedInstance = self;
    }
    return self;
}

- (void) passBookdidCompleteWithError {
    [self sendEventWithName:@"PassBookError" body:@{}];
}

@end
