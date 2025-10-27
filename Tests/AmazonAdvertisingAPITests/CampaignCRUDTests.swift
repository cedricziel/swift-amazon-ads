//
//  CampaignCRUDTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for Sponsored Products Campaign CRUD operations
//  Tests create, read, update, list, and archive operations
//

import XCTest
import Foundation
@testable import AmazonAdvertisingAPI

final class CampaignCRUDTests: XCTestCase {

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

    func mockCampaign(id: String = "CAMPAIGN123", name: String = "Test Campaign") -> SponsoredProductsCampaign {
        return SponsoredProductsCampaign(
            campaignId: id,
            name: name,
            state: .enabled,
            targetingType: .manual,
            budget: SponsoredProductsCampaign.Budget(amount: 10.0, budgetType: .daily),
            startDate: "20250101",
            endDate: nil,
            premiumBidAdjustment: true,
            bidding: CampaignBidding(strategy: .autoForSales),
            portfolioId: nil
        )
    }

    // MARK: - List Campaigns Tests (3 tests)

    func testListCampaignsReturnsAllCampaigns() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock successful campaigns response
        let campaigns = [mockCampaign(id: "CAMP1"), mockCampaign(id: "CAMP2")]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns") == true {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-ClientId"), "test_client_id")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.httpMethod, "GET")

                return .json(campaigns)
            }
            return .notFound()
        }

        let result = try await client.listCampaigns(profileId: profileId, region: region, stateFilter: nil)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].campaignId, "CAMP1")
        XCTAssertEqual(result[1].campaignId, "CAMP2")
    }

    func testListCampaignsWithStateFilter() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock campaigns response
        let campaigns = [mockCampaign()]
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns") == true {
                // Verify state filter query parameter
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
                let stateFilterParam = components?.queryItems?.first(where: { $0.name == "stateFilter" })
                XCTAssertNotNil(stateFilterParam)
                XCTAssertEqual(stateFilterParam?.value, "enabled,paused")

                return .json(campaigns)
            }
            return .notFound()
        }

        let result = try await client.listCampaigns(
            profileId: profileId,
            region: region,
            stateFilter: [.enabled, .paused]
        )

        XCTAssertEqual(result.count, 1)
    }

    func testListCampaignsHandlesHTTPError() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock 401 Unauthorized response
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns") == true {
                return .unauthorized()
            }
            return .notFound()
        }

        do {
            _ = try await client.listCampaigns(profileId: profileId, region: region, stateFilter: nil)
            XCTFail("Should have thrown HTTP error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 401)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Get Campaign Tests (2 tests)

    func testGetCampaignReturnsCampaign() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let campaignId = "CAMPAIGN123"

        // Mock successful campaign response
        let campaign = mockCampaign(id: campaignId)
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns/\(campaignId)") == true {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.httpMethod, "GET")

                return .json(campaign)
            }
            return .notFound()
        }

        let result = try await client.getCampaign(campaignId: campaignId, profileId: profileId, region: region)

        XCTAssertEqual(result.campaignId, campaignId)
        XCTAssertEqual(result.name, "Test Campaign")
    }

    func testGetCampaignHandlesNotFound() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let campaignId = "NONEXISTENT"

        // Mock 404 Not Found response
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns/\(campaignId)") == true {
                return .notFound()
            }
            return .notFound()
        }

        do {
            _ = try await client.getCampaign(campaignId: campaignId, profileId: profileId, region: region)
            XCTFail("Should have thrown 404 error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Create Campaign Tests (3 tests)

    func testCreateCampaignReturnsCreatedCampaign() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Campaign to create (without ID)
        var newCampaign = mockCampaign(id: "", name: "New Campaign")
        newCampaign = SponsoredProductsCampaign(
            campaignId: nil,
            name: newCampaign.name,
            state: newCampaign.state,
            targetingType: newCampaign.targetingType,
            budget: newCampaign.budget,
            startDate: newCampaign.startDate,
            endDate: newCampaign.endDate,
            premiumBidAdjustment: newCampaign.premiumBidAdjustment,
            bidding: newCampaign.bidding,
            portfolioId: newCampaign.portfolioId
        )

        // Response with generated ID
        let createdCampaign = mockCampaign(id: "NEWCAMP123", name: "New Campaign")

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns") == true && request.httpMethod == "POST" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

                return .json(createdCampaign, statusCode: 201)
            }
            return .notFound()
        }

        let result = try await client.createCampaign(campaign: newCampaign, profileId: profileId, region: region)

        XCTAssertEqual(result.campaignId, "NEWCAMP123")
        XCTAssertEqual(result.name, "New Campaign")
    }

    func testCreateCampaignHandles200Response() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let newCampaign = SponsoredProductsCampaign(
            campaignId: nil,
            name: "Test",
            state: .enabled,
            targetingType: .manual,
            budget: SponsoredProductsCampaign.Budget(amount: 10.0, budgetType: .daily),
            startDate: "20250101",
            endDate: nil,
            premiumBidAdjustment: nil,
            bidding: nil,
            portfolioId: nil
        )

        // Some APIs return 200 instead of 201
        let createdCampaign = mockCampaign(id: "NEWCAMP456")

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns") == true && request.httpMethod == "POST" {
                return .json(createdCampaign, statusCode: 200)
            }
            return .notFound()
        }

        let result = try await client.createCampaign(campaign: newCampaign, profileId: profileId, region: region)

        XCTAssertEqual(result.campaignId, "NEWCAMP456")
    }

    func testCreateCampaignHandlesValidationError() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let newCampaign = SponsoredProductsCampaign(
            campaignId: nil,
            name: "",  // Invalid empty name
            state: .enabled,
            targetingType: .manual,
            budget: SponsoredProductsCampaign.Budget(amount: 10.0, budgetType: .daily),
            startDate: "20250101",
            endDate: nil,
            premiumBidAdjustment: nil,
            bidding: nil,
            portfolioId: nil
        )

        // Mock 400 Bad Request
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns") == true && request.httpMethod == "POST" {
                return .httpError(statusCode: 400)
            }
            return .notFound()
        }

        do {
            _ = try await client.createCampaign(campaign: newCampaign, profileId: profileId, region: region)
            XCTFail("Should have thrown validation error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Update Campaign Tests (3 tests)

    func testUpdateCampaignReturnsUpdatedCampaign() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Campaign with updates
        var updatedCampaign = mockCampaign(id: "CAMPAIGN123", name: "Updated Name")
        updatedCampaign.budget = SponsoredProductsCampaign.Budget(amount: 20.0, budgetType: .daily)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns/CAMPAIGN123") == true && request.httpMethod == "PUT" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

                return .json(updatedCampaign)
            }
            return .notFound()
        }

        let result = try await client.updateCampaign(campaign: updatedCampaign, profileId: profileId, region: region)

        XCTAssertEqual(result.campaignId, "CAMPAIGN123")
        XCTAssertEqual(result.name, "Updated Name")
        XCTAssertEqual(result.budget.amount, 20.0)
    }

    func testUpdateCampaignRequiresCampaignId() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Campaign without ID
        let campaignWithoutId = SponsoredProductsCampaign(
            campaignId: nil,
            name: "Test",
            state: .enabled,
            targetingType: .manual,
            budget: SponsoredProductsCampaign.Budget(amount: 10.0, budgetType: .daily),
            startDate: "20250101",
            endDate: nil,
            premiumBidAdjustment: nil,
            bidding: nil,
            portfolioId: nil
        )

        do {
            _ = try await client.updateCampaign(campaign: campaignWithoutId, profileId: profileId, region: region)
            XCTFail("Should have thrown invalid request error")
        } catch let error as AmazonAdvertisingError {
            if case .invalidRequest(let message) = error {
                XCTAssertTrue(message.contains("Campaign ID is required"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testUpdateCampaignHandlesConflict() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let campaign = mockCampaign(id: "CAMPAIGN123")

        // Mock 409 Conflict (concurrent modification)
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns/CAMPAIGN123") == true && request.httpMethod == "PUT" {
                return .httpError(statusCode: 409)
            }
            return .notFound()
        }

        do {
            _ = try await client.updateCampaign(campaign: campaign, profileId: profileId, region: region)
            XCTFail("Should have thrown conflict error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 409)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Archive Campaign Tests (1 test)

    func testArchiveCampaignSucceeds() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let campaignId = "CAMPAIGN123"

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/campaigns/\(campaignId)") == true && request.httpMethod == "DELETE" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)

                return .success(data: Data(), statusCode: 200)
            }
            return .notFound()
        }

        // Archive should complete without throwing
        try await client.archiveCampaign(campaignId: campaignId, profileId: profileId, region: region)

        // Success - no assertion needed for void return
    }
}
