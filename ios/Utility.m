#import "Utility.h"

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
            NSLog(@"Failed to create folder, error: %@", createError.localizedDescription);
            return nil;
        }
        
        downloadsPath = [[NSURL alloc] initFileURLWithPath: folderDir];
        
        if (excludeFromBackups) {
            NSError *excludeError;
            [downloadsPath setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&excludeError];

            if (excludeError) {
                NSLog(@"Failed to set exclude from backups, error: %@", excludeError.localizedDescription);
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
    NSString *downloadFolder = [_downloadConfig[@"downloadFolder"] stringValue] ?: @"downloads";
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
@end
