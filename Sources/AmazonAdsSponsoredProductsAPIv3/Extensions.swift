//
//  Extensions.swift
//  AmazonAdsSponsoredProductsAPIv3
//
//  Public API surface for the generated Sponsored Products v3 client
//

import Foundation
import AmazonAdsCore
import OpenAPIRuntime
import OpenAPIURLSession

// MARK: - Module Info

/// Module version information
public enum AmazonAdsSponsoredProductsAPIv3Info {
    /// The API version this module targets
    public static let apiVersion = "v3"

    /// Module version
    public static let moduleVersion = "1.0.0"
}

// MARK: - Type Aliases for Discoverability

/// Sponsored Products v3 API Client
///
/// Use ``SponsoredProductsClient/make(region:tokenProvider:clientId:profileId:)`` to create an authenticated client.
///
/// Example:
/// ```swift
/// let client = SponsoredProductsClient.make(
///     region: .northAmerica,
///     tokenProvider: { try await authService.getAccessToken() },
///     clientId: "your-client-id",
///     profileId: "your-profile-id"
/// )
///
/// let response = try await client.listSponsoredProductsCampaigns(...)
/// ```
public typealias SponsoredProductsClient = Client

/// Sponsored Products v3 API Types namespace
public typealias SponsoredProductsTypes = Components.Schemas

/// Sponsored Products v3 API Operations namespace
public typealias SponsoredProductsOperations = Operations

// MARK: - Client Factory

extension Client {
    /// Creates a Sponsored Products v3 client configured for the specified Amazon region
    /// - Parameters:
    ///   - region: The Amazon region to connect to
    ///   - tokenProvider: A closure that provides the current OAuth access token
    ///   - clientId: Your Amazon Advertising API Client ID
    ///   - profileId: The profile ID to scope requests to (required for most operations)
    ///   - logLevel: Optional log level for request/response logging (default: none)
    /// - Returns: A configured Sponsored Products v3 client
    public static func make(
        region: AmazonRegion,
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil,
        logLevel: LogLevel = .none
    ) -> Client {
        let transport = AuthenticatedTransport(
            tokenProvider: tokenProvider,
            clientId: clientId,
            profileId: profileId
        )

        var middlewares: [any ClientMiddleware] = []

        // Add logging middleware if enabled
        if logLevel > .none {
            middlewares.append(LoggingMiddleware(logLevel: logLevel))
        }

        // Add content type normalizing middleware (handles Amazon returning application/json instead of vendor types)
        middlewares.append(ContentTypeNormalizingMiddleware())

        // Add error normalizing middleware (handles Amazon returning text/plain for errors)
        middlewares.append(ErrorNormalizingMiddleware())

        return Client(
            serverURL: region.advertisingAPIBaseURL,
            transport: transport,
            middlewares: middlewares
        )
    }

    /// Creates a Sponsored Products v3 client with a dynamic profile transport
    ///
    /// Use this when you need to switch profiles without recreating the client.
    /// - Parameters:
    ///   - region: The Amazon region to connect to
    ///   - tokenProvider: A closure that provides the current OAuth access token
    ///   - clientId: Your Amazon Advertising API Client ID
    ///   - profileId: Optional initial profile ID
    ///   - logLevel: Optional log level for request/response logging (default: none)
    /// - Returns: A tuple of the configured client and the transport (for changing profile)
    public static func makeWithDynamicProfile(
        region: AmazonRegion,
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil,
        logLevel: LogLevel = .none
    ) -> (client: Client, transport: DynamicProfileTransport) {
        let transport = DynamicProfileTransport(
            tokenProvider: tokenProvider,
            clientId: clientId,
            profileId: profileId
        )

        var middlewares: [any ClientMiddleware] = []

        // Add logging middleware if enabled
        if logLevel > .none {
            middlewares.append(LoggingMiddleware(logLevel: logLevel))
        }

        // Add content type normalizing middleware (handles Amazon returning application/json instead of vendor types)
        middlewares.append(ContentTypeNormalizingMiddleware())

        // Add error normalizing middleware (handles Amazon returning text/plain for errors)
        middlewares.append(ErrorNormalizingMiddleware())

        let client = Client(
            serverURL: region.advertisingAPIBaseURL,
            transport: transport,
            middlewares: middlewares
        )

        return (client, transport)
    }
}

// MARK: - Common Type Aliases

/// Campaign model from Sponsored Products v3 API
public typealias SPCampaign = Components.Schemas.SponsoredProductsCampaign

/// Ad Group model from Sponsored Products v3 API
public typealias SPAdGroup = Components.Schemas.SponsoredProductsAdGroup

/// Keyword model from Sponsored Products v3 API
public typealias SPKeyword = Components.Schemas.SponsoredProductsKeyword

/// Product Ad model from Sponsored Products v3 API
public typealias SPProductAd = Components.Schemas.SponsoredProductsProductAd

/// Target model from Sponsored Products v3 API
public typealias SPTarget = Components.Schemas.SponsoredProductsTargetingClause

/// Budget model from Sponsored Products v3 API
public typealias SPBudget = Components.Schemas.SponsoredProductsBudget
