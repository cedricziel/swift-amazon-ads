//
//  SponsoredProductsTarget.swift
//  LegacyAmazonAdsSponsoredProductsAPIv3
//
//  Sponsored Products product targeting model for Amazon Advertising API v3
//

import Foundation

// MARK: - V3 API Response Types

/// Response wrapper for target list endpoint
public struct SPTargetListResponse: Codable, Sendable {
    public let targetingClauses: [SponsoredProductsTarget]
    public let nextToken: String?
    public let totalResults: Int?

    public init(targetingClauses: [SponsoredProductsTarget], nextToken: String? = nil, totalResults: Int? = nil) {
        self.targetingClauses = targetingClauses
        self.nextToken = nextToken
        self.totalResults = totalResults
    }
}

/// Batch response wrapper for target operations
public struct SPTargetBatchResponse: Codable, Sendable {
    public let targetingClauses: SPTargetBatchResult

    public init(targetingClauses: SPTargetBatchResult) {
        self.targetingClauses = targetingClauses
    }
}

/// Batch result containing success and error items
public struct SPTargetBatchResult: Codable, Sendable {
    public let success: [SPTargetSuccessItem]
    public let error: [SPTargetErrorItem]

    public init(success: [SPTargetSuccessItem] = [], error: [SPTargetErrorItem] = []) {
        self.success = success
        self.error = error
    }
}

/// Success item in batch response
public struct SPTargetSuccessItem: Codable, Sendable {
    public let targetingClause: SponsoredProductsTarget
    public let targetId: String?
    public let index: Int?

    public init(targetingClause: SponsoredProductsTarget, targetId: String? = nil, index: Int? = nil) {
        self.targetingClause = targetingClause
        self.targetId = targetId
        self.index = index
    }
}

/// Error item in batch response
public struct SPTargetErrorItem: Codable, Sendable {
    public let targetId: String?
    public let index: Int?
    public let errors: [SPApiError]

    public init(targetId: String? = nil, index: Int? = nil, errors: [SPApiError] = []) {
        self.targetId = targetId
        self.index = index
        self.errors = errors
    }
}

// MARK: - Target Entity

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

/// Target expression type (V3 API uses UPPERCASE)
public enum TargetExpressionType: String, Codable, Sendable, CaseIterable {
    /// Manual targeting
    case manual = "MANUAL"

    /// Automatic targeting
    case auto = "AUTO"
}

/// Target state (V3 API uses UPPERCASE)
public enum TargetState: String, Codable, Sendable, CaseIterable {
    case enabled = "ENABLED"
    case paused = "PAUSED"
    case archived = "ARCHIVED"
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

/// Negative target state (V3 API uses UPPERCASE)
public enum NegativeTargetState: String, Codable, Sendable, CaseIterable {
    case enabled = "ENABLED"
    case deleted = "DELETED"
}
