//
//  Engine.swift
//  react-native-webview
//

import Foundation
import WebKit

@available(iOS 14.0, *)
@objc(EngineHandler)
public class EngineHandler: NSObject {

//    fileprivate var helpers = [String: TabContentScript]()
//
//    private var requestBlockingContentHelper: RequestBlockingContentScriptHandler?
//
//    private var currentPageData: PageData?
//
//
//    // init resources
//    @objc static public func loadEasylistAndBlocklist() async {
//        let bundlePath = Bundle.main.path(forResource: "Settings", ofType: "bundle")
//        if(bundlePath == nil) {
//            return
//        }
//        let resourceBundle = Bundle(path: bundlePath!)
//        let listInfo = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.adBlock, localFileURL: (resourceBundle?.url(forResource: "AdblockResources/Easylist/list", withExtension: "txt")!)!)
//        let resourceInfo = CachedAdBlockEngine.ResourcesInfo(localFileURL: (resourceBundle?.url(forResource: "AdblockResources/resources", withExtension: "json")!)!)
//
//        let listInfo7326 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "bfpgedeaaibpoidldhjcknekahbikncb"), localFileURL: (resourceBundle?.url(forResource: "AdblockResources/Easylist/list7545", withExtension: "txt")!)!)
//
//        let listInfo7844 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "cdbbhgbmjhfnhnmgeddbliobbofkgdhe"), localFileURL: (resourceBundle?.url(forResource: "AdblockResources/Easylist/list8055", withExtension: "txt")!)!)
//
//        let listInfo1416 = CachedAdBlockEngine.FilterListInfo(source: CachedAdBlockEngine.Source.filterList(componentId: "llgjaaddopeckcifdceaaadmemagkepi"), localFileURL: (resourceBundle?.url(forResource: "AdblockResources/Easylist/list1458", withExtension: "txt")!)!)
//
//        Task {
//
//            await AdBlockStats.shared.compile(lazyInfo: listInfo, resourcesInfo: resourceInfo)
//            await AdBlockStats.shared.compile(lazyInfo: listInfo7326, resourcesInfo: resourceInfo)
//            await AdBlockStats.shared.compile(lazyInfo: listInfo7844, resourcesInfo: resourceInfo)
//            await AdBlockStats.shared.compile(lazyInfo: listInfo1416, resourcesInfo: resourceInfo)
//        }
//    }
//
//    func addContentScript(_ helper: TabContentScript, name: String, forweb webview: WKWebView, contentWorld: WKContentWorld, scriptMessageHandlerWithReply: WKScriptMessageHandlerWithReply) {
//        if let _ = helpers[name] {
//          assertionFailure("Duplicate helper added: \(name)")
//        }
//
//        helpers[name] = helper
//        // If this helper handles script messages, then get the handler name and register it. The Tab
//      // receives all messages and then dispatches them to the right TabHelper.
//      let scriptMessageHandlerName = type(of: helper).messageHandlerName
//        webview.configuration.userContentController.addScriptMessageHandler(scriptMessageHandlerWithReply, contentWorld: contentWorld, name: scriptMessageHandlerName)
//    }
//
//    @MainActor
//    @objc
//    public func handleAdblockScript(webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, enableRequestBlocking: Bool) -> Bool {
//        guard var requestURL = navigationAction.request.url else {
//            return false;
//        }
//        if let mainDocumentURL = navigationAction.request.mainDocumentURL {
//            if mainDocumentURL != self.currentPageData?.mainFrameURL {
//                // Clear the current page data if the page changes.
//                // Do this before anything else so that we have a clean slate.
//                self.currentPageData = PageData(mainFrameURL: mainDocumentURL)
//            }
//
//            if navigationAction.targetFrame?.isMainFrame == true {
//                let scriptController = webView.configuration.userContentController
//
//                if let script = RequestBlockingContentScriptHandler.userScript {
//                  if(scriptController.userScripts.contains(script) == false) {
//                      scriptController.addUserScript(script)
//                  }
//                }
//            }
//        }
//
//        return true
//    }
//
//    @objc
//    public func isExistedRequestBlockingScript(webview: WKWebView?) -> Bool {
//        var result: Bool = false
//        if(webview != nil && RequestBlockingContentScriptHandler.userScript != nil ) {
//            result = webview!.configuration.userContentController.userScripts.contains(RequestBlockingContentScriptHandler.userScript!)
//        }
//        return result
//    }
//
//    @objc
//    public func setupContentScript(webView: WKWebView, scriptMessageHandlerWithReply: WKScriptMessageHandlerWithReply) {
//        if(self.requestBlockingContentHelper == nil) {
//            self.requestBlockingContentHelper = RequestBlockingContentScriptHandler(webView: webView)
//            self.addContentScript(self.requestBlockingContentHelper!, name: RequestBlockingContentScriptHandler.scriptName, forweb: webView, contentWorld: RequestBlockingContentScriptHandler.scriptSandbox, scriptMessageHandlerWithReply: scriptMessageHandlerWithReply)
//        } else {
//            // NSLog("The requestBlockingContentHelper object already inited !!!");
//        }
//    }
//
//
//    //
//    @objc
//    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
//        for helper in helpers.values {
//          let scriptMessageHandlerName = type(of: helper).messageHandlerName
//          if scriptMessageHandlerName == message.name {
//            helper.userContentController(userContentController, didReceiveScriptMessage: message, replyHandler: replyHandler)
//            return
//          }
//        }
//    }
//
//    @objc
//    public func setAdblockDebuggingEnabled(value: Bool) {
//        requestBlockingContentHelper?.setAdblockDebuggingEnabled(value: value)
//    }
}
