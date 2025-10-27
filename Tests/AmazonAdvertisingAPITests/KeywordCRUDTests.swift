//
//  KeywordCRUDTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for Sponsored Products Keyword CRUD operations
//  Tests create, list, update, and archive operations
//

import XCTest
import Foundation
@testable import AmazonAdvertisingAPI

final class KeywordCRUDTests: XCTestCase {

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

        // Store valid authentication tokens for all tests
        let region = AmazonRegion.northAmerica
        try await storage.save("valid_access_token", for: TokenStorageKey.accessToken, region: region)
        try await storage.save(makeExpiryString(secondsFromNow: 3600), for: TokenStorageKey.tokenExpiry, region: region)
        try await storage.save("refresh_token", for: TokenStorageKey.refreshToken, region: region)
    }

    override func tearDown() async throws {
        // Cancel any active OAuth authorization for all regions to clean up servers
        await client?.cancelAuthorization(for: .northAmerica)
        await client?.cancelAuthorization(for: .europe)
        await client?.cancelAuthorization(for: .farEast)

        MockURLProtocol.reset()
        await storage?.clearAll()
        client = nil
        storage = nil
        mockSession = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    func makeExpiryString(secondsFromNow: TimeInterval) -> String {
        let expiryDate = Date().addingTimeInterval(secondsFromNow)
        return ISO8601DateFormatter().string(from: expiryDate)
    }

    func mockKeyword(
        id: String = "KEYWORD123",
        adGroupId: String = "ADGROUP123",
        campaignId: String = "CAMPAIGN123",
        keywordText: String = "test keyword"
    ) -> SponsoredProductsKeyword {
        return SponsoredProductsKeyword(
            keywordId: id,
            adGroupId: adGroupId,
            campaignId: campaignId,
            keywordText: keywordText,
            matchType: .broad,
            bid: 1.00,
            state: .enabled,
            nativeLanguageLocale: nil
        )
    }

    // MARK: - List Keywords Tests (2 tests)

    func testListKeywordsReturnsAllKeywords() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock successful keywords response
        let keywords = [mockKeyword(id: "KW1", keywordText: "shoes"), mockKeyword(id: "KW2", keywordText: "boots")]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/keywords") == true {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-ClientId"), "test_client_id")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.httpMethod, "GET")

                return .json(keywords)
            }
            return .notFound()
        }

        let result = try await client.listKeywords(
            adGroupId: nil,
            profileId: profileId,
            region: region,
            stateFilter: nil
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].keywordId, "KW1")
        XCTAssertEqual(result[0].keywordText, "shoes")
        XCTAssertEqual(result[1].keywordId, "KW2")
        XCTAssertEqual(result[1].keywordText, "boots")
    }

    func testListKeywordsWithFilters() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock keywords response
        let keywords = [mockKeyword()]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/keywords") == true {
                // Verify query parameters
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
                let adGroupIdParam = components?.queryItems?.first(where: { $0.name == "adGroupIdFilter" })
                let stateFilterParam = components?.queryItems?.first(where: { $0.name == "stateFilter" })

                XCTAssertNotNil(adGroupIdParam)
                XCTAssertEqual(adGroupIdParam?.value, "ADGROUP123")
                XCTAssertNotNil(stateFilterParam)
                XCTAssertEqual(stateFilterParam?.value, "enabled")

                return .json(keywords)
            }
            return .notFound()
        }

        let result = try await client.listKeywords(
            adGroupId: "ADGROUP123",
            profileId: profileId,
            region: region,
            stateFilter: [.enabled]
        )

        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Create Keyword Tests (2 tests)

    func testCreateKeywordReturnsCreatedKeyword() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Keyword to create (without ID)
        let newKeyword = SponsoredProductsKeyword(
            keywordId: nil,
            adGroupId: "ADGROUP123",
            campaignId: "CAMPAIGN123",
            keywordText: "running shoes",
            matchType: .phrase,
            bid: 1.25,
            state: .enabled,
            nativeLanguageLocale: nil
        )

        // Response with generated ID
        let createdKeyword = mockKeyword(id: "NEWKW123", keywordText: "running shoes")

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/keywords") == true && request.httpMethod == "POST" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

                return .json(createdKeyword, statusCode: 201)
            }
            return .notFound()
        }

        let result = try await client.createKeyword(keyword: newKeyword, profileId: profileId, region: region)

        XCTAssertEqual(result.keywordId, "NEWKW123")
        XCTAssertEqual(result.keywordText, "running shoes")
    }

    func testCreateKeywordHandlesValidationError() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Invalid keyword (empty text)
        let newKeyword = SponsoredProductsKeyword(
            keywordId: nil,
            adGroupId: "ADGROUP123",
            campaignId: "CAMPAIGN123",
            keywordText: "",
            matchType: .broad,
            bid: nil,
            state: .enabled,
            nativeLanguageLocale: nil
        )

        // Mock 400 Bad Request
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/keywords") == true && request.httpMethod == "POST" {
                return .httpError(statusCode: 400)
            }
            return .notFound()
        }

        do {
            _ = try await client.createKeyword(keyword: newKeyword, profileId: profileId, region: region)
            XCTFail("Should have thrown validation error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Update Keyword Tests (2 tests)

    func testUpdateKeywordReturnsUpdatedKeyword() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Keyword with updates
        var updatedKeyword = mockKeyword(id: "KEYWORD123")
        updatedKeyword.bid = 2.50
        updatedKeyword.state = .paused

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/keywords/KEYWORD123") == true && request.httpMethod == "PUT" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

                return .json(updatedKeyword)
            }
            return .notFound()
        }

        let result = try await client.updateKeyword(keyword: updatedKeyword, profileId: profileId, region: region)

        XCTAssertEqual(result.keywordId, "KEYWORD123")
        XCTAssertEqual(result.bid, 2.50)
        XCTAssertEqual(result.state, .paused)
    }

    func testUpdateKeywordRequiresKeywordId() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Keyword without ID
        let keywordWithoutId = SponsoredProductsKeyword(
            keywordId: nil,
            adGroupId: "ADGROUP123",
            campaignId: "CAMPAIGN123",
            keywordText: "test",
            matchType: .broad,
            bid: nil,
            state: .enabled,
            nativeLanguageLocale: nil
        )

        do {
            _ = try await client.updateKeyword(keyword: keywordWithoutId, profileId: profileId, region: region)
            XCTFail("Should have thrown invalid request error")
        } catch let error as AmazonAdvertisingError {
            if case .invalidRequest(let message) = error {
                XCTAssertTrue(message.contains("Keyword ID is required"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Archive Keyword Tests (2 tests)

    func testArchiveKeywordSucceeds() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let keywordId = "KEYWORD123"

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/keywords/\(keywordId)") == true && request.httpMethod == "DELETE" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)

                return .success(data: Data(), statusCode: 200)
            }
            return .notFound()
        }

        // Archive should complete without throwing
        try await client.archiveKeyword(keywordId: keywordId, profileId: profileId, region: region)

        // Success - no assertion needed for void return
    }

    func testArchiveKeywordHandlesNotFound() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let keywordId = "NONEXISTENT"

        // Mock 404 Not Found
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/keywords/\(keywordId)") == true && request.httpMethod == "DELETE" {
                return .notFound()
            }
            return .notFound()
        }

        do {
            try await client.archiveKeyword(keywordId: keywordId, profileId: profileId, region: region)
            XCTFail("Should have thrown 404 error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}
