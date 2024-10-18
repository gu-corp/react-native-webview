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
    
    init(rules: String = "") {
        engine = engine_create(rules)
        setDomainResolver()
    }
    deinit { engine_destroy(engine) }
    
    
    private func setDomainResolver() {
        let resolver: C_DomainResolverCallback = { host, start, end in
            //self.swiftDomainResolver(host: host!, start: start!, end: end!)
            let hostString = String(cString: host!)

            // Use DomainParser to get the domain
            if let domainParser = try? DomainParser(),
               let parsedDomain = domainParser.parse(host: hostString)?.domain {
                if let range = hostString.range(of: parsedDomain) {
                    let startIndex = hostString.distance(from: hostString.startIndex, to: range.lowerBound)
                    let endIndex = hostString.distance(from: hostString.startIndex, to: range.upperBound)
                    start!.pointee = UInt32(startIndex)
                    end!.pointee = UInt32(endIndex)
                } else {
                    start!.pointee = 0
                    end!.pointee = UInt32(hostString.count)
                }
            } else {
                start!.pointee = 0
                end!.pointee = UInt32(hostString.count)
            }
        }
        _ = set_domain_resolver(resolver)
    }
    
    func swiftDomainResolver(host: UnsafePointer<CChar>, start: UnsafeMutablePointer<UInt32>, end: UnsafeMutablePointer<UInt32>) {
        let hostString = String(cString: host)

        // Use DomainParser to get the domain
        if let domainParser = try? DomainParser(),
           let parsedDomain = domainParser.parse(host: hostString)?.domain {
            if let range = hostString.range(of: parsedDomain) {
                let startIndex = hostString.distance(from: hostString.startIndex, to: range.lowerBound)
                let endIndex = hostString.distance(from: hostString.startIndex, to: range.upperBound)
                start.pointee = UInt32(startIndex)
                end.pointee = UInt32(endIndex)
            } else {
                start.pointee = 0
                end.pointee = UInt32(hostString.count)
            }
        } else {
            start.pointee = 0
            end.pointee = UInt32(hostString.count)
        }
    }
    
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
    
    func stylesheetForCosmeticRulesIncluding(classes: [String], ids: [String], exceptions: [String]) throws -> [String] {
        // Convert Swift arrays to C strings
        let cClasses = classes.map { strdup($0) }
        let cIds = ids.map { strdup($0) }
        let cExceptions = exceptions.map { strdup($0) }

        // Convert arrays to UnsafePointer<UnsafePointer<CChar>?>
        let cClassesPointer = UnsafePointer(cClasses.map { UnsafePointer($0) })
        let cIdsPointer = UnsafePointer(cIds.map { UnsafePointer($0) })
        let cExceptionsPointer = UnsafePointer(cExceptions.map { UnsafePointer($0) })
        
        guard let selectorsJSON = engine_hidden_class_id_selectors(engine, cClassesPointer, cClasses.count, cIdsPointer, cIds.count, cExceptionsPointer, cExceptions.count) else {
            return []
        }
        
        guard let data = String(cString: selectorsJSON).data(using: .utf8) else {
          return []
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([String].self, from: data)
    }
    
    func cosmeticFilterModel(forFrameURL frameURL: URL) throws -> CosmeticFilterModel? {
        guard let rules = engine_url_cosmetic_resources(engine, frameURL.absoluteString) else {
            return nil
        }
        guard let data = String(cString: rules).data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(CosmeticFilterModel.self, from: data)
    }
    
//    static func contentBlockerRules(fromFilterSet: String) -> String {
//        // Convert the Swift String to a C string
//        let cRules = fromFilterSet.cString(using: .utf8)
//
//        // Create a pointer for the truncated boolean
//        var cTruncated: Bool = false
//
//        // Call the C function
//        if let cContentBlockingJSON = convert_rules_to_content_blocking(cRules, &cTruncated) {
//            // Convert the C string back to a Swift String
//            let result = String(cString: cContentBlockingJSON)
//
//            // Free the allocated C string
//            c_char_buffer_destroy(cContentBlockingJSON)
//
//            return result
//        } else {
//            // Handle the case where the conversion fails (return an empty string or handle error appropriately)
//            return ""
//        }
//    }
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
