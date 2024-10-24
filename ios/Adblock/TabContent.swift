//
//  TabContent.swift
//  react-native-webview
//
//  Created by Alobridge on 2/8/24.
//

import UIKit
import WebKit

protocol TabContentScriptLoader {
  static func loadUserScript(named: String) -> String?
  static func secureScript(handlerName: String, securityToken: String, script: String) -> String
  static func secureScript(handlerNamesMap: [String: String], securityToken: String, script: String) -> String
}

@available(iOS 14.0, *)
protocol TabContentScript: TabContentScriptLoader {
  static var scriptName: String { get }
  static var scriptId: String { get }
  static var messageHandlerName: String { get }
  static var scriptSandbox: WKContentWorld { get }
  static var userScript: WKUserScript? { get }
  
  func verifyMessage(message: WKScriptMessage) -> Bool
  func verifyMessage(message: WKScriptMessage, securityToken: String) -> Bool
  
  func userContentController(_ userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void)
}

extension TabContentScriptLoader {
  static var uniqueID: String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "")
  }
  
  static var messageUUID: String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "")
  }
  
  static func loadUserScript(named: String) -> String? {
      let bundlePath = Bundle.main.path(forResource: "Settings", ofType: "bundle")!
      let resourceBundle = Bundle(path: bundlePath)
      guard let path = resourceBundle?.url(forResource: named, withExtension: "js"),
            let source = try? String(contentsOf: path) else {
          assertionFailure("Failed to Load Script: \(named).js")
          return nil
      }
    return source
  }
  
  static func secureScript(handlerName: String, securityToken: String, script: String) -> String {
    secureScript(handlerNamesMap: ["$<message_handler>": handlerName], securityToken: securityToken, script: script)
  }
  
  static func secureScript(handlerNamesMap: [String: String], securityToken: String, script: String) -> String {
    guard !script.isEmpty else {
      return script
    }
    
    var script = script
    for (obfuscatedHandlerName, actualHandlerName) in handlerNamesMap {
      script = script.replacingOccurrences(of: obfuscatedHandlerName, with: actualHandlerName)
    }
    
    let messageHandlers: String = {
      if !handlerNamesMap.isEmpty {
        let handlers = "[\(handlerNamesMap.map({"'\($0.value)'"}).joined(separator: ", "))]"
        return """
        \(handlers).forEach(e => {
            if (e && e.length > 0 && webkit.messageHandlers[e]) {
              Object.freeze(webkit.messageHandlers[e]);
              Object.freeze(webkit.messageHandlers[e].postMessage);
            }
          });
        """
      }
      return ""
    }()
    
    return """
    (function() {
      const SECURITY_TOKEN = '\(securityToken)';
    
      \(messageHandlers)
    
      \(script)
    })();
    """
  }
}

@available(iOS 14.0, *)
extension TabContentScript {
  func verifyMessage(message: WKScriptMessage) -> Bool {
    verifyMessage(message: message, securityToken: Self.scriptId)
  }
  
  func verifyMessage(message: WKScriptMessage, securityToken: String) -> Bool {
    (message.body as? [String: Any])?["securityToken"] as? String == securityToken
  }
}
