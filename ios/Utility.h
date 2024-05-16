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
+ (NSArray *)getDownloadSessionInfo;
+ (void)setDownloadSessionInfo: (NSArray *)sessionInfos;
+ (void) updateDownloadingList;
+ (void)removeSessionInfo: (NSNumber *)sessionId;
+ (void) setDownloadingInfos: (NSArray *)downloadInfos;
+ (NSNumber *)getNextIndexSessionInfo: (NSURLRequest *)url fileName: (NSString *)fileName mimeType: (NSString *)mimeType expectedFileSize: (NSNumber *)length;
+ (void) updateSessionInfo: (NSString *)sessionId downloadedSize: (NSNumber *)size status: (NSNumber *) status;
+ (NSString *)getSessionId: (NSURLSession *)session;

+ (NSNumber *)getLastSessionIndex;
+ (void)setLastSessionIndex: (NSNumber *)value;

// AppInfo
+ (NSBundle *)applicationBundle;
+ (NSString *)bundleIdentifier;
+ (NSString *)appVersion;
+ (NSString *)buildNumber;
+ (NSString *)displayName;
@end
