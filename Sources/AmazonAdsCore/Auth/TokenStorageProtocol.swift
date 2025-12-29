//
//  TokenStorageProtocol.swift
//  AmazonAdsCore
//
//  Protocol for storing and retrieving OAuth tokens and credentials
//

import Foundation

/// Protocol for secure storage of OAuth tokens and credentials
public protocol TokenStorageProtocol: Sendable {
    /// Save a value for a specific key and region
    func save(_ value: String, for key: String, region: AmazonRegion) async throws

    /// Retrieve a value for a specific key and region
    func retrieve(for key: String, region: AmazonRegion) async throws -> String

    /// Check if a value exists for a specific key and region
    func exists(for key: String, region: AmazonRegion) async -> Bool

    /// Delete a value for a specific key and region
    func delete(for key: String, region: AmazonRegion) async throws

    /// Delete all values for a specific region
    func deleteAll(for region: AmazonRegion) async throws
}

/// Standard keys for token storage
public enum TokenStorageKey {
    /// Access token key
    public static let accessToken = "amazon_access_token"

    /// Refresh token key
    public static let refreshToken = "amazon_refresh_token"

    /// Token expiry key
    public static let tokenExpiry = "amazon_token_expiry"

    /// Profile ID key
    public static let profileId = "amazon_profile_id"

    /// Client ID key (not region-specific)
    public static let clientId = "amazon_client_id"

    /// Client secret key (not region-specific)
    public static let clientSecret = "amazon_client_secret"
}

/// Errors that can occur during storage operations
public enum TokenStorageError: LocalizedError {
    case notFound
    case invalidData
    case storageError(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Value not found in storage"
        case .invalidData:
            return "Invalid data format"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}
