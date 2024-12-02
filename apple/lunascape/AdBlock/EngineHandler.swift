//
//  Engine.swift
//  react-native-webview
//

import Foundation
import WebKit

@available(iOS 14.0, *)
@objc(EngineHandler)
public class EngineHandler: NSObject {
    
    fileprivate var helpers = [String: TabContentScript]()
    
    private var requestBlockingContentHelper: RequestBlockingContentScriptHandler?
    
    private var customUserScripts = Set<UserScriptType>()

    private var userScripts = Set<UserScriptManager.ScriptType>()
    
    private var currentPageData: PageData?
    
    
    // init resources
    @objc static public func loadEasylistAndBlocklist() async {
        NSLog("=====> loadEasylistAndBlocklist -- start")
        let bundlePath = Bundle.main.path(forResource: "Settings", ofType: "bundle")
        if(bundlePath == nil) {
            return
        }
        let resourceBundle = Bundle(path: bundlePath!)
        let listInfo = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.adBlock, localFileURL: (resourceBundle?.url(forResource: "AdblockResources/Easylist/list", withExtension: "txt")!)!)
        let resourceInfo = CachedAdBlockEngine.ResourcesInfo(localFileURL: (resourceBundle?.url(forResource: "AdblockResources/resources", withExtension: "json")!)!)
        
        let listInfo7326 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "bfpgedeaaibpoidldhjcknekahbikncb"), localFileURL: (resourceBundle?.url(forResource: "AdblockResources/Easylist/list7545", withExtension: "txt")!)!)
        
        let listInfo7844 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "cdbbhgbmjhfnhnmgeddbliobbofkgdhe"), localFileURL: (resourceBundle?.url(forResource: "AdblockResources/Easylist/list8055", withExtension: "txt")!)!)
        
        let listInfo1416 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "llgjaaddopeckcifdceaaadmemagkepi"), localFileURL: (resourceBundle?.url(forResource: "AdblockResources/Easylist/list1458", withExtension: "txt")!)!)
        
        //// TODO: support later if we can fully implement ContentBlockerManager.swift
        // let allowedModes: Set<ContentBlockerManager.BlockingMode> = [
        //     .aggressive,
        //     .standard,
        //     .general
        // ]
        
        Task {
            //// TODO: support later if we can fully implement ContentBlockerManager.swift
            // await self.loadBundledDataIfNeeded(allowedModes: allowedModes)
            
            await AdBlockStats.shared.compile(lazyInfo: listInfo, resourcesInfo: resourceInfo)
            await AdBlockStats.shared.compile(lazyInfo: listInfo7326, resourcesInfo: resourceInfo)
            await AdBlockStats.shared.compile(lazyInfo: listInfo7844, resourcesInfo: resourceInfo)
            await AdBlockStats.shared.compile(lazyInfo: listInfo1416, resourcesInfo: resourceInfo)
            NSLog("=====> loadEasylistAndBlocklist -- end")
        }
    }
    
    //// TODO: support later if we can fully implement ContentBlockerManager.swift
    // private static func loadBundledDataIfNeeded(allowedModes: Set<ContentBlockerManager.BlockingMode>) async {
    //   // Compile bundled blocklists but only if we don't have anything already loaded.
    //   await ContentBlockerManager.GenericBlocklistType.allCases.asyncConcurrentForEach { genericType in
    //     let blocklistType = ContentBlockerManager.BlocklistType.generic(genericType)
    //     let modes = await blocklistType.allowedModes.asyncFilter { mode in
    //       guard allowedModes.contains(mode) else { return false }
    //       // Non .blockAds can be recompiled safely because they are never replaced by downloaded files
    //       if genericType != .blockAds { return true }
          
    //       // .blockAds is special because it can be replaced by a downloaded file.
    //       // Hence we need to first check if it already exists.
    //       if await ContentBlockerManager.shared.hasRuleList(for: blocklistType, mode: mode) {
    //           print("hasRuleList->blocklistType->\(blocklistType)")
    //         return false
    //       } else {
    //         return true
    //       }
    //     }
        
    //     do {
    //       try await ContentBlockerManager.shared.compileBundledRuleList(for: genericType, modes: modes)
    //     } catch {
    //       assertionFailure("A bundled file should not fail to compile")
    //     }
    //   }
    // }
    
    private func setScripts(webview: WKWebView, scripts: [UserScriptManager.ScriptType: Bool]) {
      var scriptsToAdd = Set<UserScriptManager.ScriptType>()
      var scriptsToRemove = Set<UserScriptManager.ScriptType>()
      
      // TODO: check Script. Only add script one time
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
    
    func addContentScript(_ helper: TabContentScript, name: String, forweb webview: WKWebView, contentWorld: WKContentWorld, scriptMessageHandlerWithReply: WKScriptMessageHandlerWithReply) {
        if let _ = helpers[name] {
          assertionFailure("Duplicate helper added: \(name)")
        }

        helpers[name] = helper
        // If this helper handles script messages, then get the handler name and register it. The Tab
      // receives all messages and then dispatches them to the right TabHelper.
      let scriptMessageHandlerName = type(of: helper).messageHandlerName
        webview.configuration.userContentController.addScriptMessageHandler(scriptMessageHandlerWithReply, contentWorld: contentWorld, name: scriptMessageHandlerName)
    }
    
    @MainActor
    @objc
    public func handleAdblockScript(webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, enableRequestBlocking: Bool) -> Bool {
        guard var requestURL = navigationAction.request.url else {
            return false; // check later
        }
        NSLog("<<<<< react-native-webview -- handleAdblockScript -- isMainFrame = %@", (navigationAction.targetFrame?.isMainFrame ?? false) ? "YES": "NO" );
        if let mainDocumentURL = navigationAction.request.mainDocumentURL {
            if mainDocumentURL != self.currentPageData?.mainFrameURL {
                // Clear the current page data if the page changes.
                // Do this before anything else so that we have a clean slate.
                self.currentPageData = PageData(mainFrameURL: mainDocumentURL)
            }
            
            if navigationAction.targetFrame?.isMainFrame == true {
              self.setScripts( webview: webView, scripts: [
                // Add request blocking script
                // This script will block certian `xhr` and `window.fetch()` requests
                .requestBlocking: enableRequestBlocking
                
              ])
            }
            
            //// TODO: support this code later if we can move all WKUserScript objects (RNCWebViewImpl.m ) that you added to WKWebView into UserScriptManager.swift
            //// 
            // Check if custom user scripts must be added to or removed from the web view.
            // if let targetFrame = navigationAction.targetFrame {
            //   self.currentPageData?.addSubframeURL(forRequestURL: requestURL, isForMainFrame: targetFrame.isMainFrame)
            //   let scriptTypes = await self.currentPageData?.makeUserScriptTypes() ?? []
            //   self.setCustomUserScript( webview: webView, scripts: scriptTypes)
            // }
            
        }
        
      //// TODO: support later if we can fully implement ContentBlockerManager.swift
      //  if let mainDocumentURL = navigationAction.request.mainDocumentURL,
      //    mainDocumentURL.schemelessAbsoluteString == requestURL.schemelessAbsoluteString,
      //    navigationAction.sourceFrame.isMainFrame || navigationAction.targetFrame?.isMainFrame == true {
      //    // Identify specific block lists that need to be applied to the requesting domain

      //    // Load rule lists
      //    let ruleLists = await ContentBlockerManager.shared.ruleLists()
      //    self.set(ruleLists: ruleLists)
      //  }
        
        return true
    }
    
    @MainActor
    @objc
    public func isExistedRequestBlockingScript(webView: WKWebView?) -> Bool {
        var result: Bool = false
        if(webView != nil && RequestBlockingContentScriptHandler.userScript != nil) {
            result = webView!.configuration.userContentController.userScripts.contains(RequestBlockingContentScriptHandler.userScript!)
        }
        return result
    }
    
    @objc
    public func setupContentScript(webView: WKWebView, scriptMessageHandlerWithReply: WKScriptMessageHandlerWithReply) {
        if(self.requestBlockingContentHelper == nil) {
            self.requestBlockingContentHelper = RequestBlockingContentScriptHandler(webView: webView)
            self.addContentScript(self.requestBlockingContentHelper!, name: RequestBlockingContentScriptHandler.scriptName, forweb: webView, contentWorld: RequestBlockingContentScriptHandler.scriptSandbox, scriptMessageHandlerWithReply: scriptMessageHandlerWithReply)
        } else {
            NSLog("The requestBlockingContentHelper object already inited !!!");
        }
    }
    
    
    // call in WKScriptMessageHandlerWithReply -> userContentController
    @objc
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        for helper in helpers.values {
          let scriptMessageHandlerName = type(of: helper).messageHandlerName
          if scriptMessageHandlerName == message.name {
            helper.userContentController(userContentController, didReceiveScriptMessage: message, replyHandler: replyHandler)
            return
          }
        }
    }
    
}
