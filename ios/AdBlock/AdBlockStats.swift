//
//  AdBlockStats.swift
//  Greetings
//
//  Created by Dinh Minh Ngoc on 2024/07/09.
//

import Foundation

@available(iOS 13.0.0, *)
public actor AdBlockStats {
    public static let shared = AdBlockStats()
    private(set) var availableFilterLists: [CachedAdBlockEngine.Source: CachedAdBlockEngine.FilterListInfo]
    private(set) var resourcesInfo: CachedAdBlockEngine.ResourcesInfo?
    private(set) var cachedEngines: [CachedAdBlockEngine.Source: CachedAdBlockEngine]
    private var currentCompileTask: Task<(), Never>?
    
    @MainActor var enabledSources: [CachedAdBlockEngine.Source] {
        var enabledSources: [CachedAdBlockEngine.Source] = [.adBlock, .filterList(componentId: "cdbbhgbmjhfnhnmgeddbliobbofkgdhe"), .filterList(componentId: "bfpgedeaaibpoidldhjcknekahbikncb"), .filterList(componentId: "llgjaaddopeckcifdceaaadmemagkepi")]
      return enabledSources
    }
    
    init() {
      cachedEngines = [:]
      availableFilterLists = [:]
    }
    
    func makeEngineScriptTypes(frameURL: URL, isMainFrame: Bool) async -> Set<UserScriptType> {
      // Add any engine scripts for this frame
      return await cachedEngines().enumerated().asyncMap({ index, cachedEngine -> Set<UserScriptType> in
        do {
          return try await cachedEngine.makeEngineScriptTypes(
            frameURL: frameURL, isMainFrame: isMainFrame, index: index
          )
        } catch {
          assertionFailure()
          return []
        }
      }).reduce(Set<UserScriptType>(), { partialResult, scriptTypes in
        return partialResult.union(scriptTypes)
      })
    }
    
    func shouldBlock(requestURL: URL, sourceURL: URL, resourceType: AdblockRustEngine.ResourceType) async -> Bool {
      let sources = await self.enabledSources
      return await cachedEngines(for: sources).asyncConcurrentMap({ cachedEngine in
        return await cachedEngine.shouldBlock(
          requestURL: requestURL,
          sourceURL: sourceURL,
          resourceType: resourceType
        )
      }).contains(where: { $0 })
    }
    
    public func compile(
      lazyInfo: CachedAdBlockEngine.FilterListInfo, resourcesInfo: CachedAdBlockEngine.ResourcesInfo
    ) async {
      await currentCompileTask?.value
      
      currentCompileTask = Task {
        // Compile engine
        if cachedEngines[lazyInfo.source] == nil {
          do {
            let engine = try CachedAdBlockEngine.compile(
              filterListInfo: lazyInfo, resourcesInfo: resourcesInfo
            )
            
            add(engine: engine)
          } catch {
            print("Failed to compile engine for \(lazyInfo.source.debugDescription)")
          }
        }
      }
        
//        if let blocklistType = lazyInfo.blocklistType {
//          let modes = await ContentBlockerManager.shared.missingModes(for: blocklistType)
//          guard !modes.isEmpty else { return }
//
//          do {
//            try await ContentBlockerManager.shared.compileRuleList(
//              at: lazyInfo.localFileURL, for: blocklistType, modes: modes
//            )
//          } catch {
//            print("Failed to compile rule list for \(lazyInfo.source.debugDescription)")
//          }
//        }
      
      await currentCompileTask?.value
    }
    
    @MainActor func cachedEngines() async -> [CachedAdBlockEngine] {
        return await self.cachedEngines(for: self.enabledSources)
    }
    
    private func add(engine: CachedAdBlockEngine) {
        cachedEngines[engine.filterListInfo.source] = engine
        availableFilterLists[engine.filterListInfo.source] = engine.filterListInfo
        self.resourcesInfo = engine.resourcesInfo
    }
    
    private func cachedEngines(for sources: [CachedAdBlockEngine.Source]) -> [CachedAdBlockEngine] {
      return sources.compactMap { source -> CachedAdBlockEngine? in
        return cachedEngines[source]
      }
    }
}

@available(iOS 13.0.0, *)
extension CachedAdBlockEngine.FilterListInfo {
  var blocklistType: ContentBlockerManager.BlocklistType? {
    switch source {
    case .adBlock:
      // Normally this should be .generic(.blockAds)
      // but this content blocker is coming from slim-list
      return nil
    case .filterList(let componentId):
      return .filterList(componentId: componentId, isAlwaysAggressive: true)
    case .filterListURL(let uuid):
      return .customFilterList(uuid: uuid)
    }
  }
}
