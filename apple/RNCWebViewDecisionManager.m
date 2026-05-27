#import "RNCWebViewDecisionManager.h"



@implementation RNCWebViewDecisionManager

@synthesize nextLockIdentifier;
@synthesize decisionHandlers;

+ (id)getInstance {
    static RNCWebViewDecisionManager *lockManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lockManager = [[self alloc] init];
    });
    return lockManager;
}

- (int)setDecisionHandler:(DecisionBlock)decisionHandler {
    // decisionHandlers and nextLockIdentifier are accessed from both the main
    // thread (WKNavigationDelegate) and the JS bridge queue (setResult:...).
    // NSMutableDictionary is not thread-safe; serialize access to avoid crashes.
    @synchronized (self) {
        int lockIdentifier = self.nextLockIdentifier++;
        [self.decisionHandlers setObject:decisionHandler forKey:@(lockIdentifier)];
        return lockIdentifier;
    }
}

- (void) setResult:(BOOL)shouldStart
 forLockIdentifier:(int)lockIdentifier {
    DecisionBlock handler = nil;
    @synchronized (self) {
        handler = [self.decisionHandlers objectForKey:@(lockIdentifier)];
        if (handler != nil) {
            [self.decisionHandlers removeObjectForKey:@(lockIdentifier)];
        }
    }
    if (handler == nil) {
        RCTLogWarn(@"Lock not found");
        return;
    }
    handler(shouldStart);
}

- (id)init {
  if (self = [super init]) {
      self.nextLockIdentifier = 1;
      self.decisionHandlers = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {}

@end
