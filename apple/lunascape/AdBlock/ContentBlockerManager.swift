//
//  ContentBlockerManager.swift
//

import Foundation
import WebKit

@available(iOS 13.0.0, *)
actor ContentBlockerManager {
    
    struct CompileOptions: OptionSet {
      let rawValue: Int
      
      static let stripContentBlockers = CompileOptions(rawValue: 1 << 0)
      static let punycodeDomains = CompileOptions(rawValue: 1 << 1)
      static let all: CompileOptions = [.stripContentBlockers, .punycodeDomains]
    }
    
    enum BlockingMode: CaseIterable {
      /// This is a general version that is supported on both standard and aggressive mode
      case general
      /// This indicates a less aggressive (or general) blocking version of the content blocker.
      ///
      /// In this version we will not block 1st party ad content.
      /// We will apped a rule that specifies that 1st party content should be ignored.
      case standard
      /// This indicates a more aggressive blocking version of the content blocker.
      ///
      /// In this version we will block 1st party ad content.
      /// We will not append a rule that specifies that 1st party content should be ignored.
      case aggressive
    }
    
    enum CompileError: Error {
      case noRuleListReturned
      case invalidJSONArray
    }
    
    public enum GenericBlocklistType: Hashable, CaseIterable {
      case blockAds
      case blockCookies
      case blockTrackers
      case upgradeMixedContent
      
      func mode(isAggressiveMode: Bool) -> BlockingMode {
        switch self {
        case .blockAds:
          if isAggressiveMode {
            return .aggressive
          } else {
            return .standard
          }
        case .blockCookies, .blockTrackers, .upgradeMixedContent:
          return .general
        }
      }
      
      var bundledFileName: String {
        switch self {
        case .blockAds: return "block-ads"
        case .blockCookies: return "block-cookies"
        case .blockTrackers: return "block-trackers"
        case .upgradeMixedContent: return "mixed-content-upgrade"
        }
      }
    }
    
    public enum BlocklistType: Hashable, CustomDebugStringConvertible {
      fileprivate static let genericPrifix = "stored-type"
      fileprivate static let filterListPrefix = "filter-list"
      fileprivate static let filterListURLPrefix = "filter-list-url"
      
      case generic(GenericBlocklistType)
      case filterList(componentId: String, isAlwaysAggressive: Bool)
      case customFilterList(uuid: String)
      
      private var identifier: String {
        switch self {
        case .generic(let type):
          return [Self.genericPrifix, type.bundledFileName].joined(separator: "-")
        case .filterList(let componentId, _):
          return [Self.filterListPrefix, componentId].joined(separator: "-")
        case .customFilterList(let uuid):
          return [Self.filterListURLPrefix, uuid].joined(separator: "-")
        }
      }
      
      func mode(isAggressiveMode: Bool) -> BlockingMode {
        switch self {
        case .customFilterList:
          return .general
        case .filterList(_, let isAlwaysAggressive):
          if isAlwaysAggressive || isAggressiveMode {
            return .aggressive
          } else {
            return .standard
          }
        case .generic(let genericType):
          return genericType.mode(isAggressiveMode: isAggressiveMode)
        }
      }
      
      var allowedModes: [BlockingMode] {
        var allowedModes: Set<BlockingMode> = []
        allowedModes.insert(mode(isAggressiveMode: true))
        allowedModes.insert(mode(isAggressiveMode: false))
        return BlockingMode.allCases.filter({ allowedModes.contains($0) })
      }
      
      func makeIdentifier(for mode: BlockingMode) -> String {
        switch mode {
        case .general:
          return identifier
        case .aggressive:
          return [self.identifier, "aggressive"].joined(separator: "-")
        case .standard:
          return [self.identifier, "standard"].joined(separator: "-")
        }
      }
      
      public var debugDescription: String {
        return identifier
      }
    }
    
}
