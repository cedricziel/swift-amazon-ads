//
//  SponsoredProductsKeyword.swift
//  AmazonAdvertisingAPI
//
//  Sponsored Products keyword model for Amazon Advertising API v3
//

import Foundation

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

/// Keyword match type
public enum KeywordMatchType: String, Codable, Sendable, CaseIterable {
    /// Exact match - ads show for exact keyword only
    case exact

    /// Phrase match - ads show for phrases containing the keyword
    case phrase

    /// Broad match - ads show for related searches
    case broad
}

/// Keyword state
public enum KeywordState: String, Codable, Sendable, CaseIterable {
    case enabled
    case paused
    case archived
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

/// Negative keyword match type (exact and phrase only)
public enum NegativeKeywordMatchType: String, Codable, Sendable, CaseIterable {
    /// Exact match - exclude exact keyword only
    case negativeExact

    /// Phrase match - exclude phrases containing the keyword
    case negativePhrase
}

/// Negative keyword state
public enum NegativeKeywordState: String, Codable, Sendable, CaseIterable {
    case enabled
    case deleted
}
