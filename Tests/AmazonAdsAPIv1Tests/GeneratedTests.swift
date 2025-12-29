//
//  GeneratedTests.swift
//  AmazonAdsAPIv1Tests
//
//  Placeholder tests for generated unified API v1 client
//

import Testing
@testable import AmazonAdsAPIv1

@Suite("Generated API v1 Tests")
struct GeneratedAPIv1Tests {
    @Test("Module info is available")
    func testModuleInfo() {
        #expect(AmazonAdsAPIv1Info.apiVersion == "v1")
        #expect(!AmazonAdsAPIv1Info.moduleVersion.isEmpty)
    }
}
