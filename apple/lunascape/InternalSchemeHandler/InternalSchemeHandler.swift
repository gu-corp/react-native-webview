// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import WebKit

enum InternalPageSchemeHandlerError: Error {
    case badURL
    case noResponder
    case responderUnableToHandle
    case notAuthorized
}

protocol InterstitialPageHandler {
    func canHandle(error: NSError) -> Bool
    func response(for model: ErrorPageModel) -> (URLResponse, Data)?
}

public protocol InternalSchemeResponse {
    func response(forRequest: URLRequest) -> (URLResponse, Data)?
}

@available(iOS 11.0, *)
@objc(InternalSchemeHandler)
public class InternalSchemeHandler: NSObject, WKURLSchemeHandler {
    
    public static func response(forUrl url: URL) -> URLResponse {
        return URLResponse(url: url, mimeType: "text/html", expectedContentLength: -1, textEncodingName: "utf-8")
    }
    
    // Responders are looked up based on the path component, for instance responder["about/license"] is used for 'internal://local/about/license'
    public static var responders: [String: InternalSchemeResponse] = {
        return [
            ErrorPageHandler.path: ErrorPageHandler(),
        ]
    }()
    
    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(InternalPageSchemeHandlerError.badURL)
            return
        }
        
        let path = url.path.starts(with: "/") ? String(url.path.dropFirst()) : url.path
        
        // For non-main doc URL, try load it as a resource
        if !urlSchemeTask.request.isPrivileged, urlSchemeTask.request.mainDocumentURL != urlSchemeTask.request.url {
            return
        }
        
        // Need a better way to detect when WebKit is making a request from interactionState vs. a regular request by the user
        // instead of having to check the cache policy
        if !urlSchemeTask.request.isPrivileged && urlSchemeTask.request.cachePolicy == .useProtocolCachePolicy {
            urlSchemeTask.didFailWithError(InternalPageSchemeHandlerError.notAuthorized)
            return
        }
        
        guard let responder = InternalSchemeHandler.responders[path] else {
            urlSchemeTask.didFailWithError(InternalPageSchemeHandlerError.noResponder)
            return
        }
        
        guard let (urlResponse, data) = responder.response(forRequest: urlSchemeTask.request) else {
            urlSchemeTask.didFailWithError(InternalPageSchemeHandlerError.responderUnableToHandle)
            return
        }
        
        urlSchemeTask.didReceive(urlResponse)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
