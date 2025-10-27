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
    case httpError(Int, responseBody: String?)
    case oauthError(String, String?)
    case noAccessToken
    case noRefreshToken
    case pkceGenerationFailed
    case timeout
    case apiAccessNotApproved
    case storageError(Error)
    case invalidRequest(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .invalidResponse:
            return "Invalid response from Amazon"
        case .httpError(let code, let responseBody):
            var message = httpErrorDescription(for: code)
            if let body = responseBody, !body.isEmpty {
                message += "\nResponse: \(body)"
            }
            return message
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
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        }
    }

    /// Provides user-friendly error descriptions for HTTP status codes
    private func httpErrorDescription(for code: Int) -> String {
        switch code {
        case 400:
            return "Bad Request (HTTP 400): Invalid request parameters or profile ID. Check that the profile ID is correct and active."
        case 401:
            return "Unauthorized (HTTP 401): Authentication failed. Access token may be expired or invalid. Try logging in again."
        case 403:
            return "Forbidden (HTTP 403): Access denied. Check that your account has permission to access this profile and that API access is enabled."
        case 404:
            return "Not Found (HTTP 404): The requested profile or resource was not found. Verify the profile ID is correct."
        case 429:
            return "Too Many Requests (HTTP 429): Rate limit exceeded. Please wait before trying again."
        case 500:
            return "Internal Server Error (HTTP 500): Amazon Advertising API encountered an error. Please try again later."
        case 502:
            return "Bad Gateway (HTTP 502): Amazon Advertising API is temporarily unavailable. Please try again later."
        case 503:
            return "Service Unavailable (HTTP 503): Amazon Advertising API is temporarily down for maintenance. Please try again later."
        case 504:
            return "Gateway Timeout (HTTP 504): Request timed out. Please try again."
        default:
            return "HTTP error \(code): An unexpected error occurred while communicating with Amazon Advertising API."
        }
    }
}
