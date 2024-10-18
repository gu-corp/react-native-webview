//
//  RCTEngineAdBlock.m
//  react-native-webview
//
//  Created by Alobridge on 29/7/24.
//

#import "RCTEngineAdBlock.h"
#import "react_native_webview-Swift.h"
@implementation RCTEngineAdBlock

// To export a module named EngineAdBlock
RCT_EXPORT_MODULE(EngineAdBlock);

API_AVAILABLE(ios(11.0))
Engine *engine ;
RCT_EXPORT_METHOD(initialEngine ){
    if (@available(iOS 11.0, *)) {
        Engine *e = [[Engine alloc] init];
        engine = e;
    } else {
        // Fallback on earlier versions
    }
}

+ (id)getEngine{
    if (@available(iOS 11.0, *)) {
        return engine;
    } else {
        return nil;
    }
}


@end
