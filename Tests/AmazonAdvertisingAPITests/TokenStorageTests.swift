//
//  TokenStorageTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for token storage implementations
//

import XCTest
@testable import AmazonAdvertisingAPI

final class TokenStorageTests: XCTestCase {
    func testInMemoryStorageStoresAndRetrievesValues() async throws {
        let storage = InMemoryTokenStorage()
        let region = AmazonRegion.northAmerica
        let key = "test_key"
        let value = "test_value"

        // Save value
        try await storage.save(value, for: key, region: region)

        // Check exists
        let exists = await storage.exists(for: key, region: region)
        XCTAssertTrue(exists)

        // Retrieve value
        let retrieved = try await storage.retrieve(for: key, region: region)
        XCTAssertEqual(retrieved, value)

        // Delete value
        try await storage.delete(for: key, region: region)

        // Check not exists
        let existsAfterDelete = await storage.exists(for: key, region: region)
        XCTAssertFalse(existsAfterDelete)
    }

    func testInMemoryStorageDeletesAllValuesForRegion() async throws {
        let storage = InMemoryTokenStorage()
        let region1 = AmazonRegion.northAmerica
        let region2 = AmazonRegion.europe

        // Save values for different regions
        try await storage.save("value1", for: "key1", region: region1)
        try await storage.save("value2", for: "key2", region: region1)
        try await storage.save("value3", for: "key1", region: region2)

        // Delete all for region1
        try await storage.deleteAll(for: region1)

        // Check region1 values are deleted
        let exists1 = await storage.exists(for: "key1", region: region1)
        let exists2 = await storage.exists(for: "key2", region: region1)
        XCTAssertFalse(exists1)
        XCTAssertFalse(exists2)

        // Check region2 value still exists
        let exists3 = await storage.exists(for: "key1", region: region2)
        XCTAssertTrue(exists3)
    }

    func testRetrieveThrowsErrorForMissingValue() async throws {
        let storage = InMemoryTokenStorage()
        let region = AmazonRegion.northAmerica

        // Try to retrieve non-existent value
        do {
            _ = try await storage.retrieve(for: "nonexistent", region: region)
            XCTFail("Should have thrown TokenStorageError")
        } catch is TokenStorageError {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
