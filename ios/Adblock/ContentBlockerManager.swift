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
    
    public static var shared = ContentBlockerManager()
    /// The store in which these rule lists should be compiled
    let ruleStore: WKContentRuleListStore
    /// We cached the rule lists so that we can return them quicker if we need to
    private var cachedRuleLists: [String: Result<WKContentRuleList, Error>]
    
    init(ruleStore: WKContentRuleListStore = .default()) {
      self.ruleStore = ruleStore
      self.cachedRuleLists = [:]
    }
    
    func compile(encodedContentRuleList: String, for type: BlocklistType, options: CompileOptions = [], modes: [BlockingMode]) async throws {
      guard !modes.isEmpty else { return }
      let cleanedRuleList: [[String: Any?]]
      
      do {
        print("encodedContentRuleList-->\(encodedContentRuleList)")
        cleanedRuleList = try await process(encodedContentRuleList: encodedContentRuleList, for: type, with: options)
      } catch {
        for mode in modes {
          self.cachedRuleLists[type.makeIdentifier(for: mode)] = .failure(error)
        }
        throw error
      }
      
      var foundError: Error?
      
      for mode in modes {
        let moddedRuleList = self.set(mode: mode, forRuleList: cleanedRuleList)
        let identifier = type.makeIdentifier(for: mode)
        
        do {
          let ruleList = try await compile(ruleList: moddedRuleList, for: type, mode: mode)
          self.cachedRuleLists[identifier] = .success(ruleList)
        } catch {
          self.cachedRuleLists[identifier] = .failure(error)
          foundError = error
        }
      }
      
      if let error = foundError {
        throw error
      }
    }
    
    func process(encodedContentRuleList: String, for type: BlocklistType, with options: CompileOptions) async throws -> [[String: Any?]] {
      var ruleList = try decode(encodedContentRuleList: encodedContentRuleList)
      if options.isEmpty { return ruleList }
      
      #if DEBUG
      let originalCount = ruleList.count
      #endif
      
      if options.contains(.stripContentBlockers) {
        ruleList = await stripCosmeticFilters(jsonArray: ruleList)
      }
      
      if options.contains(.punycodeDomains) {
        ruleList = await punycodeDomains(jsonArray: ruleList)
      }
      
      #if DEBUG
      let count = originalCount - ruleList.count
      if count > 0 {
        print("Filtered out \(count) rules for `\(type.debugDescription)`")
      }
      #endif
      
      return ruleList
    }
    
    public func ruleLists() async -> Set<WKContentRuleList> {
        let validBlocklistTypes: Set<BlocklistType> = [
            .generic(.blockAds),
            .generic(.blockTrackers),
            .generic(.upgradeMixedContent),
            .filterList(componentId: "cdbbhgbmjhfnhnmgeddbliobbofkgdhe", isAlwaysAggressive: true),
            .filterList(componentId: "bfpgedeaaibpoidldhjcknekahbikncb", isAlwaysAggressive: true),
            .filterList(componentId: "llgjaaddopeckcifdceaaadmemagkepi", isAlwaysAggressive: true)
      ]
      
      return await Set(validBlocklistTypes.asyncConcurrentCompactMap({ blocklistType -> WKContentRuleList? in
        let mode = blocklistType.mode(isAggressiveMode: true)
        do {
          return try await self.ruleList(for: blocklistType, mode: mode)
        } catch {
          // We can't log the error because some rules have empty rules. This is normal
          // But on relaunches we try to reload the filter list and this will give us an error.
          // Need to find a more graceful way of handling this so error here can be logged properly
          return nil
        }
      }))
    }
    
    func compileBundledRuleList(for genericType: GenericBlocklistType, modes: [BlockingMode]) async throws {
      guard !modes.isEmpty else { return }
        let bundlePath = Bundle.main.path(forResource: "Settings", ofType: "bundle")!
        let resourceBundle = Bundle(path: bundlePath)
      guard let fileURL = resourceBundle?.url(forResource: "AdblockResources/Blocklist/"+genericType.bundledFileName, withExtension: "json") else {
        assertionFailure("A bundled file shouldn't fail to load")
        return
      }
      
      let encodedContentRuleList = try String(contentsOf: fileURL)
      let type = BlocklistType.generic(genericType)
        print("bundle rule list -> \(fileURL)")
        print("bundle rule list type -> \(type)")
        print("bundle rule list modes -> \(modes)")
        
        
      try await compile(
        encodedContentRuleList: encodedContentRuleList,
        for: type, modes: modes
      )
    }
    
    private func stripCosmeticFilters(jsonArray: [[String: Any?]]) async -> [[String: Any?]] {
      let updatedArray = await jsonArray.asyncConcurrentCompactMap { dictionary in
        guard let actionDictionary = dictionary["action"] as? [String: Any] else {
          return dictionary
        }
        
        // Filter out with any dictionaries with `selector` actions
        if actionDictionary["selector"] != nil {
          return nil
        } else {
          return dictionary
        }
      }
      
      return updatedArray
    }
    
    private func punycodeDomains(jsonArray: [[String: Any?]]) async -> [[String: Any?]] {
      var jsonArray = jsonArray
      
      await jsonArray.enumerated().asyncConcurrentForEach({ index, dictionary in
        guard var triggerObject = dictionary["trigger"] as? [String: Any] else {
          return
        }
        
        if let domainArray = triggerObject["if-domain"] as? [String] {
          triggerObject["if-domain"] = self.punycodeConversion(domains: domainArray)
        }
        
        if let domainArray = triggerObject["unless-domain"] as? [String] {
          triggerObject["unless-domain"] = self.punycodeConversion(domains: domainArray)
        }
        
        jsonArray[index]["trigger"] = triggerObject
      })
      
      return jsonArray
    }
    
    private func punycodeConversion(domains: [String]) -> [String] {
      return domains.compactMap { domain -> String? in
        guard domain.allSatisfy({ $0.isASCII }) else {
          if let result = URL(idnString: domain)?.absoluteString {
            #if DEBUG
            print("Punycoded domain: \(domain) -> \(result)")
            #endif
            return result
          } else {
            #if DEBUG
            print("Could not punycode domain: \(domain)")
            #endif
            
            return nil
          }
        }
        
        return domain
      }
    }
    
    private func set(mode: BlockingMode, forRuleList ruleList: [[String: Any?]]) -> [[String: Any?]] {
      guard let lastRule = ruleList.last else { return ruleList }
      
      switch mode {
      case .aggressive:
        guard isFirstPartyException(jsonObject: lastRule) else { return ruleList }
        
        // Remove this rule to make it aggressive
        var ruleList = ruleList
        ruleList.removeLast()
        return ruleList
        
      case .standard:
        guard !isFirstPartyException(jsonObject: lastRule) else { return ruleList }
        
        // Add the ignore first party rule to make it standard
        var ruleList = ruleList
        ruleList.append([
          "action": ["type": "ignore-previous-rules"],
          "trigger": [
            "url-filter": ".*",
            "load-type": ["first-party"]
          ] as [String: Any?]
        ])
        return ruleList
        
      case .general:
        // Nothing needs to be done
        return ruleList
      }
    }
    
    private func isFirstPartyException(jsonObject: [String: Any?]) -> Bool {
      guard
        let actionDictionary = jsonObject["action"] as? [String: Any],
        let actionType = actionDictionary["type"] as? String, actionType == "ignore-previous-rules",
        let triggerDictionary = jsonObject["trigger"] as? [String: Any],
        let urlFilter = triggerDictionary["url-filter"] as? String, urlFilter == ".*",
        let loadType = triggerDictionary["load-type"] as? [String], loadType == ["first-party"],
        triggerDictionary["resource-type"] == nil
      else {
        return false
      }
      
      return true
    }
    
    private func compile(ruleList: [[String: Any?]], for type: BlocklistType, mode: BlockingMode) async throws -> WKContentRuleList {
      let identifier = type.makeIdentifier(for: mode)
      let modifiedData = try JSONSerialization.data(withJSONObject: ruleList)
      let cleanedRuleList = String(bytes: modifiedData, encoding: .utf8)
      let ruleList = try await ruleStore.compileContentRuleList(
        forIdentifier: identifier, encodedContentRuleList: cleanedRuleList)
      
      guard let ruleList = ruleList else {
        throw CompileError.noRuleListReturned
      }
      
      return ruleList
    }
    
    private func decode(encodedContentRuleList: String) throws -> [[String: Any?]] {
      guard let blocklistData = encodedContentRuleList.data(using: .utf8) else {
        assertionFailure()
        throw CompileError.invalidJSONArray
      }
      
      guard let jsonArray = try JSONSerialization.jsonObject(with: blocklistData) as? [[String: Any]] else {
        throw CompileError.invalidJSONArray
      }
      
      return jsonArray
    }
    
    /// Check if a rule list is compiled for this type
    func hasRuleList(for type: BlocklistType, mode: BlockingMode) async -> Bool {
      do {
        return try await ruleList(for: type, mode: mode) != nil
      } catch {
        return false
      }
    }
    
    /// Remove the rule list for the blocklist type
    public func removeRuleLists(for type: BlocklistType, force: Bool = false) async throws {
      for mode in type.allowedModes {
        try await removeRuleList(forIdentifier: type.makeIdentifier(for: mode), force: force)
      }
    }
    
    /// Load a rule list from the rule store and return it. Will use cached results if they exist
    func ruleList(for type: BlocklistType, mode: BlockingMode) async throws -> WKContentRuleList? {
      if let result = cachedRuleLists[type.makeIdentifier(for: mode)] {
        return try result.get()
      }
      
      return try await loadRuleList(for: type, mode: mode)
    }
    
    /// Return all the modes that need to be compiled for the given type
    func missingModes(for type: BlocklistType) async -> [BlockingMode] {
      return await type.allowedModes.asyncFilter { mode in
        // If the file wasn't modified, make sure we have something compiled.
        // We should, but this can be false during upgrades if the identifier changed for some reason.
        if await hasRuleList(for: type, mode: mode) {
          return false
        } else {
          return true
        }
      }
    }
    
//    func compileRuleList(at localFileURL: URL, for type: BlocklistType, options: CompileOptions = [], modes: [BlockingMode]) async throws {
//        print("localFileURL->\(localFileURL)")
//        print("type->\(type)")
//        print("options->\(options)")
//        print("modes->\(modes)")
//
//      let filterSet = try String(contentsOf: localFileURL)
//      let result = AdblockRustEngine.contentBlockerRules(fromFilterSet: filterSet)
//      try await compile(encodedContentRuleList: result, for: type, options: options, modes: modes)
//    }
    
    /// Remove the rule list for the given identifier. This will remove them from this local cache and from the rule store.
    private func removeRuleList(forIdentifier identifier: String, force: Bool) async throws {
      guard force || self.cachedRuleLists[identifier] != nil else { return }
      self.cachedRuleLists.removeValue(forKey: identifier)
      try await ruleStore.removeContentRuleList(forIdentifier: identifier)
    }
    
    private func loadRuleList(for type: BlocklistType, mode: BlockingMode) async throws -> WKContentRuleList? {
      let identifier = type.makeIdentifier(for: mode)
      
      do {
        guard let ruleList = try await ruleStore.contentRuleList(forIdentifier: identifier) else {
          return nil
        }
        
        self.cachedRuleLists[identifier] = .success(ruleList)
        return ruleList
      } catch {
        throw error
      }
    }
}
