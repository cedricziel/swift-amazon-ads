//
//  SponsoredProductsTarget.swift
//  AmazonAdvertisingAPI
//
//  Sponsored Products product targeting model for Amazon Advertising API v3
//

import Foundation

/// Sponsored Products product/category targeting entity
public struct SponsoredProductsTarget: Codable, Sendable, Identifiable {
    /// Amazon's target identifier (read-only, assigned by Amazon)
    public let targetId: String?

    /// Parent ad group identifier
    public var adGroupId: String

    /// Parent campaign identifier
    public var campaignId: String

    /// Targeting expression (defines what to target)
    public var expression: [TargetExpression]

    /// Expression type
    public var expressionType: TargetExpressionType

    /// Bid amount for this target (optional, uses ad group default if not specified)
    public var bid: Decimal?

    /// Target state
    public var state: TargetState

    // MARK: - Identifiable

    public var id: String {
        targetId ?? UUID().uuidString
    }

    // MARK: - Initialization

    public init(
        targetId: String? = nil,
        adGroupId: String,
        campaignId: String,
        expression: [TargetExpression],
        expressionType: TargetExpressionType,
        bid: Decimal? = nil,
        state: TargetState = .enabled
    ) {
        self.targetId = targetId
        self.adGroupId = adGroupId
        self.campaignId = campaignId
        self.expression = expression
        self.expressionType = expressionType
        self.bid = bid
        self.state = state
    }
}

/// Target expression (defines targeting criteria)
public struct TargetExpression: Codable, Sendable {
    /// Expression type (e.g., "asinCategorySameAs", "asinSameAs")
    public var type: String

    /// Expression value (ASIN or category ID)
    public var value: String

    public init(type: String, value: String) {
        self.type = type
        self.value = value
    }

    // MARK: - Convenience Constructors

    /// Target a specific ASIN
    public static func asin(_ asin: String) -> TargetExpression {
        TargetExpression(type: "asinSameAs", value: asin)
    }

    /// Target products in the same category as an ASIN
    public static func category(_ asin: String) -> TargetExpression {
        TargetExpression(type: "asinCategorySameAs", value: asin)
    }

    /// Target products with similar features to an ASIN
    public static func expanded(_ asin: String) -> TargetExpression {
        TargetExpression(type: "asinExpandedFrom", value: asin)
    }
}

/// Target expression type
public enum TargetExpressionType: String, Codable, Sendable, CaseIterable {
    /// Manual targeting
    case manual

    /// Automatic targeting
    case auto
}

/// Target state
public enum TargetState: String, Codable, Sendable, CaseIterable {
    case enabled
    case paused
    case archived
}

// MARK: - Negative Targets

/// Negative product targeting (products/categories to exclude)
public struct SponsoredProductsNegativeTarget: Codable, Sendable, Identifiable {
    /// Amazon's negative target identifier (read-only, assigned by Amazon)
    public let targetId: String?

    /// Parent ad group identifier (can be at ad group or campaign level)
    public var adGroupId: String?

    /// Parent campaign identifier
    public var campaignId: String

    /// Targeting expression (defines what to exclude)
    public var expression: [TargetExpression]

    /// Expression type
    public var expressionType: TargetExpressionType

    /// Negative target state
    public var state: NegativeTargetState

    // MARK: - Identifiable

    public var id: String {
        targetId ?? UUID().uuidString
    }

    // MARK: - Initialization

    public init(
        targetId: String? = nil,
        adGroupId: String? = nil,
        campaignId: String,
        expression: [TargetExpression],
        expressionType: TargetExpressionType = .manual,
        state: NegativeTargetState = .enabled
    ) {
        self.targetId = targetId
        self.adGroupId = adGroupId
        self.campaignId = campaignId
        self.expression = expression
        self.expressionType = expressionType
        self.state = state
    }
}

/// Negative target state
public enum NegativeTargetState: String, Codable, Sendable, CaseIterable {
    case enabled
    case deleted
}
