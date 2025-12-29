//
//  KeywordCRUDTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for Sponsored Products Keyword CRUD operations
//  Tests create, list, update, and archive operations
//  Updated for V3 API patterns
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

    // MARK: - List Keywords Tests (V3 API uses POST /sp/keywords/list)

    func testListKeywordsReturnsAllKeywords() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock V3 list response
        let keywords = [mockKeyword(id: "KW1", keywordText: "shoes"), mockKeyword(id: "KW2", keywordText: "boots")]
        let listResponse = SPKeywordListResponse(keywords: keywords, nextToken: nil, totalResults: 2)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/keywords/list") == true {
                // V3 API uses POST for list
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-ClientId"), "test_client_id")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)

                return .json(listResponse)
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

        // Mock V3 list response
        let keywords = [mockKeyword()]
        let listResponse = SPKeywordListResponse(keywords: keywords, nextToken: nil, totalResults: 1)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/keywords/list") == true {
                // V3 API sends filter in POST body, not query parameters
                XCTAssertEqual(request.httpMethod, "POST")

                return .json(listResponse)
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

    // MARK: - Create Keyword Tests (V3 API returns batch response with 207)

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

        // V3 Response with batch wrapper
        let createdKeyword = mockKeyword(id: "NEWKW123", keywordText: "running shoes")
        let successItem = SPKeywordSuccessItem(keyword: createdKeyword, keywordId: "NEWKW123", index: 0)
        let batchResult = SPKeywordBatchResult(success: [successItem], error: [])
        let batchResponse = SPKeywordBatchResponse(keywords: batchResult)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/sp/keywords" && request.httpMethod == "POST" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                // V3 API uses versioned content type
                XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("application/vnd.spKeyword.v3+json") == true)

                // V3 API returns 207 Multi-Status
                return .json(batchResponse, statusCode: 207)
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
            if request.url?.path == "/sp/keywords" && request.httpMethod == "POST" {
                return .httpError(statusCode: 400)
            }
            return .notFound()
        }

        do {
            _ = try await client.createKeyword(keyword: newKeyword, profileId: profileId, region: region)
            XCTFail("Should have thrown validation error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Update Keyword Tests (V3 API uses batch PUT)

    func testUpdateKeywordReturnsUpdatedKeyword() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Keyword with updates
        var updatedKeyword = mockKeyword(id: "KEYWORD123")
        updatedKeyword.bid = 2.50
        updatedKeyword.state = .paused

        // V3 batch response
        let successItem = SPKeywordSuccessItem(keyword: updatedKeyword, keywordId: "KEYWORD123", index: 0)
        let batchResult = SPKeywordBatchResult(success: [successItem], error: [])
        let batchResponse = SPKeywordBatchResponse(keywords: batchResult)

        MockURLProtocol.setRequestHandler { request in
            // V3 uses PUT to /sp/keywords for batch update
            if request.url?.path == "/sp/keywords" && request.httpMethod == "PUT" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("application/vnd.spKeyword.v3+json") == true)

                return .json(batchResponse, statusCode: 207)
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

    // MARK: - Archive Keyword Tests (V3 uses POST to /sp/keywords/delete)

    func testArchiveKeywordSucceeds() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let keywordId = "KEYWORD123"

        MockURLProtocol.setRequestHandler { request in
            // V3 API uses POST to /delete endpoint
            if request.url?.path.contains("/sp/keywords/delete") == true && request.httpMethod == "POST" {
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
            if request.url?.path.contains("/sp/keywords/delete") == true && request.httpMethod == "POST" {
                return .notFound()
            }
            return .notFound()
        }

        do {
            try await client.archiveKeyword(keywordId: keywordId, profileId: profileId, region: region)
            XCTFail("Should have thrown 404 error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}
