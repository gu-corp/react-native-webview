import Foundation
import JavaScriptCore
import WebKit

extension URLComponents {
    // Return the first query parameter that matches
    public func valueForQuery(_ param: String) -> String? {
        return self.queryItems?.first { $0.name == param }?.value
    }
}

extension String {
    /// Encode HTMLStrings
    /// Also used for Strings which are not sanitized for displaying
    /// - Returns: Encoded String
    public var htmlEntityEncodedString: String {
        return
            self
            .replacingOccurrences(of: "&", with: "&amp;", options: .literal)
            .replacingOccurrences(of: "\"", with: "&quot;", options: .literal)
            .replacingOccurrences(of: "'", with: "&#39;", options: .literal)
            .replacingOccurrences(of: "<", with: "&lt;", options: .literal)
            .replacingOccurrences(of: ">", with: "&gt;", options: .literal)
            .replacingOccurrences(of: "`", with: "&lsquo;", options: .literal)
    }
}

private let apostropheEncoded = "%27"
enum JavascriptError: Error {
    case invalid
}
extension WKWebView {
    // Use JS to redirect the page without adding a history entry
    @available(iOS 14.0, *)
    func replaceLocation(with url: URL) {
        let safeUrl = url.absoluteString.replacingOccurrences(of: "'", with: apostropheEncoded)
        evaluateSafeJavaScript(
            functionName: "location.replace", 
            args: ["'\(safeUrl)'"], 
            contentWorld: .defaultClient, 
            escapeArgs: false, 
            asFunction: true, 
            completion: nil
        )
    }
    
    func generateJSFunctionString(functionName: String, args: [Any?], escapeArgs: Bool = true) -> (javascript: String, error: Error?) {
        var sanitizedArgs = [String]()
        for arg in args {
            if let arg = arg {
                do {
                    if let arg = arg as? String {
                        sanitizedArgs.append(escapeArgs ? "'\(arg.htmlEntityEncodedString)'" : "\(arg)")
                    } else {
                        let data = try JSONSerialization.data(withJSONObject: arg, options: [.fragmentsAllowed])
                        
                        if let str = String(data: data, encoding: .utf8) {
                            sanitizedArgs.append(str)
                        } else {
                            throw JavascriptError.invalid
                        }
                    }
                } catch {
                    return ("", error)
                }
            } else {
                sanitizedArgs.append("null")
            }
        }
        
        if args.count != sanitizedArgs.count {
            assertionFailure("Javascript parsing failed.")
            return ("", JavascriptError.invalid)
        }
        
        return ("\(functionName)(\(sanitizedArgs.joined(separator: ", ")))", nil)
    }
    
    @available(iOS 14.0, *)
    func evaluateSafeJavaScript(functionName: String, args: [Any] = [], frame: WKFrameInfo? = nil, contentWorld: WKContentWorld, escapeArgs: Bool = true, asFunction: Bool = true, completion: ((Any?, Error?) -> Void)? = nil) {
        var javascript = functionName
        
        if asFunction {
            let js = generateJSFunctionString(functionName: functionName, args: args, escapeArgs: escapeArgs)
            if js.error != nil {
                if let completionHandler = completion {
                    completionHandler(nil, js.error)
                }
                return
            }
            javascript = js.javascript
        }
        
        DispatchQueue.main.async {
            // swiftlint:disable:next safe_javascript
            self.evaluateJavaScript(javascript, in: frame, in: contentWorld) { result in
                switch result {
                    case .success(let value):
                        completion?(value, nil)
                    case .failure(let error):
                        completion?(nil, error)
                }
            }
        }
    }
    
}
