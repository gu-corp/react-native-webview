/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#import "PassBookHelper.h"
#import "Utility.h"

@interface PassBookHelper ()

@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) WKHTTPCookieStore *cookieStore;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, weak) UIViewController *viewController;

@end

@implementation PassBookHelper
- (instancetype)initWithResponse:(NSURLResponse *)response
                     cookieStore:(WKHTTPCookieStore *)cookieStore
                  viewController:(UIViewController *)viewController
{
    self = [super init];
    if (self) {
        _response = response;
        _url = response.URL;
        _cookieStore = cookieStore;
        _session = [PassBookHelper makeURLSessionWithUserAgent: @"Lunascape-iOS-FxA"];
        _viewController = viewController;
    }
    return self;
}

+ (BOOL)canOpenPassBookWithResponse:(NSURLResponse *)response {
    if (!response.MIMEType || !response.URL) {
        return NO;
    }
    
    return [response.MIMEType isEqualToString:@"application/vnd.apple.pkpass"] && [PKAddPassesViewController canAddPasses];
}

- (void)open {
    @try {
        [self openPassWithContentsOfURL];
    }
    @catch (NSException *exception) {
        // NSLog(@"%@", exception.reason);
        [self sendLogErrorWithErrorDescription:exception.reason];
        [self openPassWithCookiesWithCompletion:^(NSError *error) {
            if (error) {
                [self presentErrorAlert];
            }
        }];
    }
}

- (void)openPassWithCookiesWithCompletion:(void (^)(NSError *))completion {
    [self configureCookiesWithCompletion:^{
        [self openPassFromDataTaskWithCompletion:completion];
    }];
}

- (void)openPassFromDataTaskWithCompletion:(void (^)(NSError *))completion {
    [self getDataWithCompletion:^(NSData *data) {
        if (!data) {
            if (completion) {
                completion([NSError errorWithDomain:@"YourErrorDomain" code:-1 userInfo:nil]);
            }
            return;
        }
        
        @try {
            [self openPassWithData:data];
        }
        @catch (NSException *exception) {
            // NSLog(@"%@", exception.reason);
            [self sendLogErrorWithErrorDescription:exception.reason];
            if (completion) {
                completion([NSError errorWithDomain:@"YourErrorDomain" code:-1 userInfo:nil]);
            }
        }
    }];
}

- (void)getDataWithCompletion:(void (^)(NSData *))completion {
    if (!self.url) {
        if (completion) {
            completion(nil);
        }
        return;
    }
    
    [[self.session dataTaskWithURL:self.url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([(NSHTTPURLResponse *)response statusCode] >= 200 && [(NSHTTPURLResponse *)response statusCode] < 300 && data) {
            if (completion) {
                completion(data);
            }
        } else {
            if (completion) {
                completion(nil);
            }
        }
    }] resume];
}

- (void)configureCookiesWithCompletion:(void (^)(void))completion {
    [self.cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        for (NSHTTPCookie *cookie in cookies) {
            [self.session.configuration.HTTPCookieStorage setCookie:cookie];
        }
        if (completion) {
            completion();
        }
    }];
}

- (void)openPassWithContentsOfURL {
    if (!self.url) {
        [NSException raise:@"InvalidPassError" format:@"Failed to open pass with content of URL"];
    }
    
    NSError *error;
    NSData *passData = [NSData dataWithContentsOfURL:self.url options:NSDataReadingUncached error:&error];
    if (!passData) {
        [NSException raise:@"InvalidPassError" format:@"Failed to open pass with content of URL"];
    }
    
    @try {
        [self openPassWithData:passData];
    }
    @catch (NSException *exception) {
        // NSLog(@"%@", exception.reason);
        [self sendLogErrorWithErrorDescription:exception.reason];
        [NSException raise:@"InvalidPassError" format:@"Failed to open pass with content of URL"];
    }
}

- (void)openPassWithData:(NSData *)passData {
    @try {
        PKPass *pass = [[PKPass alloc] initWithData:passData error:nil];
        PKPassLibrary *passLibrary = [[PKPassLibrary alloc] init];
        if ([passLibrary containsPass:pass]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] openURL:pass.passURL options:@{} completionHandler:nil];
            });
        } else {
            PKAddPassesViewController *addController = [[PKAddPassesViewController alloc] initWithPass:pass];
            if (!addController) {
                [NSException raise:@"InvalidPassError" format:@"Failed to prompt or open pass"];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [_viewController presentViewController:addController animated:YES completion:nil];
            });
        }
    }
    @catch (NSException *exception) {
        // NSLog(@"%@", exception.reason);
        [self sendLogErrorWithErrorDescription:exception.reason];
        [NSException raise:@"InvalidPassError" format:@"Failed to prompt or open pass"];
    }
}

- (void)presentErrorAlert {
    [self.delegate passBookdidCompleteWithError];
}

- (void)sendLogErrorWithErrorDescription:(NSString *)errorDescription {
    // Log error
    // NSLog(@"Unknown error when adding pass to Apple Wallet: %@", errorDescription);
}

+ (NSURLSession *)makeURLSessionWithUserAgent:(NSString *)userAgent {
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    [sessionConfiguration setHTTPAdditionalHeaders:@{@"User-Agent": [self clientUserAgentWithPrefix: userAgent]}];
    return [NSURLSession sessionWithConfiguration:sessionConfiguration];
}

+ (NSString *)clientUserAgentWithPrefix:(NSString *)prefix {
    NSString *versionStr;
    if (![Utility.buildNumber isEqualToString:@"1"]) {
        versionStr = [NSString stringWithFormat:@"%@b%@", Utility.appVersion, Utility.buildNumber];
    } else {
        versionStr = @"dev";
    }
    NSString *userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iPhone OS %@) (%@)", prefix, versionStr, [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion, Utility.displayName];
    return userAgent;
}
@end
