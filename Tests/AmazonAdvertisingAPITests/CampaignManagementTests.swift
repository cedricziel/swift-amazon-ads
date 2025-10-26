//
//  CampaignManagementTests.swift
//  AmazonAdvertisingAPITests
//
//  Tests for Campaign Management API models
//

import XCTest
import Foundation
@testable import AmazonAdvertisingAPI

final class CampaignManagementTests: XCTestCase {

    // MARK: - Campaign Tests

    func testCampaignCanBeEncodedAndDecoded() throws {
        let campaign = SponsoredProductsCampaign(
            campaignId: "123456",
            name: "Test Campaign",
            state: .enabled,
            targetingType: .manual,
            budget: .daily(50.00),
            startDate: "20250101",
            endDate: "20250331",
            premiumBidAdjustment: true,
            bidding: CampaignBidding(
                strategy: .autoForSales,
                adjustments: [
                    BidAdjustment(predicate: .placementTop, percentage: 50)
                ]
            ),
            portfolioId: "PORT123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(campaign)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SponsoredProductsCampaign.self, from: data)

        XCTAssertEqual(decoded.campaignId, campaign.campaignId)
        XCTAssertEqual(decoded.name, campaign.name)
        XCTAssertEqual(decoded.state, .enabled)
        XCTAssertEqual(decoded.targetingType, .manual)
        XCTAssertEqual(decoded.budget.amount, 50.00)
        XCTAssertEqual(decoded.startDate, "20250101")
        XCTAssertEqual(decoded.endDate, "20250331")
        XCTAssertEqual(decoded.premiumBidAdjustment, true)
        XCTAssertEqual(decoded.bidding?.strategy, .autoForSales)
        XCTAssertEqual(decoded.bidding?.adjustments?.count, 1)
        XCTAssertEqual(decoded.portfolioId, "PORT123")
    }

    func testCampaignWithDatesConvertsCorrectly() {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 3, to: startDate)!

        let campaign = SponsoredProductsCampaign.withDates(
            name: "Date Test Campaign",
            budget: .daily(25.00),
            startDate: startDate,
            endDate: endDate
        )

        XCTAssertNotNil(campaign.parsedStartDate)
        XCTAssertNotNil(campaign.parsedEndDate)

        // Dates should be within same day (ignoring time)
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDate(campaign.parsedStartDate!, inSameDayAs: startDate))
        XCTAssertTrue(calendar.isDate(campaign.parsedEndDate!, inSameDayAs: endDate))
    }

    func testCampaignStateEnumValues() {
        XCTAssertEqual(CampaignState.enabled.rawValue, "enabled")
        XCTAssertEqual(CampaignState.paused.rawValue, "paused")
        XCTAssertEqual(CampaignState.archived.rawValue, "archived")
    }

    func testTargetingTypeEnumValues() {
        XCTAssertEqual(TargetingType.manual.rawValue, "manual")
        XCTAssertEqual(TargetingType.auto.rawValue, "auto")
    }

    func testBiddingStrategyEnumValues() {
        XCTAssertEqual(BiddingStrategy.legacyForSales.rawValue, "legacyForSales")
        XCTAssertEqual(BiddingStrategy.autoForSales.rawValue, "autoForSales")
        XCTAssertEqual(BiddingStrategy.manual.rawValue, "manual")
    }

    func testDailyBudgetConvenience() {
        let budget = SponsoredProductsCampaign.Budget.daily(100.50)
        XCTAssertEqual(budget.amount, 100.50)
        XCTAssertEqual(budget.budgetType, .daily)
    }

    // MARK: - Ad Group Tests

    func testAdGroupCanBeEncodedAndDecoded() throws {
        let adGroup = SponsoredProductsAdGroup(
            adGroupId: "AG123",
            name: "Test Ad Group",
            campaignId: "C456",
            state: .enabled,
            defaultBid: 0.75
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(adGroup)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SponsoredProductsAdGroup.self, from: data)

        XCTAssertEqual(decoded.adGroupId, "AG123")
        XCTAssertEqual(decoded.name, "Test Ad Group")
        XCTAssertEqual(decoded.campaignId, "C456")
        XCTAssertEqual(decoded.state, .enabled)
        XCTAssertEqual(decoded.defaultBid, 0.75)
    }

    func testAdGroupStateEnumValues() {
        XCTAssertEqual(AdGroupState.enabled.rawValue, "enabled")
        XCTAssertEqual(AdGroupState.paused.rawValue, "paused")
        XCTAssertEqual(AdGroupState.archived.rawValue, "archived")
    }

    // MARK: - Product Ad Tests

    func testProductAdCanBeEncodedAndDecoded() throws {
        let productAd = SponsoredProductsProductAd(
            adId: "AD123",
            adGroupId: "AG456",
            campaignId: "C789",
            asin: "B07TESTASN",
            sku: "SKU-123",
            state: .enabled
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(productAd)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SponsoredProductsProductAd.self, from: data)

        XCTAssertEqual(decoded.adId, "AD123")
        XCTAssertEqual(decoded.adGroupId, "AG456")
        XCTAssertEqual(decoded.campaignId, "C789")
        XCTAssertEqual(decoded.asin, "B07TESTASN")
        XCTAssertEqual(decoded.sku, "SKU-123")
        XCTAssertEqual(decoded.state, .enabled)
    }

    func testProductAdStateEnumValues() {
        XCTAssertEqual(ProductAdState.enabled.rawValue, "enabled")
        XCTAssertEqual(ProductAdState.paused.rawValue, "paused")
        XCTAssertEqual(ProductAdState.archived.rawValue, "archived")
    }

    // MARK: - Keyword Tests

    func testKeywordCanBeEncodedAndDecoded() throws {
        let keyword = SponsoredProductsKeyword(
            keywordId: "KW123",
            adGroupId: "AG456",
            campaignId: "C789",
            keywordText: "funny t-shirt",
            matchType: .phrase,
            bid: 0.85,
            state: .enabled
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(keyword)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SponsoredProductsKeyword.self, from: data)

        XCTAssertEqual(decoded.keywordId, "KW123")
        XCTAssertEqual(decoded.adGroupId, "AG456")
        XCTAssertEqual(decoded.campaignId, "C789")
        XCTAssertEqual(decoded.keywordText, "funny t-shirt")
        XCTAssertEqual(decoded.matchType, .phrase)
        XCTAssertEqual(decoded.bid, 0.85)
        XCTAssertEqual(decoded.state, .enabled)
    }

    func testKeywordMatchTypeEnumValues() {
        XCTAssertEqual(KeywordMatchType.exact.rawValue, "exact")
        XCTAssertEqual(KeywordMatchType.phrase.rawValue, "phrase")
        XCTAssertEqual(KeywordMatchType.broad.rawValue, "broad")
    }

    func testKeywordStateEnumValues() {
        XCTAssertEqual(KeywordState.enabled.rawValue, "enabled")
        XCTAssertEqual(KeywordState.paused.rawValue, "paused")
        XCTAssertEqual(KeywordState.archived.rawValue, "archived")
    }

    func testNegativeKeywordMatchTypeEnumValues() {
        XCTAssertEqual(NegativeKeywordMatchType.negativeExact.rawValue, "negativeExact")
        XCTAssertEqual(NegativeKeywordMatchType.negativePhrase.rawValue, "negativePhrase")
    }

    // MARK: - Target Tests

    func testTargetCanBeEncodedAndDecoded() throws {
        let target = SponsoredProductsTarget(
            targetId: "T123",
            adGroupId: "AG456",
            campaignId: "C789",
            expression: [
                TargetExpression(type: "asinSameAs", value: "B07TESTASN")
            ],
            expressionType: .manual,
            bid: 1.25,
            state: .enabled
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(target)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SponsoredProductsTarget.self, from: data)

        XCTAssertEqual(decoded.targetId, "T123")
        XCTAssertEqual(decoded.adGroupId, "AG456")
        XCTAssertEqual(decoded.campaignId, "C789")
        XCTAssertEqual(decoded.expression.count, 1)
        XCTAssertEqual(decoded.expression[0].type, "asinSameAs")
        XCTAssertEqual(decoded.expression[0].value, "B07TESTASN")
        XCTAssertEqual(decoded.expressionType, .manual)
        XCTAssertEqual(decoded.bid, 1.25)
        XCTAssertEqual(decoded.state, .enabled)
    }

    func testTargetExpressionConvenienceConstructors() {
        let asinTarget = TargetExpression.asin("B07TEST123")
        XCTAssertEqual(asinTarget.type, "asinSameAs")
        XCTAssertEqual(asinTarget.value, "B07TEST123")

        let categoryTarget = TargetExpression.category("B07CATEGORY")
        XCTAssertEqual(categoryTarget.type, "asinCategorySameAs")
        XCTAssertEqual(categoryTarget.value, "B07CATEGORY")

        let expandedTarget = TargetExpression.expanded("B07EXPANDED")
        XCTAssertEqual(expandedTarget.type, "asinExpandedFrom")
        XCTAssertEqual(expandedTarget.value, "B07EXPANDED")
    }

    func testTargetStateEnumValues() {
        XCTAssertEqual(TargetState.enabled.rawValue, "enabled")
        XCTAssertEqual(TargetState.paused.rawValue, "paused")
        XCTAssertEqual(TargetState.archived.rawValue, "archived")
    }

    func testTargetExpressionTypeEnumValues() {
        XCTAssertEqual(TargetExpressionType.manual.rawValue, "manual")
        XCTAssertEqual(TargetExpressionType.auto.rawValue, "auto")
    }

    // MARK: - Bid Adjustment Tests

    func testBidAdjustmentCanBeEncodedAndDecoded() throws {
        let adjustment = BidAdjustment(predicate: .placementTop, percentage: 75)

        let encoder = JSONEncoder()
        let data = try encoder.encode(adjustment)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BidAdjustment.self, from: data)

        XCTAssertEqual(decoded.predicate, .placementTop)
        XCTAssertEqual(decoded.percentage, 75)
    }

    func testPlacementPredicateEnumValues() {
        XCTAssertEqual(PlacementPredicate.placementTop.rawValue, "placementTop")
        XCTAssertEqual(PlacementPredicate.placementProductPage.rawValue, "placementProductPage")
    }

    // MARK: - Integration Tests

    func testFullCampaignStructureCanBeEncodedAndDecoded() throws {
        let campaign = SponsoredProductsCampaign(
            campaignId: "C123",
            name: "Full Test Campaign",
            state: .enabled,
            targetingType: .manual,
            budget: .daily(100.00),
            startDate: "20250101",
            endDate: nil,
            premiumBidAdjustment: false,
            bidding: CampaignBidding(
                strategy: .manual,
                adjustments: [
                    BidAdjustment(predicate: .placementTop, percentage: 50),
                    BidAdjustment(predicate: .placementProductPage, percentage: 25)
                ]
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(campaign)

        // Verify JSON structure
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["campaignId"] as? String, "C123")
        XCTAssertEqual(json?["name"] as? String, "Full Test Campaign")
        XCTAssertEqual(json?["state"] as? String, "enabled")
        XCTAssertEqual(json?["targetingType"] as? String, "manual")

        // Decode and verify
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SponsoredProductsCampaign.self, from: data)

        XCTAssertEqual(decoded.campaignId, campaign.campaignId)
        XCTAssertEqual(decoded.bidding?.adjustments?.count, 2)
    }
}
