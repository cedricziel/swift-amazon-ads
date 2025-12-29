//
//  LegacyTests.swift
//  LegacyAmazonAdsSponsoredProductsAPIv3Tests
//
//  Tests for legacy SP v3 handwritten client
//

import Testing
@testable import LegacyAmazonAdsSponsoredProductsAPIv3

@Suite("LegacySponsoredProducts Tests")
struct LegacySponsoredProductsTests {
    @Test("CampaignState has correct raw values")
    func testCampaignStates() {
        #expect(CampaignState.enabled.rawValue == "ENABLED")
        #expect(CampaignState.paused.rawValue == "PAUSED")
        #expect(CampaignState.archived.rawValue == "ARCHIVED")
    }

    @Test("SPMediaType provides correct header values")
    func testMediaTypes() {
        #expect(SPMediaType.campaign.headerValue == "application/vnd.spCampaign.v3+json")
        #expect(SPMediaType.adGroup.headerValue == "application/vnd.spAdGroup.v3+json")
    }
}
