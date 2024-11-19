//
//  CosmeticFiltersScriptHandler.swift
//

import Foundation
import WebKit

/// This handler receives a list of ids and selectors for a given frame for which it is then able to inject scripts and css rules in order to hide certain elements
///
/// The ids and classes are collected in the `SelectorsPollerScript.js` file.
@available(iOS 14.0, *)
class CosmeticFiltersScriptHandler: TabContentScript {
  struct CosmeticFiltersDTO: Decodable {
    struct CosmeticFiltersDTOData: Decodable, Hashable {
      let sourceURL: String
      let ids: [String]
      let classes: [String]
    }
    
    let securityToken: String
    let data: CosmeticFiltersDTOData
  }
  
  static let scriptName = "SelectorsPollerScript"
  static let scriptId = UUID().uuidString
  static let messageHandlerName = "\(scriptName)_\(messageUUID)"
  static let scriptSandbox: WKContentWorld = .defaultClient
  static let userScript: WKUserScript? = nil
  
  private weak var webView: WKWebView?
  
  init(webView: WKWebView) {
    self.webView = webView
  }
  
  func userContentController(_ userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
    if !verifyMessage(message: message) {
      assertionFailure("Invalid security token. Fix the `RequestBlocking.js` script")
      replyHandler(nil, nil)
      return
    }

    do {
      let data = try JSONSerialization.data(withJSONObject: message.body)
      let dto = try JSONDecoder().decode(CosmeticFiltersDTO.self, from: data)
      
      guard let frameURL = URL(string: dto.data.sourceURL) else {
        replyHandler(nil, nil)
        return
      }
      
      Task { @MainActor in
        let cachedEngines = await AdBlockStats.shared.cachedEngines()
        
        let selectorArrays = await cachedEngines.asyncConcurrentCompactMap { cachedEngine -> (selectors: Set<String>, isAlwaysAggressive: Bool)? in
          do {
            guard let selectors = try await cachedEngine.selectorsForCosmeticRules(
              frameURL: frameURL,
              ids: dto.data.ids,
              classes: dto.data.classes
            ) else {
              return nil
            }
            
            return (selectors, true)
          } catch {
            return nil
          }
        }
        
        var standardSelectors: Set<String> = []
        var aggressiveSelectors: Set<String> = []
        for tuple in selectorArrays {
          if tuple.isAlwaysAggressive {
            aggressiveSelectors = aggressiveSelectors.union(tuple.selectors)
          } else {
            standardSelectors = standardSelectors.union(tuple.selectors)
          }
        }
        
        replyHandler([
          "aggressiveSelectors": Array(aggressiveSelectors),
          "standardSelectors": Array(standardSelectors)
        ], nil)
      }
    } catch {
      assertionFailure("Invalid type of message. Fix the `RequestBlocking.js` script")
      replyHandler(nil, nil)
    }
  }
}
