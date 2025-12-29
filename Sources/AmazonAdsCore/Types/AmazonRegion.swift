//
//  AmazonRegion.swift
//  AmazonAdsCore
//
//  Amazon Advertising API regions with their respective endpoints
//

import Foundation

/// Amazon Advertising API regions
public enum AmazonRegion: String, CaseIterable, Codable, Identifiable, Sendable {
    case northAmerica = "NA"
    case europe = "EU"
    case farEast = "FE"

    public var id: String { rawValue }

    /// Display name for the region
    public var displayName: String {
        switch self {
        case .northAmerica:
            return "North America"
        case .europe:
            return "Europe"
        case .farEast:
            return "Far East"
        }
    }

    /// OAuth authorization endpoint
    public var authorizationURL: URL {
        URL(string: "https://www.amazon.com/ap/oa")!
    }

    /// OAuth token endpoint for exchanging authorization code and refreshing tokens
    public var tokenEndpoint: URL {
        switch self {
        case .northAmerica:
            return URL(string: "https://api.amazon.com/auth/o2/token")!
        case .europe:
            return URL(string: "https://api.amazon.co.uk/auth/o2/token")!
        case .farEast:
            return URL(string: "https://api.amazon.co.jp/auth/o2/token")!
        }
    }

    /// Amazon Advertising API base URL
    public var advertisingAPIBaseURL: URL {
        switch self {
        case .northAmerica:
            return URL(string: "https://advertising-api.amazon.com")!
        case .europe:
            return URL(string: "https://advertising-api-eu.amazon.com")!
        case .farEast:
            return URL(string: "https://advertising-api-fe.amazon.com")!
        }
    }

    /// Keychain key suffix for this region
    public var keychainSuffix: String {
        rawValue
    }
}
