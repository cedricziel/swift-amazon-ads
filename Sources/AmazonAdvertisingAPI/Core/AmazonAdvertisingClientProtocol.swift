//
//  AmazonAdvertisingClientProtocol.swift
//  AmazonAdvertisingAPI
//
//  Protocol for Amazon Advertising API client
//

import Foundation

/// Protocol defining Amazon Advertising API operations
public protocol AmazonAdvertisingClientProtocol: Sendable {
    /// Initiate OAuth authorization flow for a specific region
    /// This method starts a local OAuth server, generates the authorization URL, and waits for the callback
    /// Note: The caller is responsible for opening the returned URL in a browser
    /// - Parameter region: The Amazon region to authorize
    /// - Returns: The authorization URL that should be opened in a browser
    func initiateAuthorization(for region: AmazonRegion) async throws -> URL

    /// Cancel ongoing authorization for a region
    /// - Parameter region: The Amazon region
    func cancelAuthorization(for region: AmazonRegion) async

    /// Refresh access token using refresh token
    /// - Parameter region: The Amazon region
    func refreshToken(for region: AmazonRegion) async throws

    /// Get valid access token for a region, refreshing if necessary
    /// - Parameter region: The Amazon region
    /// - Returns: Valid access token
    func getAccessToken(for region: AmazonRegion) async throws -> String

    /// Fetch advertising profiles for a region (regular Sponsored Products accounts)
    /// - Parameter region: The Amazon region
    /// - Returns: Array of advertising profiles
    func fetchProfiles(for region: AmazonRegion) async throws -> [AmazonProfile]

    /// Fetch manager accounts for a region (Merch By Amazon accounts)
    /// - Parameter region: The Amazon region
    /// - Returns: Manager accounts response
    func fetchManagerAccounts(for region: AmazonRegion) async throws -> AmazonManagerAccountsResponse

    /// Verify connection by making a test API call
    /// Returns true if connection is valid, false otherwise
    /// - Parameter region: The Amazon region to verify
    /// - Returns: True if connection is valid
    func verifyConnection(for region: AmazonRegion) async throws -> Bool

    /// Check if authenticated for a specific region
    /// - Parameter region: The Amazon region to check
    /// - Returns: True if valid tokens exist
    func isAuthenticated(for region: AmazonRegion) async -> Bool

    /// Logout and clear stored tokens for a region
    /// - Parameter region: The Amazon region to logout from
    func logout(for region: AmazonRegion) async throws
}
