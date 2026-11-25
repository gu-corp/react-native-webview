import Foundation

/// A wrapper around libadblock (adblock-rust 0.13, `lib.h` in `libadblock.xcframework`,
/// built from gu-corp/adblock-rust-jni).
///
/// Not thread-safe: use one engine from one serial queue at a time (`CachedAdBlockEngine`).
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
    }
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

        // Redirects and rewritten URLs are not asked for: the request blocking script can only block.
        engine_match(engine, requestURL.absoluteString, requestHost,
                     sourceHost, isThirdParty, resourceType.rawValue,
                     &didMatchRule, &didMatchException,
                     &didMatchImportant,
                     nil, nil)
        return didMatchRule
    }

    private func useResources(fromFileURL fileURL: URL) throws {
        if let json = try Self.validateJSON(Data(contentsOf: fileURL)) {
            if !engine_use_resources(engine, json) {
                throw CompileError.invalidResourceJSON
            }
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

    @discardableResult func set(json: Data) -> Bool {
        guard let string = String(data: json, encoding: .utf8) else {
            return false
        }
        return engine_use_resources(engine, string)
    }

    func stylesheetForCosmeticRulesIncluding(classes: [String], ids: [String], exceptions: [String]) throws -> [String] {
        let cClasses: [UnsafePointer<CChar>?] = classes.map { UnsafePointer(strdup($0)) }
        let cIds: [UnsafePointer<CChar>?] = ids.map { UnsafePointer(strdup($0)) }
        let cExceptions: [UnsafePointer<CChar>?] = exceptions.map { UnsafePointer(strdup($0)) }
        defer {
            (cClasses + cIds + cExceptions).forEach { free(UnsafeMutablePointer(mutating: $0)) }
        }

        let selectorsJSON = cClasses.withUnsafeBufferPointer { classesBuffer in
            cIds.withUnsafeBufferPointer { idsBuffer in
                cExceptions.withUnsafeBufferPointer { exceptionsBuffer in
                    engine_hidden_class_id_selectors(
                        engine,
                        classesBuffer.baseAddress, classesBuffer.count,
                        idsBuffer.baseAddress, idsBuffer.count,
                        exceptionsBuffer.baseAddress, exceptionsBuffer.count
                    )
                }
            }
        }
        guard let selectorsJSON else {
            return []
        }
        defer { c_char_buffer_destroy(selectorsJSON) }

        guard let data = String(cString: selectorsJSON).data(using: .utf8) else {
          return []
        }

        return try JSONDecoder().decode([String].self, from: data)
    }

    func cosmeticFilterModel(forFrameURL frameURL: URL) throws -> CosmeticFilterModel? {
        guard let rules = engine_url_cosmetic_resources(engine, frameURL.absoluteString) else {
            return nil
        }
        defer { c_char_buffer_destroy(rules) }
        guard let data = String(cString: rules).data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(CosmeticFilterModel.self, from: data)
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
