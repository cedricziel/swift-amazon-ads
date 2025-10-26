//
//  SponsoredProductsCampaign.swift
//  AmazonAdvertisingAPI
//
//  Sponsored Products campaign model for Amazon Advertising API v3
//

import Foundation

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

    /// Daily budget in advertiser's currency
    public var budget: Budget

    /// Campaign start date (YYYYMMDD format)
    public var startDate: String

    /// Campaign end date (YYYYMMDD format, optional)
    public var endDate: String?

    /// Premium bid adjustment (top of search placement)
    public var premiumBidAdjustment: Bool?

    /// Bidding strategy
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
        self.bidding = bidding
        self.portfolioId = portfolioId
        self.tags = tags
    }

    // MARK: - Budget

    /// Campaign budget configuration
    public struct Budget: Codable, Sendable {
        /// Daily budget amount
        public var amount: Decimal

        /// Budget type (currently only daily is supported)
        public var budgetType: BudgetType

        public init(amount: Decimal, budgetType: BudgetType = .daily) {
            self.amount = amount
            self.budgetType = budgetType
        }

        /// Convenience initializer for daily budget
        public static func daily(_ amount: Decimal) -> Budget {
            Budget(amount: amount, budgetType: .daily)
        }
    }

    /// Budget type
    public enum BudgetType: String, Codable, Sendable {
        case daily
    }
}

/// Campaign state
public enum CampaignState: String, Codable, Sendable, CaseIterable {
    case enabled
    case paused
    case archived
}

/// Targeting type for campaigns
public enum TargetingType: String, Codable, Sendable, CaseIterable {
    /// Manual targeting (keywords or product targets specified by advertiser)
    case manual

    /// Automatic targeting (Amazon automatically targets based on product info)
    case auto
}

/// Campaign bidding configuration
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

/// Bidding strategy
public enum BiddingStrategy: String, Codable, Sendable, CaseIterable {
    /// Legacy bid optimization for conversions
    case legacyForSales

    /// Automatic bid optimization for conversions
    case autoForSales

    /// Manual bidding (advertiser sets bids)
    case manual
}

/// Bid adjustment for specific placements
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

/// Placement predicate for bid adjustments
public enum PlacementPredicate: String, Codable, Sendable {
    /// Top of search (first page)
    case placementTop

    /// Product pages
    case placementProductPage
}

// MARK: - Date Helpers

extension SponsoredProductsCampaign {
    /// Create campaign with Swift Date objects (converts to YYYYMMDD format)
    public static func withDates(
        name: String,
        state: CampaignState = .enabled,
        targetingType: TargetingType = .manual,
        budget: Budget,
        startDate: Date,
        endDate: Date? = nil,
        bidding: CampaignBidding? = nil
    ) -> SponsoredProductsCampaign {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        return SponsoredProductsCampaign(
            name: name,
            state: state,
            targetingType: targetingType,
            budget: budget,
            startDate: dateFormatter.string(from: startDate),
            endDate: endDate.map { dateFormatter.string(from: $0) },
            bidding: bidding
        )
    }

    /// Parse start date string to Date
    public var parsedStartDate: Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        return dateFormatter.date(from: startDate)
    }

    /// Parse end date string to Date
    public var parsedEndDate: Date? {
        guard let endDate = endDate else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        return dateFormatter.date(from: endDate)
    }
}
