#import <Foundation/Foundation.h>

@interface Utility : NSObject
+ (NSString *)getBase64Data:(NSString *)base64Data;
+ (NSString *)getMimeTypeFromBase64Data:(NSString *)base64Data;
+ (NSString *)getFileExtensionFromBase64Data:(NSString *)base64Data;

@property (class, nonatomic, strong) NSDictionary *downloadConfig;
+ (NSURL *)getOrCreateFolderWithName:(NSString *)name excludeFromBackups:(BOOL)excludeFromBackups location:(NSSearchPathDirectory)location;
+ (NSURL *)uniqueDownloadPathForFilename:(NSString *)filename;
+ (NSURL *)getDownloadFolder;
+ (void)openDownloadFolder;

// AppInfo
+ (NSBundle *)applicationBundle;
+ (NSString *)bundleIdentifier;
+ (NSString *)appVersion;
+ (NSString *)buildNumber;
+ (NSString *)displayName;
@end
