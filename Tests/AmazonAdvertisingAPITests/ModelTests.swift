//
//  ModelTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for API models
//

import Testing
import Foundation
@testable import AmazonAdvertisingAPI

@Suite("Model Tests")
struct ModelTests {
    @Test("AmazonTokenResponse calculates expiry date correctly")
    func testTokenResponseExpiryDate() {
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
        #expect(expiryDate > beforeDate)
        #expect(expiryDate <= afterDate.addingTimeInterval(1)) // Allow 1 second tolerance
    }

    @Test("AmazonRegion provides correct display names")
    func testRegionDisplayNames() {
        #expect(AmazonRegion.northAmerica.displayName == "North America")
        #expect(AmazonRegion.europe.displayName == "Europe")
        #expect(AmazonRegion.farEast.displayName == "Far East")
    }

    @Test("AmazonRegion provides correct API endpoints")
    func testRegionEndpoints() {
        #expect(AmazonRegion.northAmerica.advertisingAPIBaseURL.absoluteString == "https://advertising-api.amazon.com")
        #expect(AmazonRegion.europe.advertisingAPIBaseURL.absoluteString == "https://advertising-api-eu.amazon.com")
        #expect(AmazonRegion.farEast.advertisingAPIBaseURL.absoluteString == "https://advertising-api-fe.amazon.com")
    }

    @Test("AmazonProfile can be encoded and decoded")
    func testProfileCodable() throws {
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

        #expect(decoded.profileId == profile.profileId)
        #expect(decoded.countryCode == profile.countryCode)
        #expect(decoded.accountInfo.name == profile.accountInfo.name)
    }

    @Test("AmazonManagerAccount can be encoded and decoded")
    func testManagerAccountCodable() throws {
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

        #expect(decoded.managerAccountId == managerAccount.managerAccountId)
        #expect(decoded.linkedAccounts.count == 1)
        #expect(decoded.linkedAccounts[0].profileId == "P456")
    }
}
