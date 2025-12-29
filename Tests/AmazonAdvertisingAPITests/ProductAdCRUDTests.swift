//
//  ProductAdCRUDTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for Sponsored Products Product Ad CRUD operations
//  Tests create, list, update, and archive operations
//  Updated for V3 API patterns
//

import XCTest
import Foundation
@testable import AmazonAdvertisingAPI

final class ProductAdCRUDTests: XCTestCase {

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

    func mockProductAd(
        id: String = "AD123",
        adGroupId: String = "ADGROUP123",
        campaignId: String = "CAMPAIGN123",
        asin: String = "B0TEST1234"
    ) -> SponsoredProductsProductAd {
        return SponsoredProductsProductAd(
            adId: id,
            adGroupId: adGroupId,
            campaignId: campaignId,
            asin: asin,
            sku: "TEST-SKU-001",
            state: .enabled
        )
    }

    // MARK: - List Product Ads Tests (V3 API uses POST /sp/productAds/list)

    func testListProductAdsReturnsAllAds() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock V3 list response
        let productAds = [mockProductAd(id: "AD1"), mockProductAd(id: "AD2")]
        let listResponse = SPProductAdListResponse(productAds: productAds, nextToken: nil, totalResults: 2)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/productAds/list") == true {
                // V3 API uses POST for list
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-ClientId"), "test_client_id")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)

                return .json(listResponse)
            }
            return .notFound()
        }

        let result = try await client.listProductAds(
            adGroupId: nil,
            profileId: profileId,
            region: region,
            stateFilter: nil
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].adId, "AD1")
        XCTAssertEqual(result[1].adId, "AD2")
    }

    func testListProductAdsWithFilters() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Mock V3 list response
        let productAds = [mockProductAd()]
        let listResponse = SPProductAdListResponse(productAds: productAds, nextToken: nil, totalResults: 1)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/productAds/list") == true {
                // V3 API sends filter in POST body, not query parameters
                XCTAssertEqual(request.httpMethod, "POST")

                return .json(listResponse)
            }
            return .notFound()
        }

        let result = try await client.listProductAds(
            adGroupId: "ADGROUP123",
            profileId: profileId,
            region: region,
            stateFilter: [.enabled]
        )

        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Create Product Ad Tests (V3 API returns batch response with 207)

    func testCreateProductAdReturnsCreatedAd() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Product ad to create (without ID)
        let newProductAd = SponsoredProductsProductAd(
            adId: nil,
            adGroupId: "ADGROUP123",
            campaignId: "CAMPAIGN123",
            asin: "B0NEWASIN99",
            sku: "NEW-SKU-001",
            state: .enabled
        )

        // V3 Response with batch wrapper
        let createdProductAd = mockProductAd(id: "NEWAD123", asin: "B0NEWASIN99")
        let successItem = SPProductAdSuccessItem(productAd: createdProductAd, adId: "NEWAD123", index: 0)
        let batchResult = SPProductAdBatchResult(success: [successItem], error: [])
        let batchResponse = SPProductAdBatchResponse(productAds: batchResult)

        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/sp/productAds" && request.httpMethod == "POST" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                // V3 API uses versioned content type
                XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("application/vnd.spProductAd.v3+json") == true)

                // V3 API returns 207 Multi-Status
                return .json(batchResponse, statusCode: 207)
            }
            return .notFound()
        }

        let result = try await client.createProductAd(productAd: newProductAd, profileId: profileId, region: region)

        XCTAssertEqual(result.adId, "NEWAD123")
        XCTAssertEqual(result.asin, "B0NEWASIN99")
    }

    func testCreateProductAdHandlesValidationError() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Invalid product ad (empty ASIN)
        let newProductAd = SponsoredProductsProductAd(
            adId: nil,
            adGroupId: "ADGROUP123",
            campaignId: "CAMPAIGN123",
            asin: "",
            sku: nil,
            state: .enabled
        )

        // Mock 400 Bad Request
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/sp/productAds" && request.httpMethod == "POST" {
                return .httpError(statusCode: 400)
            }
            return .notFound()
        }

        do {
            _ = try await client.createProductAd(productAd: newProductAd, profileId: profileId, region: region)
            XCTFail("Should have thrown validation error")
        } catch let error as AmazonAdvertisingError {
            if case .httpError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Update Product Ad Tests (V3 API uses batch PUT)

    func testUpdateProductAdReturnsUpdatedAd() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Product ad with updates
        var updatedProductAd = mockProductAd(id: "AD123")
        updatedProductAd.state = .paused

        // V3 batch response
        let successItem = SPProductAdSuccessItem(productAd: updatedProductAd, adId: "AD123", index: 0)
        let batchResult = SPProductAdBatchResult(success: [successItem], error: [])
        let batchResponse = SPProductAdBatchResponse(productAds: batchResult)

        MockURLProtocol.setRequestHandler { request in
            // V3 uses PUT to /sp/productAds for batch update
            if request.url?.path == "/sp/productAds" && request.httpMethod == "PUT" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)
                XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("application/vnd.spProductAd.v3+json") == true)

                return .json(batchResponse, statusCode: 207)
            }
            return .notFound()
        }

        let result = try await client.updateProductAd(productAd: updatedProductAd, profileId: profileId, region: region)

        XCTAssertEqual(result.adId, "AD123")
        XCTAssertEqual(result.state, .paused)
    }

    func testUpdateProductAdRequiresAdId() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"

        // Product ad without ID
        let productAdWithoutId = SponsoredProductsProductAd(
            adId: nil,
            adGroupId: "ADGROUP123",
            campaignId: "CAMPAIGN123",
            asin: "B0TEST1234",
            sku: nil,
            state: .enabled
        )

        do {
            _ = try await client.updateProductAd(productAd: productAdWithoutId, profileId: profileId, region: region)
            XCTFail("Should have thrown invalid request error")
        } catch let error as AmazonAdvertisingError {
            if case .invalidRequest(let message) = error {
                XCTAssertTrue(message.contains("Product Ad ID is required"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Archive Product Ad Tests (V3 uses POST to /sp/productAds/delete)

    func testArchiveProductAdSucceeds() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let adId = "AD123"

        MockURLProtocol.setRequestHandler { request in
            // V3 API uses POST to /delete endpoint
            if request.url?.path.contains("/sp/productAds/delete") == true && request.httpMethod == "POST" {
                // Verify headers
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Amazon-Advertising-API-Scope"), profileId)

                return .success(data: Data(), statusCode: 200)
            }
            return .notFound()
        }

        // Archive should complete without throwing
        try await client.archiveProductAd(adId: adId, profileId: profileId, region: region)

        // Success - no assertion needed for void return
    }

    func testArchiveProductAdHandlesNotFound() async throws {
        let region = AmazonRegion.northAmerica
        let profileId = "PROFILE123"
        let adId = "NONEXISTENT"

        // Mock 404 Not Found
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path.contains("/sp/productAds/delete") == true && request.httpMethod == "POST" {
                return .notFound()
            }
            return .notFound()
        }

        do {
            try await client.archiveProductAd(adId: adId, profileId: profileId, region: region)
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
