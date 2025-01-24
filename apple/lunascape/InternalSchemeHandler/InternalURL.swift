/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

public struct InternalURL {
    public static let uuid = UUID().uuidString
    public static let scheme = "internal"
    public static let host = "local"
    public static let baseUrl = "\(scheme)://\(host)"
    public enum Path: String {
        case errorpage = "errorpage"
        case sessionrestore = "sessionrestore"
        case readermode = "reader-mode"
        func matches(_ string: String) -> Bool {
            return string.range(of: "/?\(self.rawValue)", options: .regularExpression, range: nil, locale: nil) != nil
        }
    }

    public enum Param: String {
        case uuidkey = "uuidkey"
        case url = "url"
        func matches(_ string: String) -> Bool { return string == self.rawValue }
    }
    
    public let url: URL
    private let sessionRestoreHistoryItemBaseUrl = "\(InternalURL.baseUrl)/\(InternalURL.Path.sessionrestore.rawValue)?url="

    public static func isValid(url: URL) -> Bool {
        return InternalURL.scheme == url.scheme && InternalURL.host == url.host
    }

    public init?(_ url: URL) {
        guard InternalURL.isValid(url: url) else {
            return nil
        }
        
        self.url = url
    }

    public var isAuthorized: Bool {
        return (url.getQuery()[InternalURL.Param.uuidkey.rawValue] ?? "") == InternalURL.uuid
    }

    public var stripAuthorization: String {
        guard var components = URLComponents(string: url.absoluteString), let items = components.queryItems else {
            return url.absoluteString
        }
        
        components.queryItems = items.filter { !Param.uuidkey.matches($0.name) }
        if let items = components.queryItems, items.count == 0 {
            components.queryItems = nil  // This cleans up the url to not end with a '?'
        }
        return components.url?.absoluteString ?? ""
    }

    public static func authorize(url: URL) -> URL? {
        guard var components = URLComponents(string: url.absoluteString) else { return nil }
        if components.queryItems == nil {
            components.queryItems = []
        }

        if var item = components.queryItems?.first(where: { Param.uuidkey.matches($0.name) }) {
            item.value = InternalURL.uuid
        } else {
            components.queryItems?.append(URLQueryItem(name: Param.uuidkey.rawValue, value: InternalURL.uuid))
        }
        return components.url
    }

    public var isSessionRestore: Bool {
        return url.absoluteString.hasPrefix(sessionRestoreHistoryItemBaseUrl)
    }

    public var isErrorPage: Bool {
        // Error pages can be nested in session restore URLs,
        // and session restore handler will forward them to the error page handler
        let path = url.absoluteString.hasPrefix(sessionRestoreHistoryItemBaseUrl) ? extractedUrlParam?.path : url.path
        return InternalURL.Path.errorpage.matches(path ?? "")
    }
  
    public var isReaderModePage: Bool {
        return InternalURL.Path.readermode.matches(url.path)
    }

    public var originalURLFromErrorPage: URL? {
        if !url.absoluteString.hasPrefix(sessionRestoreHistoryItemBaseUrl) {
            return isErrorPage ? extractedUrlParam : nil
        }
        if let urlParam = extractedUrlParam, let nested = InternalURL(urlParam), nested.isErrorPage {
            return nested.extractedUrlParam
        }
        return nil
    }

    public var extractedUrlParam: URL? {
        if let nestedUrl = url.getQuery()[InternalURL.Param.url.rawValue]?.unescape() {
            return URL(string: nestedUrl)
        }
        return nil
    }
}

extension String {
    public func unescape() -> String? {
        return self.removingPercentEncoding
    }
}
