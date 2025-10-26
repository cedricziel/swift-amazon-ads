//
//  AmazonAdvertisingError.swift
//  AmazonAdvertisingAPI
//
//  Error types for Amazon Advertising API
//

import Foundation

/// Errors that can occur when using the Amazon Advertising API
public enum AmazonAdvertisingError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case oauthError(String, String?)
    case noAccessToken
    case noRefreshToken
    case pkceGenerationFailed
    case timeout
    case apiAccessNotApproved
    case storageError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .invalidResponse:
            return "Invalid response from Amazon"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .oauthError(let error, let description):
            return description ?? "OAuth error: \(error)"
        case .noAccessToken:
            return "No access token available. Please login."
        case .noRefreshToken:
            return "No refresh token available. Please login."
        case .pkceGenerationFailed:
            return "Failed to generate PKCE code challenge"
        case .timeout:
            return "Authorization timed out. Please try again."
        case .apiAccessNotApproved:
            return "Your Amazon account is not approved for Advertising API access. Please complete the onboarding process at https://advertising.amazon.com/API/docs/en-us/guides/onboarding/overview"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        }
    }
}
