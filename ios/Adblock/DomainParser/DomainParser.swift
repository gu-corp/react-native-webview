//
//  DomainParser.swift
//  DomainParser
//
//  Created by Jason Akakpo on 19/07/2018.
//  Copyright © 2018 Dashlane. All rights reserved.
//

import Foundation

enum DomainParserError: Error {
    case ruleParsingError(message: String)
}

/// Uses the public suffix list
public struct DomainParser: DomainParserProtocol {
    
    let parsedRules: ParsedRules
    
    let onlyBasicRules: Bool
    
    let basicDomainParser: BasicDomainParser
    
    /// Parse the `public_suffix_list` file and build the set of Rules
    /// Parameters:
    ///   - QuickParsing: IF true, the `exception` and `wildcard` rules will be ignored
    public init(quickParsing: Bool = false) throws {
        let bundlePath = Bundle.main.path(forResource: "Settings", ofType: "bundle")!
        let resourceBundle = Bundle(path: bundlePath)
        let linkList = (resourceBundle?.url(forResource: "public_suffix_list", withExtension: "dat"))!
        let data = try Data(contentsOf: linkList)

        // We don't need to sort the rules from "public_suffix_list" since
        // the file has already been sorted by the update script.
        try self.init(rulesData: data, quickParsing: quickParsing, sortRules: false)
    }

    init(rulesData: Data, quickParsing: Bool = false, sortRules: Bool = true) throws {
        parsedRules = try RulesParser().parse(raw: rulesData, sortRules: sortRules)
        basicDomainParser = BasicDomainParser(suffixes: parsedRules.basicRules)
        onlyBasicRules = quickParsing
    }

    public func parse(host: String) -> ParsedHost? {
        if onlyBasicRules {
            return basicDomainParser.parse(host: host)
        } else {
            return parseExceptionsAndWildCardRules(host: host) ?? basicDomainParser.parse(host: host)
        }
     }
    
    func parseExceptionsAndWildCardRules(host: String) -> ParsedHost? {
        let hostComponents = host.split(separator: ".")
        guard let lastLabelSubstring = hostComponents.last else {
            return nil
        }

        let lastLabel = String(lastLabelSubstring)
        let isMatching: (Rule) -> Bool = { $0.isMatching(hostLabels: hostComponents) }
        let rule = parsedRules.exceptions[lastLabel]?.first(where: isMatching) ??
                   parsedRules.wildcardRules[lastLabel]?.first(where: isMatching)

        return rule?.parse(hostLabels: hostComponents)
    }
}

private extension Bundle {

    static var current: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        class ClassInCurrentBundle {}
        return Bundle.init(for: ClassInCurrentBundle.self)
        #endif
    }
}
