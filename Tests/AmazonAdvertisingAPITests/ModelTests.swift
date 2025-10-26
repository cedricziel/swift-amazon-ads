//
//  ModelTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for API models
//

import XCTest
import Foundation
@testable import AmazonAdvertisingAPI

final class ModelTests: XCTestCase {
    func testTokenResponseCalculatesExpiryDateCorrectly() {
        let beforeDate = Date()
        let tokenResponse = AmazonTokenResponse(
            accessToken: "test_token",
            tokenType: "bearer",
            expiresIn: 3600,
            refreshToken: "refresh_token",
            scope: "profile"
        )
        let expiryDate = tokenResponse.expiryDate()
        let afterDate = Date().addingTimeInterval(3600)

        // Expiry date should be approximately 1 hour from now
        XCTAssertTrue(expiryDate > beforeDate)
        XCTAssertTrue(expiryDate <= afterDate.addingTimeInterval(1)) // Allow 1 second tolerance
    }

    func testRegionProvidesCorrectDisplayNames() {
        XCTAssertEqual(AmazonRegion.northAmerica.displayName, "North America")
        XCTAssertEqual(AmazonRegion.europe.displayName, "Europe")
        XCTAssertEqual(AmazonRegion.farEast.displayName, "Far East")
    }

    func testRegionProvidesCorrectAPIEndpoints() {
        XCTAssertEqual(AmazonRegion.northAmerica.advertisingAPIBaseURL.absoluteString, "https://advertising-api.amazon.com")
        XCTAssertEqual(AmazonRegion.europe.advertisingAPIBaseURL.absoluteString, "https://advertising-api-eu.amazon.com")
        XCTAssertEqual(AmazonRegion.farEast.advertisingAPIBaseURL.absoluteString, "https://advertising-api-fe.amazon.com")
    }

    func testProfileCanBeEncodedAndDecoded() throws {
        let profile = AmazonProfile(
            profileId: "123456",
            countryCode: "US",
            currencyCode: "USD",
            timezone: "America/Los_Angeles",
            accountInfo: AmazonAccountInfo(
                id: "789",
                type: "seller",
                name: "Test Account",
                validPaymentMethod: true
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AmazonProfile.self, from: data)

        XCTAssertEqual(decoded.profileId, profile.profileId)
        XCTAssertEqual(decoded.countryCode, profile.countryCode)
        XCTAssertEqual(decoded.accountInfo.name, profile.accountInfo.name)
    }

    func testManagerAccountCanBeEncodedAndDecoded() throws {
        let managerAccount = AmazonManagerAccount(
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

        let encoder = JSONEncoder()
        let data = try encoder.encode(managerAccount)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AmazonManagerAccount.self, from: data)

        XCTAssertEqual(decoded.managerAccountId, managerAccount.managerAccountId)
        XCTAssertEqual(decoded.linkedAccounts.count, 1)
        XCTAssertEqual(decoded.linkedAccounts[0].profileId, "P456")
    }
}
