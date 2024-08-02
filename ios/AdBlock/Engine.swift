//
//  Engine.swift
//  react-native-webview
//
//  Created by Alobridge on 23/7/24.
//

import Foundation
import WebKit

@available(iOS 14.0, *)
@objcMembers public class Engine: NSObject {
    
    private var customUserScripts = Set<UserScriptType>()
    
    private var userScripts = Set<UserScriptManager.ScriptType>()
    
    var currentPageData: PageData?
    
    
    //(void (^)(id _Nullable reply, NSString * _Nullable errorMessage))
    @objc func checkBlocking ( requestURL: URL, sourceURL:URL, resourceType:String, replyHandler: @escaping(Any?, String?) -> Void){
        Task { @MainActor in
            let shouldBlock = await AdBlockStats.shared.shouldBlock(
                requestURL: requestURL, sourceURL: sourceURL, resourceType: AdblockRustEngine.ResourceType(rawValue: resourceType)!
            )
            replyHandler(shouldBlock, nil)
        }
        
    }
    
    private var setRuleLists: Set<WKContentRuleList> = []

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
    
    @MainActor
    @objc func getScripts(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> String {
            guard var requestURL = navigationAction.request.url else {
              return "NoAdd"
            }
            
            if let mainDocumentURL = navigationAction.request.mainDocumentURL {
                if mainDocumentURL != self.currentPageData?.mainFrameURL {
                    // Clear the current page data if the page changes.
                    // Do this before anything else so that we have a clean slate.
                    self.currentPageData = PageData(mainFrameURL: mainDocumentURL)
                }
                
//                if navigationAction.targetFrame?.isMainFrame == true {
//                  self.setScripts(scripts: [
//                    .requestBlocking: true])
//                }
                
                // Check if custom user scripts must be added to or removed from the web view.
                if let targetFrame = navigationAction.targetFrame {
                    self.currentPageData?.addSubframeURL(forRequestURL: requestURL, isForMainFrame: targetFrame.isMainFrame)
                    let scriptTypes = await self.currentPageData?.makeUserScriptTypes() ?? []
                    print("bách scriptTypes : \(scriptTypes)")
                    if customUserScripts != scriptTypes {
                        customUserScripts = scriptTypes
                        UserScriptManager.shared.loadCustomScripts(into: webView,
                                                                 userScripts: userScripts,
                                                                 customScripts: customUserScripts)
                    }
                }
                
            }
        return "Added"
        }
    
}
