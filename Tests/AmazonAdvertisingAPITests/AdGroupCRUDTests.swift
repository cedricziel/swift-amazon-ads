//
//  AdGroupCRUDTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for Sponsored Products Ad Group CRUD operations
//  Tests create, read, update, list, and archive operations
//

import XCTest
import Foundation
@testable import AmazonAdvertisingAPI

final class AdGroupCRUDTests: XCTestCase {

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

    func mockAdGroup(id: String = "ADGROUP123", name: String = "Test Ad Group", campaignId: String = "CAMPAIGN123") -> SponsoredProductsAdGroup {
        return SponsoredProductsAdGroup(
            adGroupId: id,
            name: name,
            campaignId: campaignId,
            state: .enabled,
            defaultBid: 1.50,
            tags: nil
        )
    }

    // MARK: - List Ad Groups Tests (2 tests)

    func testListAdGroupsReturnsAllAdGroups() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock successful ad groups response
        let adGroups = [mockAdGroup(id: "AG1"), mockAdGroup(id: "AG2")]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/adGroups") == true {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-ClientId"), "test_client_id")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.httpMethod, "GET")

                return .json(adGroups)
            }
            return .notFound()
        }

        let result = try await client.listAdGroups(campaignId: nil, profileId: profileId, region: region, stateFilter: nil)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].adGroupId, "AG1")
        XCTAssertEqual(result[1].adGroupId, "AG2")
    }

    func testListAdGroupsWithFilters() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock ad groups response
        let adGroups = [mockAdGroup()]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/adGroups") == true {
                // Verify query parameters
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
                let campaignIdParam = components?.queryItems?.first(where: { $0.name == "campaignIdFilter" })
                let stateFilterParam = components?.queryItems?.first(where: { $0.name == "stateFilter" })

                XCTAssertNotNil(campaignIdParam)
                XCTAssertEqual(campaignIdParam?.value, "CAMPAIGN123")
                XCTAssertNotNil(stateFilterParam)
                XCTAssertEqual(stateFilterParam?.value, "enabled")

                return .json(adGroups)
            }
            return .notFound()
        }

        let result = try await client.listAdGroups(
            campaignId: "CAMPAIGN123",
            profileId: profileId,
            region: region,
            stateFilter: [.enabled]
        )

        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Get Ad Group Tests (2 tests)

    func testGetAdGroupReturnsAdGroup() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let adGroupId = "ADGROUP123"

        // Mock successful ad group response
        let adGroup = mockAdGroup(id: adGroupId)
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/adGroups/\(adGroupId)") == true {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.httpMethod, "GET")

                return .json(adGroup)
            }
            return .notFound()
        }

        let result = try await client.getAdGroup(adGroupId: adGroupId, profileId: profileId, region: region)

        XCTAssertEqual(result.adGroupId, adGroupId)
        XCTAssertEqual(result.name, "Test Ad Group")
    }

    func testGetAdGroupHandlesNotFound() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let adGroupId = "NONEXISTENT"

        // Mock 404 Not Found response
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/adGroups/\(adGroupId)") == true {
                return .notFound()
            }
            return .notFound()
        }

        do {
            _ = try await client.getAdGroup(adGroupId: adGroupId, profileId: profileId, region: region)
            XCTFail("Should have thrown 404 error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Create Ad Group Tests (2 tests)

    func testCreateAdGroupReturnsCreatedAdGroup() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Ad group to create (without ID)
        let newAdGroup = SponsoredProductsAdGroup(
            adGroupId: nil,
            name: "New Ad Group",
            campaignId: "CAMPAIGN123",
            state: .enabled,
            defaultBid: 1.25,
            tags: nil
        )

        // Response with generated ID
        let createdAdGroup = mockAdGroup(id: "NEWAG123", name: "New Ad Group")

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/adGroups") == true && request.httpMethod == "POST" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

                return .json(createdAdGroup, statusCode: 201)
            }
            return .notFound()
        }

        let result = try await client.createAdGroup(adGroup: newAdGroup, profileId: profileId, region: region)

        XCTAssertEqual(result.adGroupId, "NEWAG123")
        XCTAssertEqual(result.name, "New Ad Group")
    }

    func testCreateAdGroupHandlesValidationError() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Invalid ad group (empty name)
        let newAdGroup = SponsoredProductsAdGroup(
            adGroupId: nil,
            name: "",
            campaignId: "CAMPAIGN123",
            state: .enabled,
            defaultBid: nil,
            tags: nil
        )

        // Mock 400 Bad Request
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/adGroups") == true && request.httpMethod == "POST" {
                return .httpError(statusCode: 400)
            }
            return .notFound()
        }

        do {
            _ = try await client.createAdGroup(adGroup: newAdGroup, profileId: profileId, region: region)
            XCTFail("Should have thrown validation error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Update Ad Group Tests (2 tests)

    func testUpdateAdGroupReturnsUpdatedAdGroup() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Ad group with updates
        var updatedAdGroup = mockAdGroup(id: "ADGROUP123", name: "Updated Name")
        updatedAdGroup.defaultBid = 2.00

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/adGroups/ADGROUP123") == true && request.httpMethod == "PUT" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

                return .json(updatedAdGroup)
            }
            return .notFound()
        }

        let result = try await client.updateAdGroup(adGroup: updatedAdGroup, profileId: profileId, region: region)

        XCTAssertEqual(result.adGroupId, "ADGROUP123")
        XCTAssertEqual(result.name, "Updated Name")
        XCTAssertEqual(result.defaultBid, 2.00)
    }

    func testUpdateAdGroupRequiresAdGroupId() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Ad group without ID
        let adGroupWithoutId = SponsoredProductsAdGroup(
            adGroupId: nil,
            name: "Test",
            campaignId: "CAMPAIGN123",
            state: .enabled,
            defaultBid: nil,
            tags: nil
        )

        do {
            _ = try await client.updateAdGroup(adGroup: adGroupWithoutId, profileId: profileId, region: region)
            XCTFail("Should have thrown invalid request error")
        } catch let error as AmazonAdvertisingError {
            if case .invalidRequest(let message) = error {
                XCTAssertTrue(message.contains("Ad Group ID is required"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Archive Ad Group Tests (2 tests)

    func testArchiveAdGroupSucceeds() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let adGroupId = "ADGROUP123"

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/adGroups/\(adGroupId)") == true && request.httpMethod == "DELETE" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)

                return .success(data: Data(), statusCode: 200)
            }
            return .notFound()
        }

        // Archive should complete without throwing
        try await client.archiveAdGroup(adGroupId: adGroupId, profileId: profileId, region: region)

        // Success - no assertion needed for void return
    }

    func testArchiveAdGroupHandlesNotFound() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let adGroupId = "NONEXISTENT"

        // Mock 404 Not Found
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/adGroups/\(adGroupId)") == true && request.httpMethod == "DELETE" {
                return .notFound()
            }
            return .notFound()
        }

        do {
            try await client.archiveAdGroup(adGroupId: adGroupId, profileId: profileId, region: region)
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
