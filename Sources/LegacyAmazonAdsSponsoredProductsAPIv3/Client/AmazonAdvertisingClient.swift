//
//  AmazonAdvertisingClient.swift
//  LegacyAmazonAdsSponsoredProductsAPIv3
//
//  Main client for Amazon Advertising API operations
//

import Foundation
import CryptoKit
import AmazonAdsCore

// MARK: - Sponsored Products V3 API Media Types

/// Versioned media types for Sponsored Products V3 API
/// The V3 API requires specific Content-Type and Accept headers for each entity type
public enum SPMediaType {
    case campaign
    case adGroup
    case productAd
    case keyword
    case target
    case campaignNegativeKeyword
    case campaignNegativeTarget

    /// The Content-Type/Accept header value for this entity type
    public var headerValue: String {
        switch self {
        case .campaign:
            return "application/vnd.spCampaign.v3+json"
        case .adGroup:
            return "application/vnd.spAdGroup.v3+json"
        case .productAd:
            return "application/vnd.spProductAd.v3+json"
        case .keyword:
            return "application/vnd.spKeyword.v3+json"
        case .target:
            return "application/vnd.spTargetingClause.v3+json"
        case .campaignNegativeKeyword:
            return "application/vnd.spCampaignNegativeKeyword.v3+json"
        case .campaignNegativeTarget:
            return "application/vnd.spCampaignNegativeTargetingClause.v3+json"
        }
    }
}

/// Main client for interacting with Amazon Advertising API
public actor AmazonAdvertisingClient: AmazonAdvertisingClientProtocol {
    private let clientId: String
    private let clientSecret: String
    private let storage: TokenStorageProtocol
    private let htmlProvider: OAuthHTMLProvider
    private let urlSession: URLSession

    // OAuth servers - one per region for concurrent auth attempts
    private var oauthServers: [AmazonRegion: LocalOAuthServer] = [:]

    // OAuth scopes for Login with Amazon + Advertising API
    // profile: Basic user profile from LWA
    // advertising::campaign_management: Access to manage advertising campaigns
    private let scopes = ["profile", "advertising::campaign_management"]

    /// Initialize the client
    /// - Parameters:
    ///   - clientId: Amazon Advertising API client ID
    ///   - clientSecret: Amazon Advertising API client secret
    ///   - storage: Storage implementation for tokens and credentials
    ///   - htmlProvider: HTML provider for OAuth callback pages
    ///   - urlSession: URL session for HTTP requests (defaults to .shared)
    public init(
        clientId: String,
        clientSecret: String,
        storage: TokenStorageProtocol,
        htmlProvider: OAuthHTMLProvider = DefaultOAuthHTMLProvider(),
        urlSession: URLSession = .shared
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.storage = storage
        self.htmlProvider = htmlProvider
        self.urlSession = urlSession
    }

    // MARK: - OAuth Authorization

    public func initiateAuthorization(for region: AmazonRegion) async throws -> URL {
        // Clean up any existing server for this region
        await cancelAuthorization(for: region)

        // Create and start local OAuth server on fixed port
        let fixedPort: UInt16 = 8765
        let server = LocalOAuthServer(port: fixedPort, htmlProvider: htmlProvider)
        let port = try await server.start()
        oauthServers[region] = server

        // Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = try generateCodeChallenge(from: codeVerifier)

        // Build redirect URI
        let redirectURI = "http://localhost:\(port)/callback"

        // Build authorization URL
        var components = URLComponents(url: region.authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: UUID().uuidString), // CSRF protection
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            throw AmazonAdvertisingError.invalidURL
        }

        // Wait for OAuth callback in background
        Task {
            do {
                let authorizationCode = try await withTimeout(seconds: 300) {
                    try await server.waitForCallback()
                }

                // Exchange code for tokens
                try await exchangeCodeForTokens(
                    code: authorizationCode,
                    codeVerifier: codeVerifier,
                    redirectURI: redirectURI,
                    region: region
                )

                // Clean up server
                await cancelAuthorization(for: region)
            } catch {
                await cancelAuthorization(for: region)
                throw error
            }
        }

        return authURL
    }

    public func cancelAuthorization(for region: AmazonRegion) async {
        if let server = oauthServers[region] {
            await server.stop()
            oauthServers.removeValue(forKey: region)
        }
    }

    // MARK: - Token Management

    public func refreshToken(for region: AmazonRegion) async throws {
        print("[Token] Refreshing access token for region \(region)...")

        // Retrieve refresh token
        guard let refreshToken = try? await storage.retrieve(
            for: TokenStorageKey.refreshToken,
            region: region
        ) else {
            print("[Token] ERROR: No refresh token available for region \(region)")
            throw AmazonAdvertisingError.noRefreshToken
        }

        // Prepare token refresh request
        var request = URLRequest(url: region.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: String.Encoding.utf8)

        // Make request
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let tokenResponse = try JSONDecoder().decode(AmazonTokenResponse.self, from: data)
            try await saveTokens(tokenResponse, for: region)
        } else {
            // Try to decode error
            if let errorResponse = try? JSONDecoder().decode(AmazonOAuthError.self, from: data) {
                throw AmazonAdvertisingError.oauthError(errorResponse.error, errorResponse.errorDetail)
            }
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func getAccessToken(for region: AmazonRegion) async throws -> String {
        // Check if token exists and is not expired
        if let expiryString = try? await storage.retrieve(
            for: TokenStorageKey.tokenExpiry,
            region: region
        ),
           let expiryDate = ISO8601DateFormatter().date(from: expiryString) {
            let timeUntilExpiry = expiryDate.timeIntervalSinceNow

            // If token expires in less than 5 minutes, refresh it
            if timeUntilExpiry < 300 {
                try await refreshToken(for: region)
            }
        } else {
            // No expiry date, try to refresh
            try await refreshToken(for: region)
        }

        // Retrieve access token
        guard let accessToken = try? await storage.retrieve(
            for: TokenStorageKey.accessToken,
            region: region
        ) else {
            throw AmazonAdvertisingError.noAccessToken
        }

        return accessToken
    }

    // MARK: - API Operations

    public func fetchProfiles(for region: AmazonRegion) async throws -> [AmazonProfile] {
        let accessToken = try await getAccessToken(for: region)

        let profilesURL = region.advertisingAPIBaseURL.appendingPathComponent("/v2/profiles")

        var request = URLRequest(url: profilesURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let profiles = try JSONDecoder().decode([AmazonProfile].self, from: data)
            return profiles
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode, responseBody: nil)
        }
    }

    public func fetchManagerAccounts(for region: AmazonRegion) async throws -> AmazonManagerAccountsResponse {
        let accessToken = try await getAccessToken(for: region)

        let managerAccountsURL = region.advertisingAPIBaseURL.appendingPathComponent("/managerAccounts")

        var request = URLRequest(url: managerAccountsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let managerAccounts = try JSONDecoder().decode(AmazonManagerAccountsResponse.self, from: data)
            return managerAccounts
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode, responseBody: nil)
        }
    }

    public func verifyConnection(for region: AmazonRegion) async throws -> Bool {
        // Try Manager Accounts endpoint first (for Merch By Amazon accounts)
        do {
            let managerAccounts = try await fetchManagerAccounts(for: region)
            if !managerAccounts.managerAccounts.isEmpty {
                return true
            }
        } catch {
            // If manager accounts fails, try regular profiles
        }

        // Fallback to Profiles endpoint (for regular Sponsored Products accounts)
        do {
            let profiles = try await fetchProfiles(for: region)
            return !profiles.isEmpty
        } catch {
            return false
        }
    }

    public func isAuthenticated(for region: AmazonRegion) async -> Bool {
        // Check if both access and refresh tokens exist
        let hasAccessToken = await storage.exists(for: TokenStorageKey.accessToken, region: region)
        let hasRefreshToken = await storage.exists(for: TokenStorageKey.refreshToken, region: region)
        return hasAccessToken && hasRefreshToken
    }

    public func logout(for region: AmazonRegion) async throws {
        // Cancel any ongoing authorization
        await cancelAuthorization(for: region)

        // Delete all tokens for this region
        do {
            try await storage.deleteAll(for: region)
        } catch {
            throw AmazonAdvertisingError.storageError(error)
        }
    }

    // MARK: - Private Helpers

    private func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        redirectURI: String,
        region: AmazonRegion
    ) async throws {
        // Prepare token request
        var request = URLRequest(url: region.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientId,
            "client_secret": clientSecret,
            "code_verifier": codeVerifier
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        // Make request
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let tokenResponse = try JSONDecoder().decode(AmazonTokenResponse.self, from: data)
            try await saveTokens(tokenResponse, for: region)
        } else {
            // Try to decode error
            if let errorResponse = try? JSONDecoder().decode(AmazonOAuthError.self, from: data) {
                throw AmazonAdvertisingError.oauthError(errorResponse.error, errorResponse.errorDetail)
            }
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode, responseBody: nil)
        }
    }

    private func saveTokens(_ response: AmazonTokenResponse, for region: AmazonRegion) async throws {
        do {
            // Save access token
            try await storage.save(
                response.accessToken,
                for: TokenStorageKey.accessToken,
                region: region
            )

            // Save refresh token (if present)
            if let refreshToken = response.refreshToken {
                try await storage.save(
                    refreshToken,
                    for: TokenStorageKey.refreshToken,
                    region: region
                )
            }

            // Save expiry date
            let expiryDate = response.expiryDate()
            let expiryString = ISO8601DateFormatter().string(from: expiryDate)
            try await storage.save(
                expiryString,
                for: TokenStorageKey.tokenExpiry,
                region: region
            )
        } catch {
            throw AmazonAdvertisingError.storageError(error)
        }
    }

    private func parseAPIError(from data: Data) throws -> AmazonAPIErrorResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AmazonAPIErrorResponse.self, from: data)
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        // Generate random 43-128 character string
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) throws -> String {
        guard let data = verifier.data(using: .utf8) else {
            throw AmazonAdvertisingError.pkceGenerationFailed
        }

        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Timeout Helper

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AmazonAdvertisingError.timeout
            }

            // Return first result (either success or timeout)
            guard let result = try await group.next() else {
                throw AmazonAdvertisingError.timeout
            }

            // Cancel the other task
            group.cancelAll()

            return result
        }
    }

    // MARK: - Campaign Management

    public func listCampaigns(
        profileId: String,
        region: AmazonRegion,
        stateFilter: [CampaignState]?
    ) async throws -> [SponsoredProductsCampaign] {
        let accessToken = try await getAccessToken(for: region)
        // V3 API uses POST /sp/campaigns/list
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/campaigns/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        // V3 API requires versioned Content-Type and Accept headers
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Accept")

        // V3 API uses request body for filters instead of query parameters
        // Even for list requests, we need to send a body (can be empty object)
        var requestBody: [String: Any] = [:]
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            requestBody["stateFilter"] = [
                "include": stateFilter.map(\.rawValue)
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            // V3 API returns a response object with campaigns array
            let listResponse = try decoder.decode(SPCampaignListResponse.self, from: data)
            return listResponse.campaigns
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func getCampaign(
        campaignId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsCampaign {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/campaigns/\(campaignId)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsCampaign.self, from: data)
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func createCampaign(
        campaign: SponsoredProductsCampaign,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsCampaign {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/campaigns")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects array of campaigns
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(SPCampaignCreateRequest(campaigns: [campaign]))

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        // V3 API returns 207 Multi-Status for batch operations
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPCampaignBatchResponse.self, from: data)
            if let successItem = batchResponse.campaigns.success.first {
                return successItem.campaign
            } else if let errorItem = batchResponse.campaigns.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.map(\.message).joined(separator: ", "))
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func updateCampaign(
        campaign: SponsoredProductsCampaign,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsCampaign {
        guard campaign.campaignId != nil else {
            throw AmazonAdvertisingError.invalidRequest("Campaign ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/campaigns")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects array of campaigns
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(SPCampaignUpdateRequest(campaigns: [campaign]))

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPCampaignBatchResponse.self, from: data)
            if let successItem = batchResponse.campaigns.success.first {
                return successItem.campaign
            } else if let errorItem = batchResponse.campaigns.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.map(\.message).joined(separator: ", "))
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func archiveCampaign(
        campaignId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        // V3 API uses POST /sp/campaigns/delete for deletion
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/campaigns/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.campaign.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects object with campaignIdFilter
        let deleteRequest = SPCampaignDeleteRequest(campaignIdFilter: SPIdFilter(include: [campaignId]))
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(deleteRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 207 {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Ad Group Management

    public func listAdGroups(
        campaignId: String?,
        profileId: String,
        region: AmazonRegion,
        stateFilter: [AdGroupState]?
    ) async throws -> [SponsoredProductsAdGroup] {
        let accessToken = try await getAccessToken(for: region)
        // V3 API uses POST /sp/adGroups/list
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/adGroups/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Accept")

        // V3 API uses request body for filters
        var requestBody: [String: Any] = [:]
        if let campaignId = campaignId {
            requestBody["campaignIdFilter"] = ["include": [campaignId]]
        }
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            requestBody["stateFilter"] = ["include": stateFilter.map(\.rawValue)]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let listResponse = try decoder.decode(SPAdGroupListResponse.self, from: data)
            return listResponse.adGroups
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func getAdGroup(
        adGroupId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsAdGroup {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/adGroups/\(adGroupId)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsAdGroup.self, from: data)
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func createAdGroup(
        adGroup: SponsoredProductsAdGroup,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsAdGroup {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/adGroups")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(["adGroups": [adGroup]])

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPAdGroupBatchResponse.self, from: data)
            if let successItem = batchResponse.adGroups.success.first {
                return successItem.adGroup
            } else if let errorItem = batchResponse.adGroups.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.map(\.message).joined(separator: ", "))
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func updateAdGroup(
        adGroup: SponsoredProductsAdGroup,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsAdGroup {
        guard adGroup.adGroupId != nil else {
            throw AmazonAdvertisingError.invalidRequest("Ad Group ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/adGroups")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(["adGroups": [adGroup]])

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPAdGroupBatchResponse.self, from: data)
            if let successItem = batchResponse.adGroups.success.first {
                return successItem.adGroup
            } else if let errorItem = batchResponse.adGroups.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.map(\.message).joined(separator: ", "))
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func archiveAdGroup(
        adGroupId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/adGroups/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.adGroup.headerValue, forHTTPHeaderField: "Accept")

        let deleteRequest = ["adGroupIdFilter": ["include": [adGroupId]]]
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(deleteRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 207 {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Product Ad Management

    public func listProductAds(
        adGroupId: String?,
        profileId: String,
        region: AmazonRegion,
        stateFilter: [ProductAdState]?
    ) async throws -> [SponsoredProductsProductAd] {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/productAds/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.productAd.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.productAd.headerValue, forHTTPHeaderField: "Accept")

        // Build request body with filters
        var requestBody: [String: Any] = [:]
        if let adGroupId = adGroupId {
            requestBody["adGroupIdFilter"] = ["include": [adGroupId]]
        }
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            requestBody["stateFilter"] = ["include": stateFilter.map(\.rawValue)]
        }

        if !requestBody.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } else {
            request.httpBody = "{}".data(using: .utf8)
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let listResponse = try decoder.decode(SPProductAdListResponse.self, from: data)
            return listResponse.productAds
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func createProductAd(
        productAd: SponsoredProductsProductAd,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsProductAd {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/productAds")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.productAd.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.productAd.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects batch request
        let createRequest = ["productAds": [productAd]]
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(createRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        // V3 API returns 207 Multi-Status for batch operations
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPProductAdBatchResponse.self, from: data)
            if let successItem = batchResponse.productAds.success.first {
                return successItem.productAd
            } else if let errorItem = batchResponse.productAds.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.first?.message ?? "Unknown error")
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func updateProductAd(
        productAd: SponsoredProductsProductAd,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsProductAd {
        guard productAd.adId != nil else {
            throw AmazonAdvertisingError.invalidRequest("Product Ad ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/productAds")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.productAd.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.productAd.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects batch request
        let updateRequest = ["productAds": [productAd]]
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(updateRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        // V3 API returns 207 Multi-Status for batch operations
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPProductAdBatchResponse.self, from: data)
            if let successItem = batchResponse.productAds.success.first {
                return successItem.productAd
            } else if let errorItem = batchResponse.productAds.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.first?.message ?? "Unknown error")
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func archiveProductAd(
        adId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/productAds/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.productAd.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.productAd.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects delete request with filter
        let deleteRequest = ["adIdFilter": ["include": [adId]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: deleteRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 207 {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Keyword Management

    public func listKeywords(
        adGroupId: String?,
        profileId: String,
        region: AmazonRegion,
        stateFilter: [KeywordState]?
    ) async throws -> [SponsoredProductsKeyword] {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/keywords/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.keyword.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.keyword.headerValue, forHTTPHeaderField: "Accept")

        // Build request body with filters
        var requestBody: [String: Any] = [:]
        if let adGroupId = adGroupId {
            requestBody["adGroupIdFilter"] = ["include": [adGroupId]]
        }
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            requestBody["stateFilter"] = ["include": stateFilter.map(\.rawValue)]
        }

        if !requestBody.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } else {
            request.httpBody = "{}".data(using: .utf8)
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let listResponse = try decoder.decode(SPKeywordListResponse.self, from: data)
            return listResponse.keywords
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func createKeyword(
        keyword: SponsoredProductsKeyword,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsKeyword {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/keywords")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.keyword.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.keyword.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects batch request
        let createRequest = ["keywords": [keyword]]
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(createRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        // V3 API returns 207 Multi-Status for batch operations
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPKeywordBatchResponse.self, from: data)
            if let successItem = batchResponse.keywords.success.first {
                return successItem.keyword
            } else if let errorItem = batchResponse.keywords.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.first?.message ?? "Unknown error")
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func updateKeyword(
        keyword: SponsoredProductsKeyword,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsKeyword {
        guard keyword.keywordId != nil else {
            throw AmazonAdvertisingError.invalidRequest("Keyword ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/keywords")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.keyword.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.keyword.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects batch request
        let updateRequest = ["keywords": [keyword]]
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(updateRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        // V3 API returns 207 Multi-Status for batch operations
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPKeywordBatchResponse.self, from: data)
            if let successItem = batchResponse.keywords.success.first {
                return successItem.keyword
            } else if let errorItem = batchResponse.keywords.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.first?.message ?? "Unknown error")
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func archiveKeyword(
        keywordId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/keywords/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.keyword.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.keyword.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects delete request with filter
        let deleteRequest = ["keywordIdFilter": ["include": [keywordId]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: deleteRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 207 {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Product Target Management

    public func listTargets(
        adGroupId: String?,
        profileId: String,
        region: AmazonRegion,
        stateFilter: [TargetState]?
    ) async throws -> [SponsoredProductsTarget] {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/targets/list")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.target.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.target.headerValue, forHTTPHeaderField: "Accept")

        // Build request body with filters
        var requestBody: [String: Any] = [:]
        if let adGroupId = adGroupId {
            requestBody["adGroupIdFilter"] = ["include": [adGroupId]]
        }
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            requestBody["stateFilter"] = ["include": stateFilter.map(\.rawValue)]
        }

        if !requestBody.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } else {
            request.httpBody = "{}".data(using: .utf8)
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let listResponse = try decoder.decode(SPTargetListResponse.self, from: data)
            return listResponse.targetingClauses
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func createTarget(
        target: SponsoredProductsTarget,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsTarget {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/targets")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.target.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.target.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects batch request
        let createRequest = ["targetingClauses": [target]]
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(createRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        // V3 API returns 207 Multi-Status for batch operations
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPTargetBatchResponse.self, from: data)
            if let successItem = batchResponse.targetingClauses.success.first {
                return successItem.targetingClause
            } else if let errorItem = batchResponse.targetingClauses.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.first?.message ?? "Unknown error")
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func updateTarget(
        target: SponsoredProductsTarget,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsTarget {
        guard target.targetId != nil else {
            throw AmazonAdvertisingError.invalidRequest("Target ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/targets")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.target.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.target.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects batch request
        let updateRequest = ["targetingClauses": [target]]
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(updateRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        // V3 API returns 207 Multi-Status for batch operations
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(SPTargetBatchResponse.self, from: data)
            if let successItem = batchResponse.targetingClauses.success.first {
                return successItem.targetingClause
            } else if let errorItem = batchResponse.targetingClauses.error.first {
                throw AmazonAdvertisingError.apiError(errorItem.errors.first?.message ?? "Unknown error")
            }
            throw AmazonAdvertisingError.invalidResponse
        } else {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    public func archiveTarget(
        targetId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/targets/delete")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue(SPMediaType.target.headerValue, forHTTPHeaderField: "Content-Type")
        request.setValue(SPMediaType.target.headerValue, forHTTPHeaderField: "Accept")

        // V3 API expects delete request with filter
        let deleteRequest = ["targetIdFilter": ["include": [targetId]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: deleteRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 207 {
            throw makeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Private Helpers

    /// Creates an HTTP error with response body included
    private func makeHTTPError(statusCode: Int, data: Data) -> AmazonAdvertisingError {
        let responseBody = String(data: data, encoding: .utf8)
        return AmazonAdvertisingError.httpError(statusCode, responseBody: responseBody)
    }
}
