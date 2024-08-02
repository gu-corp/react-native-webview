//
//  SequenceExtension.swift
//  Greetings
//
//  Created by Dinh Minh Ngoc on 2024/07/09.
//

import Foundation

@available(iOS 13.0.0, *)
public extension Sequence {
    func asyncConcurrentMap<T>(_ transform: @escaping (Element) async throws -> T) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: T.self) { group in
            for element in self {
                group.addTask { try await transform(element) }
            }

            var results = [T]()
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
      var results = [T]()
      for element in self {
        try await results.append(transform(element))
      }
      return results
    }
    
    func asyncConcurrentCompactMap<T>(_ transform: @escaping (Element) async throws -> T?) async rethrows -> [T] {
      try await withThrowingTaskGroup(of: T?.self) { group in
        for element in self {
          group.addTask {
            try await transform(element)
          }
        }

        var results = [T]()
        for try await result in group {
          if let result = result {
            results.append(result)
          }
        }
        return results
      }
    }
    
    func asyncConcurrentForEach(_ operation: @escaping (Element) async throws -> Void) async rethrows {
      await withThrowingTaskGroup(of: Void.self) { group in
        for element in self {
          group.addTask { try await operation(element) }
        }
      }
    }
    
    func asyncFilter(_ isIncluded: (Element) async throws -> Bool) async rethrows -> [Element] {
      var results = [Element]()
      for element in self {
        if try await isIncluded(element) {
          results.append(element)
        }
      }
      return results
    }
}
