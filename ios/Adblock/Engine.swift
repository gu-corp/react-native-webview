//
//  Engine.swift
//  react-native-webview
//
//  Created by Alobridge on 23/7/24.
//

import Foundation
import WebKit

@available(iOS 14.0, *)
@objcMembers public class Engine {
    // TODO: change class Name to AdblockHandler
    
    private var customUserScripts = Set<UserScriptType>()

    private var userScripts = Set<UserScriptManager.ScriptType>()
    
    private var currentPageData: PageData?
    
    
//    //(void (^)(id _Nullable reply, NSString * _Nullable errorMessage))
//    @objc func checkBlocking ( requestURL: URL, sourceURL:URL, resourceType:String, replyHandler: @escaping(Any?, String?) -> Void){
//        Task { @MainActor in
//            let shouldBlock = await AdBlockStats.shared.shouldBlock(
//                requestURL: requestURL, sourceURL: sourceURL, resourceType: AdblockRustEngine.ResourceType(rawValue: resourceType)!
//            )
//            replyHandler(shouldBlock, nil)
//        }
//
//    }
//
//    private var setRuleLists: Set<WKContentRuleList> = []
//
//    @objc func configRules (userContentController: WKUserContentController ) async throws -> Set<WKContentRuleList>{
//            let ruleLists = await ContentBlockerManager.shared.ruleLists()
//    //         if(ruleLists != setRuleLists){
//    //             var addedIds: [String] = []
//    //             var removedIds: [String] = []
//
//    //             // Remove unwanted rule lists
//    //             for ruleList in setRuleLists.subtracting(ruleLists) {
//    //               // It's added but we don't want it. So we remove it.
//    // //              self.webview?.configuration.userContentController.remove(ruleList)
//    //                 setRuleLists.remove(ruleList)
//    //                 removedIds.append(ruleList.identifier)
//    //             }
//
//    //             // Add missing rule lists
//    //             for ruleList in ruleLists.subtracting(setRuleLists) {
//    // //              self.webview?.configuration.userContentController.add(ruleList)
//    //                 setRuleLists.insert(ruleList)
//    //                 addedIds.append(ruleList.identifier)
//    //             }
//    //         }
//        return ruleLists
//    }
//
//    @MainActor
//    @objc func getScripts(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> String {
//            guard var requestURL = navigationAction.request.url else {
//              return "Failed"
//            }
//
//            if let mainDocumentURL = navigationAction.request.mainDocumentURL {
//                if mainDocumentURL != self.currentPageData?.mainFrameURL {
//                    // Clear the current page data if the page changes.
//                    // Do this before anything else so that we have a clean slate.
//                    self.currentPageData = PageData(mainFrameURL: mainDocumentURL)
//                }
//
////                if navigationAction.targetFrame?.isMainFrame == true {
////                  self.setScripts(scripts: [
////                    .requestBlocking: true])
////                }
//
//                // Check if custom user scripts must be added to or removed from the web view.
//                if let targetFrame = navigationAction.targetFrame {
//                    self.currentPageData?.addSubframeURL(forRequestURL: requestURL, isForMainFrame: targetFrame.isMainFrame)
//                    let scriptTypes = await self.currentPageData?.makeUserScriptTypes() ?? []
//                    // if customUserScripts != scriptTypes {
//                        customUserScripts = scriptTypes
//                        UserScriptManager.shared.loadCustomScripts(into: webView,
//                                                                 userScripts: userScripts,
//                                                                 customScripts: customUserScripts)
//                    // }
//                }
//
//            }
//        return "Done"
//        }
//    @objc func clearCustomUserScripts () {
//        customUserScripts.removeAll()
//    }
    
    // new version
    
    // init resources
    @objc static func loadEasylistAndBlocklist() {
        let listInfo = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.adBlock, localFileURL: Bundle.main.url(forResource: "list", withExtension: "txt")!)
        let resourceInfo = CachedAdBlockEngine.ResourcesInfo(localFileURL: Bundle.main.url(forResource: "resources", withExtension: "json")!)
        
        let listInfo7326 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "bfpgedeaaibpoidldhjcknekahbikncb"), localFileURL: Bundle.main.url(forResource: "list7545", withExtension: "txt")!)
        
        let listInfo7844 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "cdbbhgbmjhfnhnmgeddbliobbofkgdhe"), localFileURL: Bundle.main.url(forResource: "list8055", withExtension: "txt")!)
        
        let listInfo1416 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "llgjaaddopeckcifdceaaadmemagkepi"), localFileURL: Bundle.main.url(forResource: "list1458", withExtension: "txt")!)
        
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
            print("nap xong engine")
        }
    }
    
    private static func loadBundledDataIfNeeded(allowedModes: Set<ContentBlockerManager.BlockingMode>) async {
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
    
    private func setScripts(webview: WKWebView, scripts: [UserScriptManager.ScriptType: Bool]) {
      var scriptsToAdd = Set<UserScriptManager.ScriptType>()
      var scriptsToRemove = Set<UserScriptManager.ScriptType>()
      
      for (script, enabled) in scripts {
        let scriptExists = userScripts.contains(script)
        
        if !scriptExists && enabled {
          scriptsToAdd.insert(script)
        } else if scriptExists && !enabled {
          scriptsToRemove.insert(script)
        }
      }
      
      if scriptsToAdd.isEmpty && scriptsToRemove.isEmpty {
        // Scripts already enabled or disabled
        return
      }
      
      userScripts.formUnion(scriptsToAdd)
      userScripts.subtract(scriptsToRemove)
      updateInjectedScripts(webview: webview)
    }
    
    private func updateInjectedScripts(webview: WKWebView) {
        UserScriptManager.shared.loadCustomScripts(into: webview,
                                                 userScripts: userScripts,
                                                 customScripts: customUserScripts)
    }
    
    func setCustomUserScript(webview: WKWebView, scripts: Set<UserScriptType>) {
      if customUserScripts != scripts {
        customUserScripts = scripts
        print("scripts->\(scripts)")
        updateInjectedScripts(webview: webview)
      }
    }
    
    
    @MainActor func handleAdblockScript(webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> Bool {
        guard var requestURL = navigationAction.request.url else {
            return false;
        }
        
        if let mainDocumentURL = navigationAction.request.mainDocumentURL {
            if mainDocumentURL != self.currentPageData?.mainFrameURL {
                // Clear the current page data if the page changes.
                // Do this before anything else so that we have a clean slate.
                self.setPageData(mainFrameUrl: mainDocumentURL)
            }
            
            if navigationAction.targetFrame?.isMainFrame == true {
              self.setScripts( webview: webView, scripts: [
                // Add de-amp script
                // The user script manager will take care to not reload scripts if this value doesn't change
      //          .deAmp: Preferences.Shields.autoRedirectAMPPages.value,
                
                // Add request blocking script
                // This script will block certian `xhr` and `window.fetch()` requests
                .requestBlocking: true
                
                // The tracker protection script
                // This script will track what is blocked and increase stats
      //          .trackerProtectionStats: requestURL.isWebPage(includeDataURIs: false) &&
      //                                   domainForMainFrame.isShieldExpected(.AdblockAndTp, considerAllShieldsOption: true)
              ])
            }
            
            // Check if custom user scripts must be added to or removed from the web view.
            if let targetFrame = navigationAction.targetFrame {
              self.currentPageData?.addSubframeURL(forRequestURL: requestURL, isForMainFrame: targetFrame.isMainFrame)
              let scriptTypes = await self.currentPageData?.makeUserScriptTypes() ?? []
              self.setCustomUserScript( webview: webView, scripts: scriptTypes)
            }
            
        }
        
//        if let mainDocumentURL = navigationAction.request.mainDocumentURL,
//          mainDocumentURL.schemelessAbsoluteString == requestURL.schemelessAbsoluteString,
//          navigationAction.sourceFrame.isMainFrame || navigationAction.targetFrame?.isMainFrame == true {
//          // Identify specific block lists that need to be applied to the requesting domain
//
//          // Load rule lists
//          let ruleLists = await ContentBlockerManager.shared.ruleLists()
//          self.set(ruleLists: ruleLists)
//        }
        
        return true
    }
    
    func setPageData(mainFrameUrl: URL) {
        self.currentPageData = PageData(mainFrameURL: mainFrameUrl)
    }
    
    func getPageData () -> PageData? {
        return self.currentPageData
    }
}
