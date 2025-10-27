//
//  TargetCRUDTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for Sponsored Products Target CRUD operations
//  Tests create, list, update, and archive operations for product/category targeting
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

    // MARK: - List Targets Tests (2 tests)

    func testListTargetsReturnsAllTargets() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock successful targets response
        let targets = [mockTarget(id: "TG1"), mockTarget(id: "TG2")]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/targets") == true {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-ClientId"), "test_client_id")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.httpMethod, "GET")

                return .json(targets)
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

        // Mock targets response
        let targets = [mockTarget()]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/targets") == true {
                // Verify query parameters
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
                let adGroupIdParam = components?.queryItems?.first(where: { $0.name == "adGroupIdFilter" })
                let stateFilterParam = components?.queryItems?.first(where: { $0.name == "stateFilter" })

                XCTAssertNotNil(adGroupIdParam)
                XCTAssertEqual(adGroupIdParam?.value, "ADGROUP123")
                XCTAssertNotNil(stateFilterParam)
                XCTAssertEqual(stateFilterParam?.value, "enabled")

                return .json(targets)
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

    // MARK: - Create Target Tests (2 tests)

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

        // Response with generated ID
        let createdTarget = mockTarget(id: "NEWTG123")

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/targets") == true && request.httpMethod == "POST" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

                return .json(createdTarget, statusCode: 201)
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
            if request.url?.path.contains("/sp/targets") == true && request.httpMethod == "POST" {
                return .httpError(statusCode: 400)
            }
            return .notFound()
        }

        do {
            _ = try await client.createTarget(target: newTarget, profileId: profileId, region: region)
            XCTFail("Should have thrown validation error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Update Target Tests (2 tests)

    func testUpdateTargetReturnsUpdatedTarget() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Target with updates
        var updatedTarget = mockTarget(id: "TARGET123")
        updatedTarget.bid = 3.00
        updatedTarget.state = .paused

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/targets/TARGET123") == true && request.httpMethod == "PUT" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

                return .json(updatedTarget)
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

    // MARK: - Archive Target Tests (2 tests)

    func testArchiveTargetSucceeds() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let targetId = "TARGET123"

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/targets/\(targetId)") == true && request.httpMethod == "DELETE" {
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
            if request.url?.path.contains("/sp/targets/\(targetId)") == true && request.httpMethod == "DELETE" {
                return .notFound()
            }
            return .notFound()
        }

        do {
            try await client.archiveTarget(targetId: targetId, profileId: profileId, region: region)
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
