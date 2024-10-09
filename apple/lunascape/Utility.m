#import "Utility.h"
#import "DownloadModule.h"

@implementation Utility

static NSDictionary *_downloadConfig = nil;

+ (void)initialize {
    if (self == [Utility class]) {
        _downloadConfig = [NSDictionary dictionary];
    }
}

+ (NSDictionary *) downloadConfig {
    return _downloadConfig;
}

+ (void)setDownloadConfig:(NSDictionary *)newValue {
    _downloadConfig = newValue;
}

+ (NSString *)getBase64Data:(NSString *)base64Data {
    NSArray *parts = [base64Data componentsSeparatedByString:@","];
    if ([parts count] > 1) {
        return parts[1];
    }
    return base64Data;
}

+ (NSString *)getMimeTypeFromBase64Data:(NSString *)base64Data {
    NSArray *parts = [base64Data componentsSeparatedByString:@";"];
    if (parts.count > 0) {
        NSArray *typePart = [parts[0] componentsSeparatedByString:@":"];
        if (typePart.count > 1) {
            return typePart[1];
        }
    }
    return nil;
}

+ (NSString *)getFileExtensionFromBase64Data:(NSString *)base64Data {
    NSArray *parts = [base64Data componentsSeparatedByString:@";"];
    if (parts.count > 0) {
        NSArray *extensionPart = [parts[0] componentsSeparatedByString:@"/"];
        if (extensionPart.count > 1) {
            return extensionPart[1];
        }
    }
    return nil;
}

+ (NSURL *)getOrCreateFolderWithName:(NSString *)name excludeFromBackups:(BOOL)excludeFromBackups location:(NSSearchPathDirectory)location {
    NSURL *downloadsPath;
    
    NSArray *urls = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,  NSUserDomainMask, YES);;
    NSString *firstURLStr = [urls firstObject];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    

    if (!firstURLStr) {
        return nil;
    }

    NSString *folderDir = [firstURLStr stringByAppendingPathComponent:name];

    if ([fileManager fileExistsAtPath:folderDir]) {
        downloadsPath = [[NSURL alloc] initFileURLWithPath: folderDir];
    } else {
        NSError *createError;
        [fileManager createDirectoryAtPath:folderDir withIntermediateDirectories:YES attributes:nil error:&createError];

        if (createError) {
            // NSLog(@"Failed to create folder, error: %@", createError.localizedDescription);
            return nil;
        }
        
        downloadsPath = [[NSURL alloc] initFileURLWithPath: folderDir];
        
        if (excludeFromBackups) {
            NSError *excludeError;
            [downloadsPath setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&excludeError];

            if (excludeError) {
                // NSLog(@"Failed to set exclude from backups, error: %@", excludeError.localizedDescription);
            }
        }
    }
    return downloadsPath;
}

+ (NSURL *)uniqueDownloadPathForFilename:(NSString *)filename {
    NSURL *downloadsPath = [Utility getDownloadFolder];
    
    if (!downloadsPath) {
        return nil;
    }

    NSURL *basePath = [downloadsPath URLByAppendingPathComponent:filename];
    NSString *fileExtension = basePath.pathExtension;
    NSString *filenameWithoutExtension = (fileExtension.length > 0) ? [filename substringToIndex:(filename.length - (fileExtension.length + 1))] : filename;

    NSURL *proposedPath = basePath;
    NSInteger count = 0;

    while ([[NSFileManager defaultManager] fileExistsAtPath:proposedPath.path]) {
        count++;

        NSString *proposedFilenameWithoutExtension = [NSString stringWithFormat:@"%@ (%ld)", filenameWithoutExtension, (long)count];
        proposedPath = [[downloadsPath URLByAppendingPathComponent:proposedFilenameWithoutExtension] URLByAppendingPathExtension:fileExtension];
    }

    return proposedPath;
}

+ (NSURL *)getDownloadFolder {
    NSString *downloadFolder = [_downloadConfig[kDownloadFolderKey] stringValue] ?: kDownloadKey;
    return [Utility getOrCreateFolderWithName:downloadFolder excludeFromBackups:YES location:NSDocumentDirectory];
}

+ (void)openDownloadFolder {
    NSURL *downloadsPath = [Utility getDownloadFolder];
    if (!downloadsPath) {
        return;
    }
    
    NSURLComponents *downloadsPathComponents = [NSURLComponents componentsWithURL:downloadsPath resolvingAgainstBaseURL:NO];
    if (!downloadsPathComponents) {
        return;
    }
    
    downloadsPathComponents.scheme = @"shareddocuments";
    NSURL *downloadFolderURL = [downloadsPathComponents URL];
    if (!downloadFolderURL) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:downloadFolderURL options:@{} completionHandler:nil];
    });
}

+ (NSNumber *)getLastSessionIndex {
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSNumber *index = [userDefault objectForKey:kLastSessionIndexKey];
    return index ?: @(0);
}

+ (void)setLastSessionIndex: (NSNumber *)value {
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    [userDefault setObject:value forKey:kLastSessionIndexKey];
    [userDefault synchronize];
}

+ (NSArray *)getDownloadSessionInfo {
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSArray *sessionInfos = [userDefault arrayForKey:kDownloadSessionInfoKey];
    return sessionInfos;
}

+ (void)setDownloadSessionInfo: (NSArray *)sessionInfos {
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    [userDefault setObject:sessionInfos forKey:kDownloadSessionInfoKey];
    [userDefault synchronize];
}

+ (void) initDownloadingList {
    NSArray *sessionInfos = [Utility getDownloadSessionInfo];
    NSMutableArray *newSessionInfos = [NSMutableArray array];
    for (NSDictionary *sessionInfo in sessionInfos) {
        if ([sessionInfo[kStatusKey] isEqual: DownloadStatusDownloading]) {
            NSMutableDictionary *new = [NSMutableDictionary dictionaryWithDictionary:sessionInfo];
            new[kStatusKey] = DownloadStatusPause;
            [newSessionInfos addObject:new];
        } else {
            [newSessionInfos addObject:sessionInfo];
        }
    }
    [DownloadQueue setDownloadingList: newSessionInfos];
    dispatch_async([DownloadQueue downloadSerialQueue], ^{
        [Utility setDownloadSessionInfo:newSessionInfos];
    });
}

+ (void)removeSessionInfo: (NSNumber *)sessionId {
    dispatch_async([DownloadQueue downloadSerialQueue], ^{
        NSMutableArray *sessionInfos =  [NSMutableArray arrayWithArray: [DownloadQueue downloadingList]];
        for (NSMutableDictionary *sessionInfo in sessionInfos) {
            if ([sessionInfo[kSessionIdKey] isEqual:sessionId]) {
                [sessionInfos removeObject:sessionInfo];
                [[DownloadModule sharedInstance] downloadingFileItemDidSuccess];
                break;
            }
        }
        [Utility setDownloadingInfos:sessionInfos];
    });
}

+ (void)setDownloadingInfos: (NSArray *)downloadInfos {
    [DownloadQueue setDownloadingList:downloadInfos];
    [[DownloadModule sharedInstance] downloadingFileDidUpdate];
    dispatch_async([DownloadQueue downloadSerialQueue], ^{
        [Utility setDownloadSessionInfo:downloadInfos];
    });
}

+ (NSNumber *)getNextIndexSessionInfo: (NSURLRequest *)url fileName: (NSString *)fileName mimeType: (NSString *)mimeType expectedFileSize: (NSNumber *)length {
    NSNumber *newNumber = [Utility getLastSessionIndex];
    NSString *newSessionId = [NSString stringWithFormat:@"%@%d", kSessionIdKey, newNumber.intValue + 1];
    NSDictionary *new = @{kSessionIdKey: @(newNumber.intValue + 1), kStatusKey: DownloadStatusDownloading, kUrlKey: url.URL.absoluteString, kFileNameKey: fileName ?: kUnknownKey, kMimeTypeKey: mimeType ?: @"", kTotalBytesKey: length ?: @0, kBytesDownloadedKey: @0};
    [DownloadQueue setTempSessionInfo:new];
    return @(newNumber.intValue + 1);
}

+ (void) updateSessionInfo: (NSString *)sessionId downloadedSize: (NSNumber *)size status: (NSString *) status {
    dispatch_async([DownloadQueue downloadSerialQueue], ^{
        NSArray *sessionInfos = [DownloadQueue downloadingList];
        NSMutableArray *newSessionInfos = [NSMutableArray arrayWithArray:sessionInfos];
        for (int i = 0; i < newSessionInfos.count; i++) {
            NSDictionary *sessionInfo = newSessionInfos[i];
            NSString *sessionIdStr = [sessionInfo[kSessionIdKey] stringValue];
            if ([sessionIdStr isEqual:sessionId]) {
                NSMutableDictionary *new = [NSMutableDictionary dictionaryWithDictionary:sessionInfo];
                if (size) {
                    new[kBytesDownloadedKey] = size;
                }
                
                if (status != DownloadStatusNone) {
                    new[kStatusKey] = status;
                    [[DownloadModule sharedInstance]  downloadingFileStatusDidUpdate:@([sessionId intValue]) status:status];
                }
                [newSessionInfos replaceObjectAtIndex:i withObject:new];
                break;
            }
        }
        [Utility setDownloadingInfos:newSessionInfos];
    });
}

+ (NSString *)getSessionId: (NSURLSession *)session {
    NSString *sessionId = session.configuration.identifier;
    NSString *indexStr = [sessionId substringFromIndex: [kSessionIdKey length]];
    return indexStr;
}

+ (NSBundle *)applicationBundle {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *pathExtension = bundle.bundleURL.pathExtension;
    if ([pathExtension isEqualToString:@"app"]) {
        return bundle;
    } else if ([pathExtension isEqualToString:@"appex"]) {
        return [NSBundle bundleWithURL:[[bundle.bundleURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent]];
    } else {
        // NSLog(@"Unable to get application Bundle (Bundle.main.bundlePath=%@)", bundle.bundlePath);
        return nil;
    }
}

+ (NSString *)bundleIdentifier {
    return [[self applicationBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
}

+ (NSString *)appVersion {
    return [[self applicationBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (NSString *)buildNumber {
    return [[self applicationBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
}

+ (NSString *)displayName {
    return [[self applicationBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
}
@end
