
import Foundation
import WebKit

@available(iOS 14.0, *)
class RequestBlockingContentScriptHandler: TabContentScript {
  struct RequestBlockingDTO: Decodable {
    struct RequestBlockingDTOData: Decodable, Hashable {
      let resourceType: AdblockRustEngine.ResourceType
      let resourceURL: String
      let sourceURL: String
    }
    
    let securityToken: String
    let data: RequestBlockingDTOData
  }
  
  static let scriptName = "RequestBlockingScript"
  static let scriptId = UUID().uuidString
  static let messageHandlerName = "\(scriptName)_\(messageUUID)"
  static let scriptSandbox: WKContentWorld = .page
  static let userScript: WKUserScript? = {
    guard var script = loadUserScript(named: scriptName) else {
      return nil
    }
    
    return WKUserScript(source: secureScript(handlerName: messageHandlerName,
                                             securityToken: scriptId,
                                             script: script),
                        injectionTime: .atDocumentStart,
                        forMainFrameOnly: false,
                        in: scriptSandbox)
  }()
  
  private weak var webView: WKWebView?
  
  init(webView: WKWebView) {
    self.webView = webView
  }
  
  func userContentController(_ userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
      guard let currentTabURL = self.webView?.url else {
      assertionFailure("Should have a tab set")
      return
    }
    
    if !verifyMessage(message: message) {
      assertionFailure("Invalid security token. Fix the `RequestBlocking.js` script")
      replyHandler(false, nil)
      return
    }

    do {
      let data = try JSONSerialization.data(withJSONObject: message.body)
      let dto = try JSONDecoder().decode(RequestBlockingDTO.self, from: data)
      
      // Because javascript urls allow some characters that `URL` does not,
      // we use `NSURL(idnString: String)` to parse them
      guard let requestURL = URL(idnString: dto.data.resourceURL) else { return }
      guard let sourceURL = URL(idnString: dto.data.sourceURL) else { return }
      
      Task { @MainActor in
        let shouldBlock = await AdBlockStats.shared.shouldBlock(
          requestURL: requestURL, sourceURL: sourceURL, resourceType: dto.data.resourceType
        )
        replyHandler(shouldBlock, nil)
      }
    } catch {
      assertionFailure("Invalid type of message. Fix the `RequestBlocking.js` script")
      replyHandler(false, nil)
    }
  }
}
