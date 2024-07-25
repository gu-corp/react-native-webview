//
//  URLExtension.swift
//  Greetings
//
//  Created by Dinh Minh Ngoc on 2024/07/08.
//

import UIKit

extension URL {
    public var isIPv6: Bool {
        return host?.contains(":") ?? false
    }
    
    public var baseDomain: String? {
        guard !isIPv6, let host = host else { return nil }
        
        // If this is just a hostname and not a FQDN, use the entire hostname.
        if !host.contains(".") {
            return host
        }
        
        let domainParser = try? DomainParser()
        return domainParser?.parse(host: host)?.domain
    }
    
    init?(idnString: String) {
        guard let encodedString = idnString.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
            return nil
        }
        self.init(string: encodedString)
    }
    
    public var domainURL: URL {
      if let normalized = self.normalizedHost() {
        // Use URLComponents instead of URL since the former correctly preserves
        // brackets for IPv6 hosts, whereas the latter escapes them.
        var components = URLComponents()
        components.scheme = self.scheme
        components.port = self.port
        components.host = normalized
        return components.url ?? self
      }

      return self
    }
    
    public func normalizedHost(stripWWWSubdomainOnly: Bool = false) -> String? {
      // Use components.host instead of self.host since the former correctly preserves
      // brackets for IPv6 hosts, whereas the latter strips them.
      guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false), var host = components.host, host != "" else {
        return nil
      }

      let textToReplace = stripWWWSubdomainOnly ? "^(www)\\." : "^(www|mobile|m)\\."

      if let range = host.range(of: textToReplace, options: .regularExpression) {
        host.replaceSubrange(range, with: "")
      }

      return host
    }
    
    public var schemelessAbsoluteString: String {
      guard let scheme = self.scheme else { return absoluteString }
      return absoluteString.replacingOccurrences(of: "\(scheme)://", with: "")
    }
}
