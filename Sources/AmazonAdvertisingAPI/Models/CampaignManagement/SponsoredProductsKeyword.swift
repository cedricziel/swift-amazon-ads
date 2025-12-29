//
//  SponsoredProductsKeyword.swift
//  AmazonAdvertisingAPI
//
//  Sponsored Products keyword model for Amazon Advertising API v3
//

import Foundation

// MARK: - V3 API Response Types

/// Response wrapper for keyword list endpoint
public struct SPKeywordListResponse: Codable, Sendable {
    public let keywords: [SponsoredProductsKeyword]
    public let nextToken: String?
    public let totalResults: Int?

    public init(keywords: [SponsoredProductsKeyword], nextToken: String? = nil, totalResults: Int? = nil) {
        self.keywords = keywords
        self.nextToken = nextToken
        self.totalResults = totalResults
    }
}

/// Batch response wrapper for keyword operations
public struct SPKeywordBatchResponse: Codable, Sendable {
    public let keywords: SPKeywordBatchResult

    public init(keywords: SPKeywordBatchResult) {
        self.keywords = keywords
    }
}

/// Batch result containing success and error items
public struct SPKeywordBatchResult: Codable, Sendable {
    public let success: [SPKeywordSuccessItem]
    public let error: [SPKeywordErrorItem]

    public init(success: [SPKeywordSuccessItem] = [], error: [SPKeywordErrorItem] = []) {
        self.success = success
        self.error = error
    }
}

/// Success item in batch response
public struct SPKeywordSuccessItem: Codable, Sendable {
    public let keyword: SponsoredProductsKeyword
    public let keywordId: String?
    public let index: Int?

    public init(keyword: SponsoredProductsKeyword, keywordId: String? = nil, index: Int? = nil) {
        self.keyword = keyword
        self.keywordId = keywordId
        self.index = index
    }
}

/// Error item in batch response
public struct SPKeywordErrorItem: Codable, Sendable {
    public let keywordId: String?
    public let index: Int?
    public let errors: [SPApiError]

    public init(keywordId: String? = nil, index: Int? = nil, errors: [SPApiError] = []) {
        self.keywordId = keywordId
        self.index = index
        self.errors = errors
    }
}

// MARK: - Keyword Entity

/// Sponsored Products keyword targeting entity
public struct SponsoredProductsKeyword: Codable, Sendable, Identifiable {
    /// Amazon's keyword identifier (read-only, assigned by Amazon)
    public let keywordId: String?

    /// Parent ad group identifier
    public var adGroupId: String

    /// Parent campaign identifier
    public var campaignId: String

    /// Keyword text to target
    public var keywordText: String

    /// Match type for the keyword
    public var matchType: KeywordMatchType

    /// Bid amount for this keyword (optional, uses ad group default if not specified)
    public var bid: Decimal?

    /// Keyword state
    public var state: KeywordState

    /// Native language locale (optional, e.g., "en_US")
    public var nativeLanguageLocale: String?

    // MARK: - Identifiable

    public var id: String {
        keywordId ?? UUID().uuidString
    }

    // MARK: - Initialization

    public init(
        keywordId: String? = nil,
        adGroupId: String,
        campaignId: String,
        keywordText: String,
        matchType: KeywordMatchType,
        bid: Decimal? = nil,
        state: KeywordState = .enabled,
        nativeLanguageLocale: String? = nil
    ) {
        self.keywordId = keywordId
        self.adGroupId = adGroupId
        self.campaignId = campaignId
        self.keywordText = keywordText
        self.matchType = matchType
        self.bid = bid
        self.state = state
        self.nativeLanguageLocale = nativeLanguageLocale
    }
}

/// Keyword match type (V3 API uses UPPERCASE)
public enum KeywordMatchType: String, Codable, Sendable, CaseIterable {
    /// Exact match - ads show for exact keyword only
    case exact = "EXACT"

    /// Phrase match - ads show for phrases containing the keyword
    case phrase = "PHRASE"

    /// Broad match - ads show for related searches
    case broad = "BROAD"
}

/// Keyword state (V3 API uses UPPERCASE)
public enum KeywordState: String, Codable, Sendable, CaseIterable {
    case enabled = "ENABLED"
    case paused = "PAUSED"
    case archived = "ARCHIVED"
}

// MARK: - Negative Keywords

/// Negative keyword targeting (keywords to exclude)
public struct SponsoredProductsNegativeKeyword: Codable, Sendable, Identifiable {
    /// Amazon's negative keyword identifier (read-only, assigned by Amazon)
    public let keywordId: String?

    /// Parent ad group identifier (can be at ad group or campaign level)
    public var adGroupId: String?

    /// Parent campaign identifier
    public var campaignId: String

    /// Keyword text to exclude
    public var keywordText: String

    /// Match type for the negative keyword
    public var matchType: NegativeKeywordMatchType

    /// Negative keyword state
    public var state: NegativeKeywordState

    // MARK: - Identifiable

    public var id: String {
        keywordId ?? UUID().uuidString
    }

    // MARK: - Initialization

    public init(
        keywordId: String? = nil,
        adGroupId: String? = nil,
        campaignId: String,
        keywordText: String,
        matchType: NegativeKeywordMatchType,
        state: NegativeKeywordState = .enabled
    ) {
        self.keywordId = keywordId
        self.adGroupId = adGroupId
        self.campaignId = campaignId
        self.keywordText = keywordText
        self.matchType = matchType
        self.state = state
    }
}

/// Negative keyword match type (V3 API uses UPPERCASE with underscore)
public enum NegativeKeywordMatchType: String, Codable, Sendable, CaseIterable {
    /// Exact match - exclude exact keyword only
    case negativeExact = "NEGATIVE_EXACT"

    /// Phrase match - exclude phrases containing the keyword
    case negativePhrase = "NEGATIVE_PHRASE"
}

/// Negative keyword state (V3 API uses UPPERCASE)
public enum NegativeKeywordState: String, Codable, Sendable, CaseIterable {
    case enabled = "ENABLED"
    case deleted = "DELETED"
}
