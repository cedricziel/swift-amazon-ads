//
//  SponsoredProductsAdGroup.swift
//  AmazonAdvertisingAPI
//
//  Sponsored Products ad group model for Amazon Advertising API v3
//

import Foundation

/// Sponsored Products ad group entity
public struct SponsoredProductsAdGroup: Codable, Sendable, Identifiable {
    /// Amazon's ad group identifier (read-only, assigned by Amazon)
    public let adGroupId: String?

    /// Ad group name (1-128 characters)
    public var name: String

    /// Parent campaign identifier
    public var campaignId: String

    /// Ad group state
    public var state: AdGroupState

    /// Default bid for keywords/targets in this ad group (in advertiser's currency)
    public var defaultBid: Decimal?

    /// Tags for ad group organization
    public var tags: [String: String]?

    // MARK: - Identifiable

    public var id: String {
        adGroupId ?? UUID().uuidString
    }

    // MARK: - Initialization

    public init(
        adGroupId: String? = nil,
        name: String,
        campaignId: String,
        state: AdGroupState = .enabled,
        defaultBid: Decimal? = nil,
        tags: [String: String]? = nil
    ) {
        self.adGroupId = adGroupId
        self.name = name
        self.campaignId = campaignId
        self.state = state
        self.defaultBid = defaultBid
        self.tags = tags
    }
}

/// Ad group state
public enum AdGroupState: String, Codable, Sendable, CaseIterable {
    case enabled
    case paused
    case archived
}
