//
//  UserScriptManager.swift
//

import Foundation
import WebKit

public class ScriptLoader: TabContentScriptLoader { }

enum ScriptType: String, CaseIterable {
    case requestBlocking
    
    @available(iOS 14.0, *)
    fileprivate var script: WKUserScript? {
        switch self {
        case .requestBlocking: return RequestBlockingContentScriptHandler.userScript
        }
    }
    
    @available(iOS 14.0, *)
    private func loadScript(named: String) -> WKUserScript? {
        guard var script = ScriptLoader.loadUserScript(named: named) else {
            return nil
        }
        
        script = ScriptLoader.secureScript(handlerNamesMap: [:], securityToken: "", script: script)
        return WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .page)
    }
}

@available(iOS 14.0, *)
class UserScriptManager {
    static let shared = UserScriptManager()
    
    static let securityToken = ScriptLoader.uniqueID
    
    /// Scripts that are loaded after `staticScripts`
    private let dynamicScripts: [ScriptType: WKUserScript] = {
        ScriptType.allCases.reduce(into: [:]) { $0[$1] = $1.script }
    }()
    
    
    enum ScriptType: String, CaseIterable {
        case requestBlocking
        
        @available(iOS 14.0, *)
        fileprivate var script: WKUserScript? {
            switch self {
            case .requestBlocking: return RequestBlockingContentScriptHandler.userScript
            }
        }
        
        private func loadScript(named: String) -> WKUserScript? {
          guard var script = ScriptLoader.loadUserScript(named: named) else {
            return nil
          }
          
          script = ScriptLoader.secureScript(handlerNamesMap: [:], securityToken: "", script: script)
          return WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .page)
        }
    }
    
    /// Scripts injected before all other scripts.
    private let baseScripts: [WKUserScript] = {
        [
            (WKUserScriptInjectionTime.atDocumentStart, mainFrameOnly: false, sandboxed: false),
            (WKUserScriptInjectionTime.atDocumentEnd, mainFrameOnly: false, sandboxed: false),
            (WKUserScriptInjectionTime.atDocumentStart, mainFrameOnly: false, sandboxed: true),
            (WKUserScriptInjectionTime.atDocumentEnd, mainFrameOnly: false, sandboxed: true),
        ].compactMap { (injectionTime, mainFrameOnly, sandboxed) in
            
            if let source = ScriptLoader.loadUserScript(named: "__firefox__") {
                return WKUserScript(
                    source: source,
                    injectionTime: injectionTime,
                    forMainFrameOnly: mainFrameOnly,
                    in: sandboxed ? .defaultClient : .page)
            }
            
            return nil
        }
    }()
    
    public func loadScripts(into webView: WKWebView, scripts: Set<ScriptType>) {
        var scripts = scripts
        let scriptController = webView.configuration.userContentController
        
//        // Remove all existing user scripts
//        scriptController.removeAllUserScripts()
        
        // Inject all base scripts
        self.baseScripts.forEach {
            scriptController.addUserScript($0)
        }
        
        // Inject specifically RequestBlocking BEFORE other scripts
        // this is because it needs to hook requests before RewardsReporting
        if scripts.contains(.requestBlocking), let script = self.dynamicScripts[.requestBlocking] {
            scripts.remove(.requestBlocking)
            scriptController.addUserScript(script)
        }
        
        //        // Inject all static scripts
        //        self.staticScripts.forEach {
        //            scriptController.addUserScript($0)
        //        }
        
        // Inject all optional scripts
        self.dynamicScripts.filter { scripts.contains($0.key) }.forEach {
            scriptController.addUserScript($0.value)
        }
    }
    
    func loadCustomScripts(
        into webView: WKWebView,
        userScripts: Set<ScriptType>,
        customScripts: Set<UserScriptType>
    ) {
        loadScripts(into: webView, scripts: userScripts)
        let scriptController = webView.configuration.userContentController
        
        for userScriptType in customScripts.sorted(by: { $0.order < $1.order }) {
            do {
                let script = try ScriptFactory.shared.makeScript(for: userScriptType)
                scriptController.addUserScript(script)
            } catch {
                assertionFailure("Should never happen. The scripts are packed in the project and loading/modifying should always be possible.")
            }
        }
    }
}
