//
//  URLPartinessScriptHandler.swift
//

import Foundation
import WebKit

@available(iOS 14.0, *)
class URLPartinessScriptHandler: TabContentScript {
  struct PartinessDTO: Decodable {
    struct PartinessDTOData: Decodable, Hashable {
      let sourceURL: String
      let urls: [String]
    }
    
    let securityToken: String
    let data: PartinessDTOData
  }
  
  static let scriptName = "URLPartinessScript"
  static let scriptId = CosmeticFiltersScriptHandler.scriptId
  static let messageHandlerName = "\(scriptName)_\(messageUUID)"
  static let scriptSandbox: WKContentWorld = .defaultClient
  static let userScript: WKUserScript? = nil
  
  private weak var webView: WKWebView?
  
  init(webView: WKWebView) {
    self.webView = webView
  }
  
  func userContentController(_ userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
    if !verifyMessage(message: message) {
      assertionFailure("Invalid security token. Fix the `SelectorsPollerScript.js` script")
      replyHandler(nil, nil)
      return
    }

    do {
      let data = try JSONSerialization.data(withJSONObject: message.body)
      let dto = try JSONDecoder().decode(PartinessDTO.self, from: data)
      var results: [String: Bool] = [:]
      
      guard let frameURL = URL(idnString: dto.data.sourceURL) else {
        // Since we can't create a url from the source,
        // we will assume they are all 3rd party
        for urlString in dto.data.urls {
          results[urlString] = false
        }
        
        replyHandler(results, nil)
        return
      }
      
      let frameETLD1 = frameURL.baseDomain
      
      for urlString in dto.data.urls {
        guard let etld1 = URL(idnString: urlString)?.baseDomain else {
          // We can't determine a url.
          // Let's assume it's 3rd party
          results[urlString] = false
          continue
        }
        
        results[urlString] = frameETLD1 == etld1
      }
      
      replyHandler(results, nil)
    } catch {
      assertionFailure("Invalid type of message. Fix the `RequestBlocking.js` script")
      replyHandler(nil, nil)
    }
  }
}
