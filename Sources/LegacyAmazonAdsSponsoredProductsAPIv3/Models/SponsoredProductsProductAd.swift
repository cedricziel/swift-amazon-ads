//
//  SponsoredProductsProductAd.swift
//  LegacyAmazonAdsSponsoredProductsAPIv3
//
//  Sponsored Products product ad model for Amazon Advertising API v3
//

import Foundation

// MARK: - V3 API Response Types

/// Response wrapper for product ad list endpoint
public struct SPProductAdListResponse: Codable, Sendable {
    public let productAds: [SponsoredProductsProductAd]
    public let nextToken: String?
    public let totalResults: Int?

    public init(productAds: [SponsoredProductsProductAd], nextToken: String? = nil, totalResults: Int? = nil) {
        self.productAds = productAds
        self.nextToken = nextToken
        self.totalResults = totalResults
    }
}

/// Batch response wrapper for product ad operations
public struct SPProductAdBatchResponse: Codable, Sendable {
    public let productAds: SPProductAdBatchResult

    public init(productAds: SPProductAdBatchResult) {
        self.productAds = productAds
    }
}

/// Batch result containing success and error items
public struct SPProductAdBatchResult: Codable, Sendable {
    public let success: [SPProductAdSuccessItem]
    public let error: [SPProductAdErrorItem]

    public init(success: [SPProductAdSuccessItem] = [], error: [SPProductAdErrorItem] = []) {
        self.success = success
        self.error = error
    }
}

/// Success item in batch response
public struct SPProductAdSuccessItem: Codable, Sendable {
    public let productAd: SponsoredProductsProductAd
    public let adId: String?
    public let index: Int?

    public init(productAd: SponsoredProductsProductAd, adId: String? = nil, index: Int? = nil) {
        self.productAd = productAd
        self.adId = adId
        self.index = index
    }
}

/// Error item in batch response
public struct SPProductAdErrorItem: Codable, Sendable {
    public let adId: String?
    public let index: Int?
    public let errors: [SPApiError]

    public init(adId: String? = nil, index: Int? = nil, errors: [SPApiError] = []) {
        self.adId = adId
        self.index = index
        self.errors = errors
    }
}

// MARK: - Product Ad Entity

/// Sponsored Products product ad entity
/// Represents an ASIN being advertised in an ad group
public struct SponsoredProductsProductAd: Codable, Sendable, Identifiable {
    /// Amazon's ad identifier (read-only, assigned by Amazon)
    public let adId: String?

    /// Parent ad group identifier
    public var adGroupId: String

    /// Parent campaign identifier
    public var campaignId: String

    /// Product ASIN being advertised
    public var asin: String

    /// Seller SKU (optional, for inventory tracking)
    public var sku: String?

    /// Ad state
    public var state: ProductAdState

    // MARK: - Identifiable

    public var id: String {
        adId ?? UUID().uuidString
    }

    // MARK: - Initialization

    public init(
        adId: String? = nil,
        adGroupId: String,
        campaignId: String,
        asin: String,
        sku: String? = nil,
        state: ProductAdState = .enabled
    ) {
        self.adId = adId
        self.adGroupId = adGroupId
        self.campaignId = campaignId
        self.asin = asin
        self.sku = sku
        self.state = state
    }
}

/// Product ad state (V3 API uses UPPERCASE)
public enum ProductAdState: String, Codable, Sendable, CaseIterable {
    case enabled = "ENABLED"
    case paused = "PAUSED"
    case archived = "ARCHIVED"
}
