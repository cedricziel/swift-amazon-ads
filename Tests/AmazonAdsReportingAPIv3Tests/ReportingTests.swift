//
//  ReportingTests.swift
//  AmazonAdsReportingAPIv3Tests
//
//  Tests for the Reporting API v3 client
//

import XCTest
@testable import AmazonAdsReportingAPIv3

final class ReportingTests: XCTestCase {

    func testModuleInfo() {
        XCTAssertEqual(AmazonAdsReportingAPIv3Info.apiVersion, "v3")
        XCTAssertFalse(AmazonAdsReportingAPIv3Info.moduleVersion.isEmpty)
    }

    func testReportPollingOptionsDefaults() {
        let options = ReportPollingOptions.default
        XCTAssertEqual(options.maxAttempts, 60)
        XCTAssertEqual(options.backoffMultiplier, 1.5)
    }
}
