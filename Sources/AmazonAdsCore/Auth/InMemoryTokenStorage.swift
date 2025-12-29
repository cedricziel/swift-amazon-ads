//
//  InMemoryTokenStorage.swift
//  AmazonAdsCore
//
//  In-memory implementation of TokenStorageProtocol for testing and development
//

import Foundation

/// In-memory token storage implementation
/// Note: This storage is not persistent and will be cleared when the app terminates
/// For production use, implement your own storage using Keychain, UserDefaults, or other secure storage
public actor InMemoryTokenStorage: TokenStorageProtocol {
    private var storage: [String: String] = [:]

    public init() {}

    public func save(_ value: String, for key: String, region: AmazonRegion) throws {
        let storageKey = makeKey(key: key, region: region)
        storage[storageKey] = value
    }

    public func retrieve(for key: String, region: AmazonRegion) throws -> String {
        let storageKey = makeKey(key: key, region: region)
        guard let value = storage[storageKey] else {
            throw TokenStorageError.notFound
        }
        return value
    }

    public func exists(for key: String, region: AmazonRegion) -> Bool {
        let storageKey = makeKey(key: key, region: region)
        return storage[storageKey] != nil
    }

    public func delete(for key: String, region: AmazonRegion) throws {
        let storageKey = makeKey(key: key, region: region)
        storage.removeValue(forKey: storageKey)
    }

    public func deleteAll(for region: AmazonRegion) throws {
        let prefix = "\(region.rawValue)_"
        let keysToDelete = storage.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToDelete {
            storage.removeValue(forKey: key)
        }
    }

    // MARK: - Helper

    private func makeKey(key: String, region: AmazonRegion) -> String {
        "\(region.rawValue)_\(key)"
    }

    // MARK: - Testing Helpers

    /// Clear all storage (useful for testing)
    public func clearAll() {
        storage.removeAll()
    }

    /// Get all stored keys (useful for debugging)
    public func allKeys() -> [String] {
        Array(storage.keys)
    }
}
