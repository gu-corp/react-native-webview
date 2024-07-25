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
    @objc func initialEngine() -> String{
        if let bundlePath = Bundle.main.path(forResource: "Settings", ofType: "bundle") {
            let resourceBundle = Bundle(path: bundlePath)
            let linkList = resourceBundle?.url(forResource: "list", withExtension: "txt")
            
            let listInfo = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.adBlock, localFileURL: linkList!)
            
            let linkResources = resourceBundle?.url(forResource: "resources", withExtension: "json")
            let resourceInfo = CachedAdBlockEngine.ResourcesInfo(localFileURL: linkResources!)
            
            let linkListInfo7326 = resourceBundle?.url(forResource: "list7326", withExtension: "txt")
            let listInfo7326 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "bfpgedeaaibpoidldhjcknekahbikncb"), localFileURL: linkListInfo7326!)
            
            let linkListInfo7844 = resourceBundle?.url(forResource: "list7844", withExtension: "txt")
            let listInfo7844 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "cdbbhgbmjhfnhnmgeddbliobbofkgdhe"), localFileURL: linkListInfo7844!)
            
            let linkListInfo1416 = resourceBundle?.url(forResource: "list1416", withExtension: "txt")
            let listInfo1416 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "llgjaaddopeckcifdceaaadmemagkepi"), localFileURL: linkListInfo1416!)
            
            if #available(iOS 13.0.0, *) {
                let allowedModes: Set<ContentBlockerManager.BlockingMode> = [
                    .aggressive,
                    .standard,
                    .general
                ]
                
                Task {
                    await loadBundledDataIfNeeded(allowedModes: allowedModes)
                    
                    await AdBlockStats.shared.compile(lazyInfo: listInfo, resourcesInfo: resourceInfo)
                    await AdBlockStats.shared.compile(lazyInfo: listInfo7326, resourcesInfo: resourceInfo)
                    await AdBlockStats.shared.compile(lazyInfo: listInfo7844, resourcesInfo: resourceInfo)
                    await AdBlockStats.shared.compile(lazyInfo: listInfo1416, resourcesInfo: resourceInfo)
                }
            } else {
                // Fallback on earlier versions
            }
            
            return "Initial"
        }else{
            return "Initial failed"
        }
    }
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
        print("bách setRuleLists")
            let ruleLists = await ContentBlockerManager.shared.ruleLists()
            if(ruleLists != setRuleLists){
                var addedIds: [String] = []
                var removedIds: [String] = []
                
                // Remove unwanted rule lists
                for ruleList in setRuleLists.subtracting(ruleLists) {
                  // It's added but we don't want it. So we remove it.
    //              self.webview?.configuration.userContentController.remove(ruleList)
                    setRuleLists.remove(ruleList)
                    removedIds.append(ruleList.identifier)
                }
                
                // Add missing rule lists
                for ruleList in ruleLists.subtracting(setRuleLists) {
    //              self.webview?.configuration.userContentController.add(ruleList)
                    setRuleLists.insert(ruleList)
                    addedIds.append(ruleList.identifier)
                }
            }
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
