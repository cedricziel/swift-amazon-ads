//
//  SponsoredProductsAdGroup.swift
//  LegacyAmazonAdsSponsoredProductsAPIv3
//
//  Sponsored Products ad group model for Amazon Advertising API v3
//

import Foundation

// MARK: - V3 API Response Types

/// Response wrapper for ad group list endpoint
public struct SPAdGroupListResponse: Codable, Sendable {
    public let adGroups: [SponsoredProductsAdGroup]
    public let nextToken: String?
    public let totalResults: Int?

    public init(adGroups: [SponsoredProductsAdGroup], nextToken: String? = nil, totalResults: Int? = nil) {
        self.adGroups = adGroups
        self.nextToken = nextToken
        self.totalResults = totalResults
    }
}

/// Batch response wrapper for ad group operations
public struct SPAdGroupBatchResponse: Codable, Sendable {
    public let adGroups: SPAdGroupBatchResult

    public init(adGroups: SPAdGroupBatchResult) {
        self.adGroups = adGroups
    }
}

/// Batch result containing success and error items
public struct SPAdGroupBatchResult: Codable, Sendable {
    public let success: [SPAdGroupSuccessItem]
    public let error: [SPAdGroupErrorItem]

    public init(success: [SPAdGroupSuccessItem] = [], error: [SPAdGroupErrorItem] = []) {
        self.success = success
        self.error = error
    }
}

/// Success item in batch response
public struct SPAdGroupSuccessItem: Codable, Sendable {
    public let adGroup: SponsoredProductsAdGroup
    public let adGroupId: String?
    public let index: Int?

    public init(adGroup: SponsoredProductsAdGroup, adGroupId: String? = nil, index: Int? = nil) {
        self.adGroup = adGroup
        self.adGroupId = adGroupId
        self.index = index
    }
}

/// Error item in batch response
public struct SPAdGroupErrorItem: Codable, Sendable {
    public let adGroupId: String?
    public let index: Int?
    public let errors: [SPApiError]

    public init(adGroupId: String? = nil, index: Int? = nil, errors: [SPApiError] = []) {
        self.adGroupId = adGroupId
        self.index = index
        self.errors = errors
    }
}

// MARK: - Ad Group Entity

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
    public var defaultBid: Double?

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
        defaultBid: Double? = nil,
        tags: [String: String]? = nil
    ) {
        self.adGroupId = adGroupId
        self.name = name
        self.campaignId = campaignId
        self.state = state
        self.defaultBid = defaultBid
        self.tags = tags
    }

    /// Convenience initializer with Decimal bid
    public init(
        adGroupId: String? = nil,
        name: String,
        campaignId: String,
        state: AdGroupState = .enabled,
        defaultBid: Decimal?,
        tags: [String: String]? = nil
    ) {
        self.adGroupId = adGroupId
        self.name = name
        self.campaignId = campaignId
        self.state = state
        self.defaultBid = defaultBid.map { NSDecimalNumber(decimal: $0).doubleValue }
        self.tags = tags
    }
}

/// Ad group state (V3 API uses UPPERCASE)
public enum AdGroupState: String, Codable, Sendable, CaseIterable {
    case enabled = "ENABLED"
    case paused = "PAUSED"
    case archived = "ARCHIVED"
    case enabling = "ENABLING"
    case other = "OTHER"
}
