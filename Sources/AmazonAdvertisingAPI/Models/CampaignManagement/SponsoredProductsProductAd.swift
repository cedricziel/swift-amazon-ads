//
//  SponsoredProductsProductAd.swift
//  AmazonAdvertisingAPI
//
//  Sponsored Products product ad model for Amazon Advertising API v3
//

import Foundation

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

/// Product ad state
public enum ProductAdState: String, Codable, Sendable, CaseIterable {
    case enabled
    case paused
    case archived
}
