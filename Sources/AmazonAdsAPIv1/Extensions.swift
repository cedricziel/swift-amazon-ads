//
//  Extensions.swift
//  AmazonAdsAPIv1
//
//  Public API surface for the generated Amazon Ads unified API v1 client
//

import Foundation
import AmazonAdsCore
import OpenAPIRuntime
import OpenAPIURLSession

// MARK: - Module Info

/// Module version information
public enum AmazonAdsAPIv1Info {
    /// The API version this module targets
    public static let apiVersion = "v1"

    /// Module version
    public static let moduleVersion = "1.0.0"
}

// MARK: - Type Aliases for Discoverability

/// Amazon Ads unified API v1 Client
///
/// Use ``AmazonAdsClient/make(region:tokenProvider:clientId:profileId:)`` to create an authenticated client.
///
/// Example:
/// ```swift
/// let client = AmazonAdsClient.make(
///     region: .northAmerica,
///     tokenProvider: { try await authService.getAccessToken() },
///     clientId: "your-client-id",
///     profileId: "your-profile-id"
/// )
///
/// let campaigns = try await client.listCampaigns(...)
/// ```
public typealias AmazonAdsClient = Client

/// Amazon Ads API v1 Types namespace
public typealias AmazonAdsTypes = Components.Schemas

/// Amazon Ads API v1 Operations namespace
public typealias AmazonAdsOperations = Operations

// MARK: - Client Factory

extension Client {
    /// Creates an Amazon Ads API v1 client configured for the specified region
    /// - Parameters:
    ///   - region: The Amazon region to connect to
    ///   - tokenProvider: A closure that provides the current OAuth access token
    ///   - clientId: Your Amazon Advertising API Client ID
    ///   - profileId: The profile ID to scope requests to (required for most operations)
    /// - Returns: A configured Amazon Ads API v1 client
    public static func make(
        region: AmazonRegion,
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil
    ) -> Client {
        let transport = AuthenticatedTransport(
            tokenProvider: tokenProvider,
            clientId: clientId,
            profileId: profileId
        )

        return Client(
            serverURL: region.advertisingAPIBaseURL,
            transport: transport
        )
    }

    /// Creates an Amazon Ads API v1 client with a dynamic profile transport
    ///
    /// Use this when you need to switch profiles without recreating the client.
    /// - Parameters:
    ///   - region: The Amazon region to connect to
    ///   - tokenProvider: A closure that provides the current OAuth access token
    ///   - clientId: Your Amazon Advertising API Client ID
    ///   - profileId: Optional initial profile ID
    /// - Returns: A tuple of the configured client and the transport (for changing profile)
    public static func makeWithDynamicProfile(
        region: AmazonRegion,
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil
    ) -> (client: Client, transport: DynamicProfileTransport) {
        let transport = DynamicProfileTransport(
            tokenProvider: tokenProvider,
            clientId: clientId,
            profileId: profileId
        )

        let client = Client(
            serverURL: region.advertisingAPIBaseURL,
            transport: transport
        )

        return (client, transport)
    }
}

// MARK: - Common Type Aliases

/// Ad model from unified API
public typealias Ad = Components.Schemas.Ad

/// Campaign model from unified API
public typealias Campaign = Components.Schemas.Campaign

/// Ad Group model from unified API
public typealias AdGroup = Components.Schemas.AdGroup
