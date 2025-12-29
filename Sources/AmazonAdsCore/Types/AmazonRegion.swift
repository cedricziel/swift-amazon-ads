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

    /// Infers the Amazon region from a country code
    /// - Parameter countryCode: ISO 3166-1 alpha-2 country code (e.g., "US", "DE", "JP")
    /// - Returns: The appropriate Amazon region for the country, or nil if unknown
    public static func from(countryCode: String?) -> AmazonRegion? {
        guard let code = countryCode?.uppercased() else { return nil }

        switch code {
        // North America
        case "US", "CA", "MX", "BR":
            return .northAmerica

        // Europe
        case "GB", "UK", "DE", "FR", "IT", "ES", "NL", "SE", "PL", "TR", "AE", "SA", "EG", "BE", "IN":
            return .europe

        // Far East
        case "JP", "AU", "SG":
            return .farEast

        default:
            return nil
        }
    }

    /// Country codes that belong to this region
    public var countryCodes: [String] {
        switch self {
        case .northAmerica:
            return ["US", "CA", "MX", "BR"]
        case .europe:
            return ["GB", "DE", "FR", "IT", "ES", "NL", "SE", "PL", "TR", "AE", "SA", "EG", "BE", "IN"]
        case .farEast:
            return ["JP", "AU", "SG"]
        }
    }
}
