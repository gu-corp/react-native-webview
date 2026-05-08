//
//  DomainResolver.swift
//

import Foundation

final class DomainResolver {
    static let shared = DomainResolver()

    private let lock = NSLock()
    private lazy var parser: DomainParser? = try? DomainParser()

    private init() {}

    func baseDomain(for host: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return parser?.parse(host: host)?.domain
    }
}
