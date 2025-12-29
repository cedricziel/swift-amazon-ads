//
//  Extensions.swift
//  AmazonAdsAccounts
//
//  Public API surface for the generated Accounts API client
//

import Foundation
import AmazonAdsCore
import OpenAPIRuntime
import OpenAPIURLSession

// MARK: - Module Info

/// Module version information
public enum AmazonAdsAccountsInfo {
    /// Module version
    public static let moduleVersion = "1.0.0"
}

// MARK: - Type Aliases for Discoverability

/// Amazon Ads Accounts API Client
///
/// Use ``AccountsClient/make(region:tokenProvider:clientId:)`` to create an authenticated client.
///
/// Example:
/// ```swift
/// let client = AccountsClient.make(
///     region: .northAmerica,
///     tokenProvider: { try await authService.getAccessToken() },
///     clientId: "your-client-id"
/// )
///
/// let profiles = try await client.listProfiles(...)
/// ```
public typealias AccountsClient = Client

/// Accounts API Types namespace
public typealias AccountsTypes = Components.Schemas

/// Accounts API Operations namespace
public typealias AccountsOperations = Operations

// MARK: - Client Factory

extension Client {
    /// Creates an Accounts API client configured for the specified Amazon region
    ///
    /// Note: The Accounts API typically doesn't require a profile ID since it's used
    /// to discover available profiles.
    /// - Parameters:
    ///   - region: The Amazon region to connect to
    ///   - tokenProvider: A closure that provides the current OAuth access token
    ///   - clientId: Your Amazon Advertising API Client ID
    /// - Returns: A configured Accounts API client
    public static func make(
        region: AmazonRegion,
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String
    ) -> Client {
        let transport = AuthenticatedTransport(
            tokenProvider: tokenProvider,
            clientId: clientId,
            profileId: nil
        )

        return Client(
            serverURL: region.advertisingAPIBaseURL,
            transport: transport
        )
    }
}

// MARK: - Common Type Aliases

/// Advertising Account model
public typealias AdsAccount = Components.Schemas.AdsAccount

/// Advertising Account with metadata
public typealias AdsAccountWithMetaData = Components.Schemas.AdsAccountWithMetaData
