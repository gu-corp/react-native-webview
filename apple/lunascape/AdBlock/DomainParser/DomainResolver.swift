//
//  DomainResolver.swift
//

import Foundation

final class DomainResolver {
    static let shared = DomainResolver()

    private let parser: DomainParser?

    private init() {
        do {
            self.parser = try DomainParser()
        } catch {
            NSLog("[DomainResolver] Failed to init DomainParser: \(error)")
            self.parser = nil
        }
    }

    func baseDomain(for host: String) -> String? {
        return parser?.parse(host: host)?.domain
    }
}
