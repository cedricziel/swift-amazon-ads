//
//  TokenStorageTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for token storage implementations
//

import Testing
@testable import AmazonAdvertisingAPI

@Suite("Token Storage Tests")
struct TokenStorageTests {
    @Test("InMemoryTokenStorage stores and retrieves values")
    func testInMemoryStorage() async throws {
        let storage = InMemoryTokenStorage()
        let region = AmazonRegion.northAmerica
        let key = "test_key"
        let value = "test_value"

        // Save value
        try await storage.save(value, for: key, region: region)

        // Check exists
        let exists = await storage.exists(for: key, region: region)
        #expect(exists == true)

        // Retrieve value
        let retrieved = try await storage.retrieve(for: key, region: region)
        #expect(retrieved == value)

        // Delete value
        try await storage.delete(for: key, region: region)

        // Check not exists
        let existsAfterDelete = await storage.exists(for: key, region: region)
        #expect(existsAfterDelete == false)
    }

    @Test("InMemoryTokenStorage deletes all values for a region")
    func testDeleteAllForRegion() async throws {
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
        #expect(exists1 == false)
        #expect(exists2 == false)

        // Check region2 value still exists
        let exists3 = await storage.exists(for: "key1", region: region2)
        #expect(exists3 == true)
    }

    @Test("InMemoryTokenStorage throws error for missing value")
    func testRetrieveThrowsForMissingValue() async throws {
        let storage = InMemoryTokenStorage()
        let region = AmazonRegion.northAmerica

        // Try to retrieve non-existent value
        await #expect(throws: TokenStorageError.self) {
            _ = try await storage.retrieve(for: "nonexistent", region: region)
        }
    }
}
