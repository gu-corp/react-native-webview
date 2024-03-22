#import <Foundation/Foundation.h>

@interface Utility : NSObject
// AppInfo
+ (NSBundle *)applicationBundle;
+ (NSString *)bundleIdentifier;
+ (NSString *)appVersion;
+ (NSString *)buildNumber;
+ (NSString *)displayName;
@end
