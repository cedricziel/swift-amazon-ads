//
//  MockTokenStorage.swift
//  AmazonAdvertisingAPITests
//
//  Mock token storage for testing
//

import Foundation
@testable import AmazonAdvertisingAPI

/// Mock token storage for testing
public actor MockTokenStorage: TokenStorageProtocol {
    private var storage: [String: String] = [:]
    public var saveCalled = false
    public var retrieveCalled = false
    public var deleteCalled = false

    public init() {}

    public func save(_ value: String, for key: String, region: AmazonRegion) async throws {
        saveCalled = true
        let storageKey = makeKey(key: key, region: region)
        storage[storageKey] = value
    }

    public func retrieve(for key: String, region: AmazonRegion) async throws -> String {
        retrieveCalled = true
        let storageKey = makeKey(key: key, region: region)
        guard let value = storage[storageKey] else {
            throw TokenStorageError.notFound
        }
        return value
    }

    public func exists(for key: String, region: AmazonRegion) async -> Bool {
        let storageKey = makeKey(key: key, region: region)
        return storage[storageKey] != nil
    }

    public func delete(for key: String, region: AmazonRegion) async throws {
        deleteCalled = true
        let storageKey = makeKey(key: key, region: region)
        storage.removeValue(forKey: storageKey)
    }

    public func deleteAll(for region: AmazonRegion) async throws {
        deleteCalled = true
        let prefix = "\(region.rawValue)_"
        let keysToDelete = storage.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToDelete {
            storage.removeValue(forKey: key)
        }
    }

    // MARK: - Test Helpers

    public func clearAll() {
        storage.removeAll()
        saveCalled = false
        retrieveCalled = false
        deleteCalled = false
    }

    public func allKeys() -> [String] {
        Array(storage.keys)
    }

    // MARK: - Private

    private func makeKey(key: String, region: AmazonRegion) -> String {
        "\(region.rawValue)_\(key)"
    }
}
