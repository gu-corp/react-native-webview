//
//  DomainParserProtocol.swift
//  DomainParser
//

import Foundation

public protocol DomainParserProtocol {
    func parse(host: String) -> ParsedHost?
}

public struct FakeDomainParser: DomainParserProtocol {
    public init(){}
    public func parse(host: String) -> ParsedHost? {
        return nil
    }
}
