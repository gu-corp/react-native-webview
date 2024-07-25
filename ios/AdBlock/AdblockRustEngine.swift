import Foundation

/// A wrapper around adblock_rust_lib header.
class AdblockRustEngine {
    
    public enum ResourceType: String, Decodable {
        case xmlhttprequest
        case script
        case image
        case subdocument
    }
    
    public enum CompileError: Error {
        case invalidResourceJSON
        case fileNotFound
        case couldNotDeserializeDATFile
    }
    
    private let engine: OpaquePointer
    
    convenience init(textFileURL fileURL: URL, resourcesFileURL: URL) throws {
        try self.init(rules: String(contentsOf: fileURL))
        try useResources(fromFileURL: resourcesFileURL)
    }
    
    init(rules: String = "") { engine = engine_create(rules) }
    deinit { engine_destroy(engine) }
    
    public func shouldBlock(requestURL: URL, sourceURL: URL, resourceType: ResourceType) -> Bool {
        var didMatchRule = false
        var didMatchException = false
        var didMatchImportant = false
        
        guard requestURL.scheme != "data" else {
            // TODO: @JS Investigate if we need to deal with data schemes and if so, how?
            return false
        }
        
        guard sourceURL.absoluteString != "about:blank" else {
            // TODO: @JS Investigate why sometimes `sourceURL` is `about:blank` and find out how to deal with it
            return false
        }
        
        guard let requestDomain = requestURL.baseDomain, let sourceDomain = sourceURL.baseDomain else {
            return false
        }
        
        guard let requestHost = requestURL.host, let sourceHost = sourceURL.host else {
            return false
        }
        
        let isThirdParty = requestDomain != sourceDomain
        
        var emptyPointer: UnsafeMutablePointer<Int8>?
        
        engine_match(engine, requestURL.absoluteString, requestHost,
                     sourceHost, isThirdParty, resourceType.rawValue,
                     &didMatchRule, &didMatchException,
                     &didMatchImportant,
                     UnsafeMutablePointer(mutating: &emptyPointer),UnsafeMutablePointer(mutating: &emptyPointer))
        return didMatchRule
    }
    
    private func useResources(fromFileURL fileURL: URL) throws {
        if let json = try Self.validateJSON(Data(contentsOf: fileURL)) {
            engine_use_resources(engine, json)
        }
    }
    
    static func validateJSON(_ data: Data) throws -> String? {
        let value = try JSONSerialization.jsonObject(with: data, options: [])
        
        if let value = value as? NSArray {
            guard value.count > 0 else { return nil }
            return String(data: data, encoding: .utf8)
        }
        
        guard let value = value as? NSDictionary else {
            throw CompileError.invalidResourceJSON
        }
        
        guard value.count > 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    @discardableResult func set(data: Data) -> Bool {
        return engine_deserialize(engine, data.int8Array, data.count)
    }
    
    @discardableResult func set(json: Data) -> Bool {
        guard let string = String(data: json, encoding: .utf8) else {
            return false
        }
        engine_use_resources(engine, string)
        return true
    }
}

extension Data {
    public mutating func appendBytes(fromData data: Data) {
        var bytes = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &bytes, count: data.count)
        self.append(bytes, count: bytes.count)
    }
    
    public func getBytes() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: self.count)
        self.copyBytes(to: &bytes, count: self.count)
        return bytes
    }
    
    public var int8Array: [Int8] {
        return self.map { Int8(bitPattern: $0) }
    }
}
