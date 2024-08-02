//
//  CachedAdBlockEngine.swift
//  Greetings
//
//  Created by Dinh Minh Ngoc on 2024/07/09.
//

import Foundation

@available(iOS 13.0.0, *)
public class CachedAdBlockEngine {
    public enum Source: Hashable, CustomDebugStringConvertible {
        case adBlock
        case filterList(componentId: String)
        case filterListURL(uuid: String)
        
        public var debugDescription: String {
            switch self {
            case .adBlock: return "adBlock"
            case .filterList(let componentId): return "filterList(\(componentId))"
            case .filterListURL(let uuid): return "filterListURL(\(uuid))"
            }
        }
    }
    
    public struct FilterListInfo: Hashable, Equatable, CustomDebugStringConvertible {
        let source: Source
        let localFileURL: URL
        
        public var debugDescription: String {
            return "\(source.debugDescription)"
        }
    }
    
    public struct ResourcesInfo: Hashable, Equatable {
        let localFileURL: URL
    }
    
    private var cachedCosmeticFilterModels = FifoDict<URL, CosmeticFilterModel?>()
    private var cachedShouldBlockResult = FifoDict<String, Bool>()
    private var cachedFrameScriptTypes = FifoDict<URL, Set<UserScriptType>>()
    
    private let engine: AdblockRustEngine
    private let serialQueue: DispatchQueue
    
    let filterListInfo: FilterListInfo
    let resourcesInfo: ResourcesInfo
    
    init(engine: AdblockRustEngine, filterListInfo: FilterListInfo, resourcesInfo: ResourcesInfo, serialQueue: DispatchQueue) {
        self.engine = engine
        self.filterListInfo = filterListInfo
        self.resourcesInfo = resourcesInfo
        self.serialQueue = serialQueue
    }
    
    
    func shouldBlock(requestURL: URL, sourceURL: URL, resourceType: AdblockRustEngine.ResourceType) async -> Bool {
        return await withCheckedContinuation { continuation in
            serialQueue.async { [weak self] in
                let shouldBlock = self?.shouldBlock(
                    requestURL: requestURL, sourceURL: sourceURL, resourceType: resourceType
                ) == true
                
                continuation.resume(returning: shouldBlock)
            }
        }
    }
    
    func selectorsForCosmeticRules(frameURL: URL, ids: [String], classes: [String]) async throws -> Set<String>? {
      return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Set<String>?, Error>) in
        serialQueue.async { [weak self] in
          guard let self = self else {
            continuation.resume(returning: nil)
            return
          }
          
          do {
            let model = try self.cachedCosmeticFilterModel(forFrameURL: frameURL)
            
            let selectors = try self.engine.stylesheetForCosmeticRulesIncluding(
              classes: classes, ids: ids, exceptions: model?.exceptions ?? []
            )

            continuation.resume(returning: Set(selectors))
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }
    
    @MainActor func makeEngineScriptTypes(frameURL: URL, isMainFrame: Bool, index: Int) async throws -> Set<UserScriptType> {
      if let userScriptTypes = cachedFrameScriptTypes.getElement(frameURL) {
        return userScriptTypes
      }
      
      // Add the selectors poller scripts for this frame
      var userScriptTypes: Set<UserScriptType> = []
      
      if let source = try await cosmeticFilterModel(forFrameURL: frameURL)?.injectedScript, !source.isEmpty {
        let configuration = UserScriptType.EngineScriptConfiguration(
          frameURL: frameURL, isMainFrame: isMainFrame, source: source, order: index,
          isDeAMPEnabled: true
        )
        
        userScriptTypes.insert(.engineScript(configuration))
      }
        
      cachedFrameScriptTypes.addElement(userScriptTypes, forKey: frameURL)
      return userScriptTypes
    }
    
    private func cachedCosmeticFilterModel(forFrameURL frameURL: URL) throws -> CosmeticFilterModel? {
      if let result = self.cachedCosmeticFilterModels.getElement(frameURL) {
        return result
      }
      
      let model = try self.engine.cosmeticFilterModel(forFrameURL: frameURL)
      self.cachedCosmeticFilterModels.addElement(model, forKey: frameURL)
      return model
    }
    
    private func shouldBlock(requestURL: URL, sourceURL: URL, resourceType: AdblockRustEngine.ResourceType) -> Bool {
        let key = [requestURL.absoluteString, sourceURL.absoluteString, resourceType.rawValue].joined(separator: "_")
        
        if let cachedResult = cachedShouldBlockResult.getElement(key) {
            return cachedResult
        }
        
        let shouldBlock = engine.shouldBlock(
            requestURL: requestURL,
            sourceURL: sourceURL,
            resourceType: resourceType
        )
        
        cachedShouldBlockResult.addElement(shouldBlock, forKey: key)
        return shouldBlock
    }
    
    public static func compile(
        filterListInfo: FilterListInfo, resourcesInfo: ResourcesInfo
    ) throws -> CachedAdBlockEngine {
        let engine = try AdblockRustEngine(textFileURL: filterListInfo.localFileURL, resourcesFileURL: resourcesInfo.localFileURL)
        let serialQueue = DispatchQueue(label: "com.brave.WrappedAdBlockEngine.\(UUID().uuidString)")
        return CachedAdBlockEngine(
            engine: engine, filterListInfo: filterListInfo, resourcesInfo: resourcesInfo,
            serialQueue: serialQueue)
    }
    
    func cosmeticFilterModel(forFrameURL frameURL: URL) async throws -> CosmeticFilterModel? {
      return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CosmeticFilterModel?, Error>) in
        serialQueue.async { [weak self] in
          guard let self = self else {
            continuation.resume(returning: nil)
            return
          }
          
          do {
            if let model = try self.cachedCosmeticFilterModel(forFrameURL: frameURL) {
              continuation.resume(returning: model)
            } else {
              continuation.resume(returning: nil)
            }
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }
    
}
