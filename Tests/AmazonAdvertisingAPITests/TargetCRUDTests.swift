//
//  TargetCRUDTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for Sponsored Products Target CRUD operations
//  Tests create, list, update, and archive operations for product/category targeting
//  Updated for V3 API patterns
//

import XCTest
import Foundation
@testable import AmazonAdvertisingAPI

final class TargetCRUDTests: XCTestCase {

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

    func mockTarget(
        id: String = "TARGET123",
        adGroupId: String = "ADGROUP123",
        campaignId: String = "CAMPAIGN123"
    ) -> SponsoredProductsTarget {
        return SponsoredProductsTarget(
            targetId: id,
            adGroupId: adGroupId,
            campaignId: campaignId,
            expression: [
                TargetExpression(type: "asinCategorySameAs", value: "B0TEST1234")
            ],
            expressionType: .auto,
            bid: 1.50,
            state: .enabled
        )
    }

    // MARK: - List Targets Tests (V3 API uses POST /sp/targets/list)

    func testListTargetsReturnsAllTargets() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock V3 list response
        let targets = [mockTarget(id: "TG1"), mockTarget(id: "TG2")]
        let listResponse = SPTargetListResponse(targetingClauses: targets, nextToken: nil, totalResults: 2)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/targets/list") == true {
                // V3 API uses POST for list
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-ClientId"), "test_client_id")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)

                return .json(listResponse)
            }
            return .notFound()
        }

        let result = try await client.listTargets(
            adGroupId: nil,
            profileId: profileId,
            region: region,
            stateFilter: nil
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].targetId, "TG1")
        XCTAssertEqual(result[1].targetId, "TG2")
    }

    func testListTargetsWithFilters() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock V3 list response
        let targets = [mockTarget()]
        let listResponse = SPTargetListResponse(targetingClauses: targets, nextToken: nil, totalResults: 1)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/targets/list") == true {
                // V3 API sends filter in POST body, not query parameters
                XCTAssertEqual(request.httpMethod, "POST")

                return .json(listResponse)
            }
            return .notFound()
        }

        let result = try await client.listTargets(
            adGroupId: "ADGROUP123",
            profileId: profileId,
            region: region,
            stateFilter: [.enabled]
        )

        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Create Target Tests (V3 API returns batch response with 207)

    func testCreateTargetReturnsCreatedTarget() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Target to create (without ID)
        let newTarget = SponsoredProductsTarget(
            targetId: nil,
            adGroupId: "ADGROUP123",
            campaignId: "CAMPAIGN123",
            expression: [
                TargetExpression(type: "asinCategorySameAs", value: "B0NEWASIN99")
            ],
            expressionType: .auto,
            bid: 2.00,
            state: .enabled
        )

        // V3 Response with batch wrapper
        let createdTarget = mockTarget(id: "NEWTG123")
        let successItem = SPTargetSuccessItem(targetingClause: createdTarget, targetId: "NEWTG123", index: 0)
        let batchResult = SPTargetBatchResult(success: [successItem], error: [])
        let batchResponse = SPTargetBatchResponse(targetingClauses: batchResult)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/sp/targets" && request.httpMethod == "POST" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                // V3 API uses versioned content type
                XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("application/vnd.spTargetingClause.v3+json") == true)

                // V3 API returns 207 Multi-Status
                return .json(batchResponse, statusCode: 207)
            }
            return .notFound()
        }

        let result = try await client.createTarget(target: newTarget, profileId: profileId, region: region)

        XCTAssertEqual(result.targetId, "NEWTG123")
    }

    func testCreateTargetHandlesValidationError() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Invalid target (empty expression)
        let newTarget = SponsoredProductsTarget(
            targetId: nil,
            adGroupId: "ADGROUP123",
            campaignId: "CAMPAIGN123",
            expression: [],
            expressionType: .auto,
            bid: nil,
            state: .enabled
        )

        // Mock 400 Bad Request
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/sp/targets" && request.httpMethod == "POST" {
                return .httpError(statusCode: 400)
            }
            return .notFound()
        }

        do {
            _ = try await client.createTarget(target: newTarget, profileId: profileId, region: region)
            XCTFail("Should have thrown validation error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Update Target Tests (V3 API uses batch PUT)

    func testUpdateTargetReturnsUpdatedTarget() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Target with updates
        var updatedTarget = mockTarget(id: "TARGET123")
        updatedTarget.bid = 3.00
        updatedTarget.state = .paused

        // V3 batch response
        let successItem = SPTargetSuccessItem(targetingClause: updatedTarget, targetId: "TARGET123", index: 0)
        let batchResult = SPTargetBatchResult(success: [successItem], error: [])
        let batchResponse = SPTargetBatchResponse(targetingClauses: batchResult)

        MockURLProtocol.setRequestHandler { request in
            // V3 uses PUT to /sp/targets for batch update
            if request.url?.path == "/sp/targets" && request.httpMethod == "PUT" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("application/vnd.spTargetingClause.v3+json") == true)

                return .json(batchResponse, statusCode: 207)
            }
            return .notFound()
        }

        let result = try await client.updateTarget(target: updatedTarget, profileId: profileId, region: region)

        XCTAssertEqual(result.targetId, "TARGET123")
        XCTAssertEqual(result.bid, 3.00)
        XCTAssertEqual(result.state, .paused)
    }

    func testUpdateTargetRequiresTargetId() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Target without ID
        let targetWithoutId = SponsoredProductsTarget(
            targetId: nil,
            adGroupId: "ADGROUP123",
            campaignId: "CAMPAIGN123",
            expression: [
                TargetExpression(type: "asinCategorySameAs", value: "B0TEST1234")
            ],
            expressionType: .auto,
            bid: nil,
            state: .enabled
        )

        do {
            _ = try await client.updateTarget(target: targetWithoutId, profileId: profileId, region: region)
            XCTFail("Should have thrown invalid request error")
        } catch let error as AmazonAdvertisingError {
            if case .invalidRequest(let message) = error {
                XCTAssertTrue(message.contains("Target ID is required"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Archive Target Tests (V3 uses POST to /sp/targets/delete)

    func testArchiveTargetSucceeds() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let targetId = "TARGET123"

        MockURLProtocol.setRequestHandler { request in
            // V3 API uses POST to /delete endpoint
            if request.url?.path.contains("/sp/targets/delete") == true && request.httpMethod == "POST" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)

                return .success(data: Data(), statusCode: 200)
            }
            return .notFound()
        }

        // Archive should complete without throwing
        try await client.archiveTarget(targetId: targetId, profileId: profileId, region: region)

        // Success - no assertion needed for void return
    }

    func testArchiveTargetHandlesNotFound() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let targetId = "NONEXISTENT"

        // Mock 404 Not Found
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/targets/delete") == true && request.httpMethod == "POST" {
                return .notFound()
            }
            return .notFound()
        }

        do {
            try await client.archiveTarget(targetId: targetId, profileId: profileId, region: region)
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
