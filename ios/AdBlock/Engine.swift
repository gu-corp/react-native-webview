//
//  Engine.swift
//  react-native-webview
//
//  Created by Alobridge on 23/7/24.
//

import Foundation
import WebKit

@available(iOS 11.0, *)
@objcMembers public class Engine: NSObject {
    //(void (^)(id _Nullable reply, NSString * _Nullable errorMessage))
    @available(iOS 13.0.0, *)
    @objc func checkBlocking ( requestURL: URL, sourceURL:URL, resourceType:String, replyHandler: @escaping(Any?, String?) -> Void){
        Task { @MainActor in
            let shouldBlock = await AdBlockStats.shared.shouldBlock(
                requestURL: requestURL, sourceURL: sourceURL, resourceType: AdblockRustEngine.ResourceType(rawValue: resourceType)!
            )
            replyHandler(shouldBlock, nil)
        }
        
    }
    
    private var setRuleLists: Set<WKContentRuleList> = []
    @available(iOS 13.0.0, *)
    @objc func configRules (userContentController: WKUserContentController ) async throws -> Set<WKContentRuleList>{
            let ruleLists = await ContentBlockerManager.shared.ruleLists()
    //         if(ruleLists != setRuleLists){
    //             var addedIds: [String] = []
    //             var removedIds: [String] = []
                
    //             // Remove unwanted rule lists
    //             for ruleList in setRuleLists.subtracting(ruleLists) {
    //               // It's added but we don't want it. So we remove it.
    // //              self.webview?.configuration.userContentController.remove(ruleList)
    //                 setRuleLists.remove(ruleList)
    //                 removedIds.append(ruleList.identifier)
    //             }
                
    //             // Add missing rule lists
    //             for ruleList in ruleLists.subtracting(setRuleLists) {
    // //              self.webview?.configuration.userContentController.add(ruleList)
    //                 setRuleLists.insert(ruleList)
    //                 addedIds.append(ruleList.identifier)
    //             }
    //         }
        return ruleLists
    }
    
    @available(iOS 13.0.0, *)
    private func loadBundledDataIfNeeded(allowedModes: Set<ContentBlockerManager.BlockingMode>) async {
      // Compile bundled blocklists but only if we don't have anything already loaded.
      await ContentBlockerManager.GenericBlocklistType.allCases.asyncConcurrentForEach { genericType in
        let blocklistType = ContentBlockerManager.BlocklistType.generic(genericType)
        let modes = await blocklistType.allowedModes.asyncFilter { mode in
          guard allowedModes.contains(mode) else { return false }
          // Non .blockAds can be recompiled safely because they are never replaced by downloaded files
          if genericType != .blockAds { return true }
          
          // .blockAds is special because it can be replaced by a downloaded file.
          // Hence we need to first check if it already exists.
          if await ContentBlockerManager.shared.hasRuleList(for: blocklistType, mode: mode) {
              print("hasRuleList->blocklistType->\(blocklistType)")
            return false
          } else {
            return true
          }
        }
        
        do {
          try await ContentBlockerManager.shared.compileBundledRuleList(for: genericType, modes: modes)
        } catch {
          assertionFailure("A bundled file should not fail to compile")
        }
      }
    }
}
