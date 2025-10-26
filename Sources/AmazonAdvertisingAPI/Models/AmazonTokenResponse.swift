//
//  AmazonTokenResponse.swift
//  AmazonAdvertisingAPI
//
//  Model for OAuth token response from Amazon Advertising API
//

import Foundation

/// Response from Amazon OAuth token endpoint
public struct AmazonTokenResponse: Codable, Sendable {
    /// Access token for API requests
    public let accessToken: String

    /// Token type (always "bearer" for OAuth 2.0)
    public let tokenType: String

    /// Time in seconds until the access token expires
    public let expiresIn: Int

    /// Refresh token for obtaining new access tokens
    public let refreshToken: String?

    /// Space-separated list of granted scopes
    public let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }

    public init(
        accessToken: String,
        tokenType: String,
        expiresIn: Int,
        refreshToken: String? = nil,
        scope: String? = nil
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.scope = scope
    }

    /// Calculate the expiry date based on the current time
    public func expiryDate() -> Date {
        Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}

/// OAuth error response from Amazon
public struct AmazonOAuthError: Codable, LocalizedError, Sendable {
    /// Error code (e.g., "invalid_grant", "invalid_client")
    public let error: String

    /// Human-readable error description
    public let errorDetail: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDetail = "error_description"
    }

    public init(error: String, errorDetail: String? = nil) {
        self.error = error
        self.errorDetail = errorDetail
    }

    public var errorDescription: String? {
        errorDetail ?? error
    }
}
