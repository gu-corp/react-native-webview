//
//  RCTEngineAdBlock.h
//  Pods
//
//  Created by Alobridge on 29/7/24.
//

#ifndef RCTEngineAdBlock_h
#define RCTEngineAdBlock_h

#import <React/RCTBridgeModule.h>
@interface RCTEngineAdBlock : NSObject <RCTBridgeModule>
- (void) initialEngine;
+ (id)getEngine;
@end

#endif /* RCTEngineAdBlock_h */
