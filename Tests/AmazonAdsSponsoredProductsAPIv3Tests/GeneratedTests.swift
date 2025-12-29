//
//  GeneratedTests.swift
//  AmazonAdsSponsoredProductsAPIv3Tests
//
//  Tests for generated SP v3 client and extensions
//

import Testing
import AmazonAdsCore
@testable import AmazonAdsSponsoredProductsAPIv3

@Suite("Generated SP v3 Tests")
struct GeneratedSPv3Tests {
    @Test("Module info is available")
    func testModuleInfo() {
        #expect(AmazonAdsSponsoredProductsAPIv3Info.apiVersion == "v3")
        #expect(!AmazonAdsSponsoredProductsAPIv3Info.moduleVersion.isEmpty)
    }

    @Test("Type aliases are accessible")
    func testTypeAliases() {
        // Verify type aliases compile and reference correct types
        let _: SponsoredProductsClient.Type = Client.self
        let _: SponsoredProductsTypes.Type = Components.Schemas.self
        let _: SponsoredProductsOperations.Type = Operations.self
    }

    @Test("Client factory creates client for each region")
    func testClientFactory() {
        for region in AmazonRegion.allCases {
            let client = SponsoredProductsClient.make(
                region: region,
                tokenProvider: { "test-token" },
                clientId: "test-client-id",
                profileId: "test-profile-id"
            )
            #expect(client != nil)
        }
    }

    @Test("Dynamic profile client factory works")
    func testDynamicProfileClientFactory() {
        let (client, transport) = SponsoredProductsClient.makeWithDynamicProfile(
            region: .northAmerica,
            tokenProvider: { "test-token" },
            clientId: "test-client-id",
            profileId: "initial-profile"
        )

        #expect(client != nil)
        #expect(transport.profileId == "initial-profile")

        // Can change profile
        transport.profileId = "new-profile"
        #expect(transport.profileId == "new-profile")
    }
}
