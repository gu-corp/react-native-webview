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

}
