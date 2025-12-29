//
//  GeneratedTests.swift
//  AmazonAdsAccountsTests
//
//  Placeholder tests for generated Accounts API client
//

import Testing
@testable import AmazonAdsAccounts

@Suite("Generated Accounts Tests")
struct GeneratedAccountsTests {
    @Test("Module info is available")
    func testModuleInfo() {
        #expect(!AmazonAdsAccountsInfo.moduleVersion.isEmpty)
    }
}
