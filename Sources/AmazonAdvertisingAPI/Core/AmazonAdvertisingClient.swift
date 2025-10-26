//
//  AmazonAdvertisingClient.swift
//  AmazonAdvertisingAPI
//
//  Main client for Amazon Advertising API operations
//

import Foundation
import CryptoKit

/// Main client for interacting with Amazon Advertising API
public actor AmazonAdvertisingClient: AmazonAdvertisingClientProtocol {
    private let clientId: String
    private let clientSecret: String
    private let storage: TokenStorageProtocol
    private let htmlProvider: OAuthHTMLProvider

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
    public init(
        clientId: String,
        clientSecret: String,
        storage: TokenStorageProtocol,
        htmlProvider: OAuthHTMLProvider = DefaultOAuthHTMLProvider()
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.storage = storage
        self.htmlProvider = htmlProvider
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
        // Retrieve refresh token
        guard let refreshToken = try? await storage.retrieve(
            for: TokenStorageKey.refreshToken,
            region: region
        ) else {
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
        let (data, response) = try await URLSession.shared.data(for: request)

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
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func getAccessToken(for region: AmazonRegion) async throws -> String {
        // Check if token exists and is not expired
        if let expiryString = try? await storage.retrieve(
            for: TokenStorageKey.tokenExpiry,
            region: region
        ),
           let expiryDate = ISO8601DateFormatter().date(from: expiryString) {
            // If token expires in less than 5 minutes, refresh it
            if expiryDate.timeIntervalSinceNow < 300 {
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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let profiles = try JSONDecoder().decode([AmazonProfile].self, from: data)
            return profiles
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let managerAccounts = try JSONDecoder().decode(AmazonManagerAccountsResponse.self, from: data)
            return managerAccounts
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        let (data, response) = try await URLSession.shared.data(for: request)

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
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/campaigns")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add state filter as query parameter if provided
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "stateFilter", value: stateFilter.map(\.rawValue).joined(separator: ","))
            ]
            request.url = components.url
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode([SponsoredProductsCampaign].self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsCampaign.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(campaign)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsCampaign.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func updateCampaign(
        campaign: SponsoredProductsCampaign,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsCampaign {
        guard let campaignId = campaign.campaignId else {
            throw AmazonAdvertisingError.invalidRequest("Campaign ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/campaigns/\(campaignId)")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(campaign)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsCampaign.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func archiveCampaign(
        campaignId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/campaigns/\(campaignId)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/adGroups")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add filters as query parameters
        var queryItems: [URLQueryItem] = []
        if let campaignId = campaignId {
            queryItems.append(URLQueryItem(name: "campaignIdFilter", value: campaignId))
        }
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            queryItems.append(URLQueryItem(name: "stateFilter", value: stateFilter.map(\.rawValue).joined(separator: ",")))
        }

        if !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryItems
            request.url = components.url
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode([SponsoredProductsAdGroup].self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsAdGroup.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(adGroup)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsAdGroup.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func updateAdGroup(
        adGroup: SponsoredProductsAdGroup,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsAdGroup {
        guard let adGroupId = adGroup.adGroupId else {
            throw AmazonAdvertisingError.invalidRequest("Ad Group ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/adGroups/\(adGroupId)")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(adGroup)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsAdGroup.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func archiveAdGroup(
        adGroupId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/adGroups/\(adGroupId)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/productAds")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add filters as query parameters
        var queryItems: [URLQueryItem] = []
        if let adGroupId = adGroupId {
            queryItems.append(URLQueryItem(name: "adGroupIdFilter", value: adGroupId))
        }
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            queryItems.append(URLQueryItem(name: "stateFilter", value: stateFilter.map(\.rawValue).joined(separator: ",")))
        }

        if !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryItems
            request.url = components.url
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode([SponsoredProductsProductAd].self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(productAd)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsProductAd.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func updateProductAd(
        productAd: SponsoredProductsProductAd,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsProductAd {
        guard let adId = productAd.adId else {
            throw AmazonAdvertisingError.invalidRequest("Product Ad ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/productAds/\(adId)")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(productAd)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsProductAd.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func archiveProductAd(
        adId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/productAds/\(adId)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/keywords")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add filters as query parameters
        var queryItems: [URLQueryItem] = []
        if let adGroupId = adGroupId {
            queryItems.append(URLQueryItem(name: "adGroupIdFilter", value: adGroupId))
        }
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            queryItems.append(URLQueryItem(name: "stateFilter", value: stateFilter.map(\.rawValue).joined(separator: ",")))
        }

        if !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryItems
            request.url = components.url
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode([SponsoredProductsKeyword].self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(keyword)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsKeyword.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func updateKeyword(
        keyword: SponsoredProductsKeyword,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsKeyword {
        guard let keywordId = keyword.keywordId else {
            throw AmazonAdvertisingError.invalidRequest("Keyword ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/keywords/\(keywordId)")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(keyword)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsKeyword.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func archiveKeyword(
        keywordId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/keywords/\(keywordId)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/targets")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add filters as query parameters
        var queryItems: [URLQueryItem] = []
        if let adGroupId = adGroupId {
            queryItems.append(URLQueryItem(name: "adGroupIdFilter", value: adGroupId))
        }
        if let stateFilter = stateFilter, !stateFilter.isEmpty {
            queryItems.append(URLQueryItem(name: "stateFilter", value: stateFilter.map(\.rawValue).joined(separator: ",")))
        }

        if !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryItems
            request.url = components.url
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode([SponsoredProductsTarget].self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(target)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsTarget.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func updateTarget(
        target: SponsoredProductsTarget,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsTarget {
        guard let targetId = target.targetId else {
            throw AmazonAdvertisingError.invalidRequest("Target ID is required for update")
        }

        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/targets/\(targetId)")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(target)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SponsoredProductsTarget.self, from: data)
        } else {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }

    public func archiveTarget(
        targetId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws {
        let accessToken = try await getAccessToken(for: region)
        let url = region.advertisingAPIBaseURL.appendingPathComponent("/sp/targets/\(targetId)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Amazon-Advertising-API-ClientId")
        request.setValue(profileId, forHTTPHeaderField: "Amazon-Advertising-API-Scope")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonAdvertisingError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw AmazonAdvertisingError.httpError(httpResponse.statusCode)
        }
    }
}
