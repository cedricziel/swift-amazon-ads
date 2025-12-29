//
//  SponsoredProductsCampaign.swift
//  AmazonAdvertisingAPI
//
//  Sponsored Products campaign model for Amazon Advertising API v3
//

import Foundation

// MARK: - V3 API Response Types

/// Response wrapper for campaign list endpoint
public struct SPCampaignListResponse: Codable, Sendable {
    /// Array of campaigns
    public let campaigns: [SponsoredProductsCampaign]

    /// Token for pagination
    public let nextToken: String?

    /// Total number of results
    public let totalResults: Int?

    public init(
        campaigns: [SponsoredProductsCampaign],
        nextToken: String? = nil,
        totalResults: Int? = nil
    ) {
        self.campaigns = campaigns
        self.nextToken = nextToken
        self.totalResults = totalResults
    }
}

/// Sponsored Products campaign entity
public struct SponsoredProductsCampaign: Codable, Sendable, Identifiable {
    /// Amazon's campaign identifier (read-only, assigned by Amazon)
    public let campaignId: String?

    /// Campaign name (1-128 characters)
    public var name: String

    /// Campaign state
    public var state: CampaignState

    /// Targeting type (manual or automatic)
    public var targetingType: TargetingType

    /// Campaign budget configuration
    public var budget: Budget

    /// Campaign start date (YYYY-MM-DD format for V3 API)
    public var startDate: String

    /// Campaign end date (YYYY-MM-DD format, optional)
    public var endDate: String?

    /// Premium bid adjustment (top of search placement) - deprecated in V3
    public var premiumBidAdjustment: Bool?

    /// Dynamic bidding configuration (V3 API)
    public var dynamicBidding: DynamicBidding?

    /// Legacy bidding configuration (for backwards compatibility)
    public var bidding: CampaignBidding?

    /// Portfolio ID (optional, for organizing campaigns)
    public var portfolioId: String?

    /// Tags for campaign organization
    public var tags: [String: String]?

    // MARK: - Identifiable

    public var id: String {
        campaignId ?? UUID().uuidString
    }

    // MARK: - Initialization

    public init(
        campaignId: String? = nil,
        name: String,
        state: CampaignState = .enabled,
        targetingType: TargetingType = .manual,
        budget: Budget,
        startDate: String,
        endDate: String? = nil,
        premiumBidAdjustment: Bool? = nil,
        dynamicBidding: DynamicBidding? = nil,
        bidding: CampaignBidding? = nil,
        portfolioId: String? = nil,
        tags: [String: String]? = nil
    ) {
        self.campaignId = campaignId
        self.name = name
        self.state = state
        self.targetingType = targetingType
        self.budget = budget
        self.startDate = startDate
        self.endDate = endDate
        self.premiumBidAdjustment = premiumBidAdjustment
        self.dynamicBidding = dynamicBidding
        self.bidding = bidding
        self.portfolioId = portfolioId
        self.tags = tags
    }

    // MARK: - Budget

    /// Campaign budget configuration (V3 API format)
    public struct Budget: Codable, Sendable {
        /// Budget amount (V3 API uses 'budget' not 'amount')
        public var budget: Double

        /// Budget type (currently only DAILY is supported)
        public var budgetType: BudgetType

        /// Effective budget (read-only, after rules applied)
        public var effectiveBudget: Double?

        public init(budget: Double, budgetType: BudgetType = .daily) {
            self.budget = budget
            self.budgetType = budgetType
        }

        /// Convenience initializer for daily budget
        public static func daily(_ amount: Double) -> Budget {
            Budget(budget: amount, budgetType: .daily)
        }

        /// Convenience initializer from Decimal
        public static func daily(_ amount: Decimal) -> Budget {
            Budget(budget: NSDecimalNumber(decimal: amount).doubleValue, budgetType: .daily)
        }

        enum CodingKeys: String, CodingKey {
            case budget
            case budgetType
            case effectiveBudget
        }
    }

    /// Budget type (V3 API uses UPPERCASE)
    public enum BudgetType: String, Codable, Sendable {
        case daily = "DAILY"
    }
}

/// Campaign state (V3 API uses UPPERCASE values)
public enum CampaignState: String, Codable, Sendable, CaseIterable {
    case enabled = "ENABLED"
    case paused = "PAUSED"
    case archived = "ARCHIVED"
    case enabling = "ENABLING"
    case proposed = "PROPOSED"
    case userDeleted = "USER_DELETED"
    case other = "OTHER"
}

/// Targeting type for campaigns (V3 API uses UPPERCASE)
public enum TargetingType: String, Codable, Sendable, CaseIterable {
    /// Manual targeting (keywords or product targets specified by advertiser)
    case manual = "MANUAL"

    /// Automatic targeting (Amazon automatically targets based on product info)
    case auto = "AUTO"
}

/// Dynamic bidding configuration (V3 API)
public struct DynamicBidding: Codable, Sendable {
    /// Placement bidding strategy
    public var placementBidding: [PlacementBidding]?

    /// Bidding strategy
    public var strategy: BiddingStrategy?

    public init(
        placementBidding: [PlacementBidding]? = nil,
        strategy: BiddingStrategy? = nil
    ) {
        self.placementBidding = placementBidding
        self.strategy = strategy
    }
}

/// Placement bidding configuration
public struct PlacementBidding: Codable, Sendable {
    /// Placement type
    public var placement: PlacementType

    /// Percentage adjustment (0-900)
    public var percentage: Int

    public init(placement: PlacementType, percentage: Int) {
        self.placement = placement
        self.percentage = percentage
    }
}

/// Placement type for bid adjustments (V3 API)
public enum PlacementType: String, Codable, Sendable {
    case placementTop = "PLACEMENT_TOP"
    case placementProductPage = "PLACEMENT_PRODUCT_PAGE"
    case placementRestOfSearch = "PLACEMENT_REST_OF_SEARCH"
}

/// Campaign bidding configuration (legacy, for backwards compatibility)
public struct CampaignBidding: Codable, Sendable {
    /// Bidding strategy
    public var strategy: BiddingStrategy?

    /// Bid adjustments for placements
    public var adjustments: [BidAdjustment]?

    public init(
        strategy: BiddingStrategy? = nil,
        adjustments: [BidAdjustment]? = nil
    ) {
        self.strategy = strategy
        self.adjustments = adjustments
    }
}

/// Bidding strategy (V3 API uses UPPERCASE with underscores)
public enum BiddingStrategy: String, Codable, Sendable, CaseIterable {
    /// Legacy bid optimization for conversions (down only)
    case legacyForSales = "LEGACY_FOR_SALES"

    /// Automatic bid optimization for conversions (up and down)
    case autoForSales = "AUTO_FOR_SALES"

    /// Manual bidding (advertiser sets bids)
    case manual = "MANUAL"

    /// Rule-based bidding
    case ruleBased = "RULE_BASED"
}

/// Bid adjustment for specific placements (legacy)
public struct BidAdjustment: Codable, Sendable {
    /// Placement type
    public var predicate: PlacementPredicate

    /// Percentage adjustment (-99 to 900)
    public var percentage: Int

    public init(predicate: PlacementPredicate, percentage: Int) {
        self.predicate = predicate
        self.percentage = percentage
    }
}

/// Placement predicate for bid adjustments (legacy)
public enum PlacementPredicate: String, Codable, Sendable {
    /// Top of search (first page)
    case placementTop = "PLACEMENT_TOP"

    /// Product pages
    case placementProductPage = "PLACEMENT_PRODUCT_PAGE"
}

// MARK: - V3 API Request/Response Types

/// Request wrapper for creating campaigns (V3 API expects array)
public struct SPCampaignCreateRequest: Codable, Sendable {
    public let campaigns: [SponsoredProductsCampaign]

    public init(campaigns: [SponsoredProductsCampaign]) {
        self.campaigns = campaigns
    }
}

/// Request wrapper for updating campaigns (V3 API expects array)
public struct SPCampaignUpdateRequest: Codable, Sendable {
    public let campaigns: [SponsoredProductsCampaign]

    public init(campaigns: [SponsoredProductsCampaign]) {
        self.campaigns = campaigns
    }
}

/// Request wrapper for deleting campaigns
public struct SPCampaignDeleteRequest: Codable, Sendable {
    public let campaignIdFilter: SPIdFilter

    public init(campaignIdFilter: SPIdFilter) {
        self.campaignIdFilter = campaignIdFilter
    }
}

/// ID filter for V3 API requests
public struct SPIdFilter: Codable, Sendable {
    public let include: [String]

    public init(include: [String]) {
        self.include = include
    }
}

/// Batch response wrapper for campaign operations
public struct SPCampaignBatchResponse: Codable, Sendable {
    public let campaigns: SPCampaignBatchResult

    public init(campaigns: SPCampaignBatchResult) {
        self.campaigns = campaigns
    }
}

/// Batch result containing success and error items
public struct SPCampaignBatchResult: Codable, Sendable {
    public let success: [SPCampaignSuccessItem]
    public let error: [SPCampaignErrorItem]

    public init(success: [SPCampaignSuccessItem] = [], error: [SPCampaignErrorItem] = []) {
        self.success = success
        self.error = error
    }
}

/// Success item in batch response
public struct SPCampaignSuccessItem: Codable, Sendable {
    public let campaign: SponsoredProductsCampaign
    public let campaignId: String?
    public let index: Int?

    public init(campaign: SponsoredProductsCampaign, campaignId: String? = nil, index: Int? = nil) {
        self.campaign = campaign
        self.campaignId = campaignId
        self.index = index
    }
}

/// Error item in batch response
public struct SPCampaignErrorItem: Codable, Sendable {
    public let campaignId: String?
    public let index: Int?
    public let errors: [SPApiError]

    public init(campaignId: String? = nil, index: Int? = nil, errors: [SPApiError] = []) {
        self.campaignId = campaignId
        self.index = index
        self.errors = errors
    }
}

/// API error details
public struct SPApiError: Codable, Sendable {
    public let errorType: String?
    public let message: String
    public let location: String?

    public init(errorType: String? = nil, message: String, location: String? = nil) {
        self.errorType = errorType
        self.message = message
        self.location = location
    }
}

// MARK: - Date Helpers

extension SponsoredProductsCampaign {
    /// Date formatter for V3 API (YYYY-MM-DD format)
    private static var v3DateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    /// Create campaign with Swift Date objects (converts to YYYY-MM-DD format for V3 API)
    public static func withDates(
        name: String,
        state: CampaignState = .enabled,
        targetingType: TargetingType = .manual,
        budget: Budget,
        startDate: Date,
        endDate: Date? = nil,
        dynamicBidding: DynamicBidding? = nil
    ) -> SponsoredProductsCampaign {
        SponsoredProductsCampaign(
            name: name,
            state: state,
            targetingType: targetingType,
            budget: budget,
            startDate: v3DateFormatter.string(from: startDate),
            endDate: endDate.map { v3DateFormatter.string(from: $0) },
            dynamicBidding: dynamicBidding
        )
    }

    /// Parse start date string to Date
    public var parsedStartDate: Date? {
        Self.v3DateFormatter.date(from: startDate)
    }

    /// Parse end date string to Date
    public var parsedEndDate: Date? {
        guard let endDate else { return nil }
        return Self.v3DateFormatter.date(from: endDate)
    }
}
