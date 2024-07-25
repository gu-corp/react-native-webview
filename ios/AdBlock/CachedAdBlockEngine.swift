//
//  CachedAdBlockEngine.swift
//  Greetings
//
//  Created by Dinh Minh Ngoc on 2024/07/09.
//

import Foundation

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
    
    private var cachedShouldBlockResult = FifoDict<String, Bool>()
    
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
    
    
    @available(iOS 13.0.0, *)
    func shouldBlock(requestURL: URL, sourceURL: URL, resourceType: AdblockRustEngine.ResourceType) async -> Bool {
        if #available(iOS 13.0, *) {
            return await withCheckedContinuation { continuation in
                serialQueue.async { [weak self] in
                    let shouldBlock = self?.shouldBlock(
                        requestURL: requestURL, sourceURL: sourceURL, resourceType: resourceType
                    ) == true
                    
                    continuation.resume(returning: shouldBlock)
                }
            }
        } else {
            return false
        }
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
    
}
