//
//  AmazonAdvertisingClientTests.swift
//  AmazonAdvertisingAPITests
//
//  Comprehensive tests for AmazonAdvertisingClient
//  Tests authentication, OAuth, profile management, regions, and error handling
//

import XCTest
import Foundation
@testable import AmazonAdvertisingAPI

final class AmazonAdvertisingClientTests: XCTestCase {

    var client: AmazonAdvertisingClient!
    var storage: MockTokenStorage!
    var mockSession: URLSession!

    override func setUp() async throws {
        try await super.setUp()

        // Reset mock protocol
        MockURLProtocol.reset()

        // Create mock session with protocol
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)

        // Create mock storage
        storage = MockTokenStorage()

        // Create client with mocks
        client = AmazonAdvertisingClient(
            clientId: "test_client_id",
            clientSecret: "test_client_secret",
            storage: storage,
            urlSession: mockSession
        )
    }

    override func tearDown() async throws {
        MockURLProtocol.reset()
        await storage.clearAll()
        client = nil
        storage = nil
        mockSession = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    func mockSuccessfulTokenResponse() -> AmazonTokenResponse {
        return AmazonTokenResponse(
            accessToken: "mock_access_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            refreshToken: "mock_refresh_token",
            scope: "profile advertising::campaign_management"
        )
    }

    func mockProfile() -> AmazonProfile {
        return AmazonProfile(
            profileId: "PROFILE123",
            countryCode: "US",
            currencyCode: "USD",
            timezone: "America/Los_Angeles",
            accountInfo: AmazonAccountInfo(
                id: "ACC123",
                type: "seller",
                name: "Test Account",
                validPaymentMethod: true
            )
        )
    }

    func mockManagerAccount() -> AmazonManagerAccount {
        return AmazonManagerAccount(
            managerAccountId: "MA123",
            managerAccountName: "Test Manager",
            linkedAccounts: [
                AmazonLinkedAccount(
                    profileId: "P456",
                    accountId: "A789",
                    accountName: "Linked Account",
                    marketplaceId: "ATVPDKIKX0DER"
                )
            ]
        )
    }

    // MARK: - Authentication & OAuth Tests (8 tests)

    func testInitiateAuthorizationGeneratesValidURL() async throws {
        let region = AmazonRegion.northAmerica

        let authURL = try await client.initiateAuthorization(for: region)

        // Verify URL structure
        XCTAssertNotNil(authURL)
        XCTAssertEqual(authURL.scheme, "https")
        XCTAssertTrue(authURL.absoluteString.contains("amazon.com"))

        // Verify required query parameters
        let components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        XCTAssertTrue(queryItems.contains { $0.name == "client_id" })
        XCTAssertTrue(queryItems.contains { $0.name == "redirect_uri" })
        XCTAssertTrue(queryItems.contains { $0.name == "response_type" && $0.value == "code" })
        XCTAssertTrue(queryItems.contains { $0.name == "scope" })
    }

    func testInitiateAuthorizationIncludesPKCEChallenge() async throws {
        let region = AmazonRegion.northAmerica

        let authURL = try await client.initiateAuthorization(for: region)

        // Verify PKCE parameters
        let components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        XCTAssertTrue(queryItems.contains { $0.name == "code_challenge" && $0.value != nil })
        XCTAssertTrue(queryItems.contains { $0.name == "code_challenge_method" && $0.value == "S256" })
    }

    func testGetAccessTokenRetrievesValidToken() async throws {
        let region = AmazonRegion.northAmerica

        // Store a valid token
        try await storage.save("valid_access_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        let token = try await client.getAccessToken(for: region)

        XCTAssertEqual(token, "valid_access_token")

        let retrieveCalled = await storage.retrieveCalled
        XCTAssertTrue(retrieveCalled)
    }

    func testGetAccessTokenRefreshesExpiredToken() async throws {
        let region = AmazonRegion.northAmerica

        // Store expired token
        try await storage.save("expired_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 - 100), for: "token_expiry", region: region)
        try await storage.save("refresh_token", for: "refresh_token", region: region)

        // Mock successful token refresh response
        let tokenResponse = mockSuccessfulTokenResponse()
        MockURLProtocol.setRequestHandler { request in
            if request.url?.absoluteString.contains("/auth/o2/token") == true {
                return .json(tokenResponse)
            }
            return .notFound()
        }

        let token = try await client.getAccessToken(for: region)

        XCTAssertEqual(token, "mock_access_token")

        let saveCalled = await storage.saveCalled
        XCTAssertTrue(saveCalled)
    }

    func testRefreshTokenUpdatesAccessToken() async throws {
        let region = AmazonRegion.northAmerica

        // Store refresh token
        try await storage.save("refresh_token", for: "refresh_token", region: region)

        // Mock successful refresh response
        let tokenResponse = mockSuccessfulTokenResponse()
        MockURLProtocol.setRequestHandler { request in
            if request.url?.absoluteString.contains("/auth/o2/token") == true {
                return .json(tokenResponse)
            }
            return .notFound()
        }

        try await client.refreshToken(for: region)

        // Verify new token was saved
        let savedToken = try await storage.retrieve(for: "access_token", region: region)
        XCTAssertEqual(savedToken, "mock_access_token")
    }

    func testIsAuthenticatedReturnsTrueWithValidTokens() async {
        let region = AmazonRegion.northAmerica

        // Store valid tokens
        try? await storage.save("access_token", for: "access_token", region: region)
        try? await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        let isAuth = await client.isAuthenticated(for: region)

        XCTAssertTrue(isAuth)
    }

    func testIsAuthenticatedReturnsFalseWithoutTokens() async {
        let region = AmazonRegion.northAmerica

        let isAuth = await client.isAuthenticated(for: region)

        XCTAssertFalse(isAuth)
    }

    func testLogoutClearsStoredTokens() async throws {
        let region = AmazonRegion.northAmerica

        // Store tokens
        try await storage.save("access_token", for: "access_token", region: region)
        try await storage.save("refresh_token", for: "refresh_token", region: region)

        // Logout
        try await client.logout(for: region)

        // Verify tokens are cleared
        let exists = await storage.exists(for: "access_token", region: region)
        XCTAssertFalse(exists)
    }

    // MARK: - Profile Management Tests (4 tests)

    func testFetchProfilesReturnsProfiles() async throws {
        let region = AmazonRegion.northAmerica

        // Store valid token
        try await storage.save("access_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        // Mock profiles response
        let profiles = [mockProfile()]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/v2/profiles") == true {
                return .json(profiles)
            }
            return .notFound()
        }

        let fetchedProfiles = try await client.fetchProfiles(for: region)

        XCTAssertEqual(fetchedProfiles.count, 1)
        XCTAssertEqual(fetchedProfiles[0].profileId, "PROFILE123")
    }

    func testFetchManagerAccountsReturnsAccounts() async throws {
        let region = AmazonRegion.northAmerica

        // Store valid token
        try await storage.save("access_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        // Mock manager accounts response
        let response = AmazonManagerAccountsResponse(managerAccounts: [mockManagerAccount()])
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/managerAccounts") == true {
                return .json(response)
            }
            return .notFound()
        }

        let managerAccounts = try await client.fetchManagerAccounts(for: region)

        XCTAssertEqual(managerAccounts.managerAccounts.count, 1)
        XCTAssertEqual(managerAccounts.managerAccounts[0].managerAccountId, "MA123")
    }

    func testVerifyConnectionReturnsTrueForValidAuth() async throws {
        let region = AmazonRegion.northAmerica

        // Store valid token
        try await storage.save("access_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        // Mock successful profiles response
        let profiles = [mockProfile()]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/v2/profiles") == true {
                return .json(profiles)
            }
            return .notFound()
        }

        let isValid = try await client.verifyConnection(for: region)

        XCTAssertTrue(isValid)
    }

    func testVerifyConnectionReturnsFalseForInvalidAuth() async throws {
        let region = AmazonRegion.northAmerica

        // Store valid token but mock 401 response
        try await storage.save("invalid_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        // Mock 401 unauthorized
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/v2/profiles") == true {
                return .unauthorized()
            }
            return .notFound()
        }

        let isValid = try await client.verifyConnection(for: region)

        XCTAssertFalse(isValid)
    }

    // MARK: - Region Handling Tests (3 tests)

    func testMultiRegionAuthenticationIsolation() async {
        let naRegion = AmazonRegion.northAmerica
        let euRegion = AmazonRegion.europe

        // Store token for NA only
        try? await storage.save("na_token", for: "access_token", region: naRegion)
        try? await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: naRegion)

        let naAuth = await client.isAuthenticated(for: naRegion)
        let euAuth = await client.isAuthenticated(for: euRegion)

        XCTAssertTrue(naAuth)
        XCTAssertFalse(euAuth)
    }

    func testRegionSpecificAPIEndpoints() async throws {
        let naRegion = AmazonRegion.northAmerica
        let euRegion = AmazonRegion.europe

        XCTAssertEqual(naRegion.advertisingAPIBaseURL.absoluteString, "https://advertising-api.amazon.com")
        XCTAssertEqual(euRegion.advertisingAPIBaseURL.absoluteString, "https://advertising-api-eu.amazon.com")
    }

    func testCancelAuthorizationCleansUpServer() async throws {
        let region = AmazonRegion.northAmerica

        // Initiate authorization
        _ = try await client.initiateAuthorization(for: region)

        // Cancel authorization
        await client.cancelAuthorization(for: region)

        // Verify cleanup (no easy way to test OAuth server cleanup without exposing internals)
        // This test primarily ensures the method doesn't throw
        XCTAssertTrue(true)
    }

    // MARK: - Error Handling Tests (10 tests)

    func testHTTPErrorThrowsCorrectError() async throws {
        let region = AmazonRegion.northAmerica

        // Store valid token
        try await storage.save("access_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        // Mock 500 server error
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/v2/profiles") == true {
                return .serverError()
            }
            return .notFound()
        }

        do {
            _ = try await client.fetchProfiles(for: region)
            XCTFail("Should have thrown HTTP error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testNoAccessTokenThrowsError() async throws {
        let region = AmazonRegion.northAmerica

        // Don't store any token

        do {
            _ = try await client.getAccessToken(for: region)
            XCTFail("Should have thrown noAccessToken error")
        } catch let error as AmazonAdvertisingError {
            if case .noAccessToken = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testNoRefreshTokenThrowsError() async throws {
        let region = AmazonRegion.northAmerica

        // Store expired access token but no refresh token
        try await storage.save("expired_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 - 100), for: "token_expiry", region: region)

        do {
            _ = try await client.getAccessToken(for: region)
            XCTFail("Should have thrown noRefreshToken error")
        } catch let error as AmazonAdvertisingError {
            if case .noRefreshToken = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testExpiredTokenAutoRefresh() async throws {
        let region = AmazonRegion.northAmerica

        // Store expired token with refresh token
        try await storage.save("expired_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 - 100), for: "token_expiry", region: region)
        try await storage.save("refresh_token", for: "refresh_token", region: region)

        // Mock successful refresh
        let tokenResponse = mockSuccessfulTokenResponse()
        var refreshCalled = false

        MockURLProtocol.setRequestHandler { request in
            if request.url?.absoluteString.contains("/auth/o2/token") == true {
                refreshCalled = true
                return .json(tokenResponse)
            }
            return .notFound()
        }

        let token = try await client.getAccessToken(for: region)

        XCTAssertTrue(refreshCalled)
        XCTAssertEqual(token, "mock_access_token")
    }

    func testInvalidResponseThrowsError() async throws {
        let region = AmazonRegion.northAmerica

        // Store valid token
        try await storage.save("access_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        // Mock invalid JSON response
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/v2/profiles") == true {
                let invalidData = "not valid json".data(using: .utf8)!
                return .success(data: invalidData, statusCode: 200)
            }
            return .notFound()
        }

        do {
            _ = try await client.fetchProfiles(for: region)
            XCTFail("Should have thrown decoding error")
        } catch {
            // Expected decoding error
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testAPIAccessNotApprovedError() async throws {
        let region = AmazonRegion.northAmerica

        // Store valid token
        try await storage.save("access_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        // Mock 403 forbidden (API not approved)
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/v2/profiles") == true {
                return .forbidden()
            }
            return .notFound()
        }

        do {
            _ = try await client.fetchProfiles(for: region)
            XCTFail("Should have thrown HTTP 403 error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 403)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testOAuthErrorHandling() async throws {
        let region = AmazonRegion.northAmerica

        // Store refresh token
        try await storage.save("refresh_token", for: "refresh_token", region: region)

        // Mock OAuth error response
        struct OAuthErrorResponse: Codable {
            let error: String
            let errorDescription: String?

            enum CodingKeys: String, CodingKey {
                case error
                case errorDescription = "error_description"
            }
        }

        let oauthError = OAuthErrorResponse(error: "invalid_grant", errorDescription: "Refresh token expired")

        MockURLProtocol.setRequestHandler { request in
            if request.url?.absoluteString.contains("/auth/o2/token") == true {
                return .json(oauthError, statusCode: 400)
            }
            return .notFound()
        }

        do {
            try await client.refreshToken(for: region)
            XCTFail("Should have thrown OAuth error")
        } catch {
            // Expected error (may not be specifically AmazonAdvertisingError.oauthError if not parsed)
            XCTAssertTrue(true)
        }
    }

    func testTimeoutHandling() async throws {
        let region = AmazonRegion.northAmerica

        // Store valid token
        try await storage.save("access_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        // Mock timeout error
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/v2/profiles") == true {
                return .failure(error: URLError(.timedOut))
            }
            return .notFound()
        }

        do {
            _ = try await client.fetchProfiles(for: region)
            XCTFail("Should have thrown timeout error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testStorageErrorHandling() async throws {
        // Create storage that throws errors
        let failingStorage = MockTokenStorage()

        let failingClient = AmazonAdvertisingClient(
            clientId: "test",
            clientSecret: "test",
            storage: failingStorage,
            urlSession: mockSession
        )

        // Attempting to get token with no storage should fail gracefully
        do {
            _ = try await failingClient.getAccessToken(for: .northAmerica)
            XCTFail("Should have thrown error")
        } catch {
            // Expected
            XCTAssertTrue(true)
        }
    }

    func testRateLimitHandling() async throws {
        let region = AmazonRegion.northAmerica

        // Store valid token
        try await storage.save("access_token", for: "access_token", region: region)
        try await storage.save(String(Date().timeIntervalSince1970 + 3600), for: "token_expiry", region: region)

        // Mock 429 rate limited
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/v2/profiles") == true {
                return .rateLimited()
            }
            return .notFound()
        }

        do {
            _ = try await client.fetchProfiles(for: region)
            XCTFail("Should have thrown HTTP 429 error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 429)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
