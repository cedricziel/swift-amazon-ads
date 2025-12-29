//
//  AmazonAdsCoreTests.swift
//  AmazonAdsCoreTests
//
//  Tests for AmazonAdsCore shared functionality
//

import Testing
@testable import AmazonAdsCore

@Suite("AmazonAdsCore Tests")
struct AmazonAdsCoreTests {
    @Test("AmazonRegion provides correct endpoints")
    func testRegionEndpoints() {
        let region = AmazonRegion.northAmerica
        #expect(region.advertisingAPIBaseURL.absoluteString.contains("advertising-api.amazon.com"))
    }

    @Test("TokenStorageKey provides correct keys")
    func testTokenStorageKeys() {
        #expect(TokenStorageKey.accessToken == "amazon_access_token")
        #expect(TokenStorageKey.refreshToken == "amazon_refresh_token")
        #expect(TokenStorageKey.tokenExpiry == "amazon_token_expiry")
    }
}
