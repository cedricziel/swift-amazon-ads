//
//  AmazonAPIErrorResponse.swift
//  AmazonAdsCore
//
//  Amazon Advertising API error responses
//

import Foundation

/// Amazon Advertising API error response
public struct AmazonAPIErrorResponse: Codable, Sendable {
    public let code: String
    public let details: String
    public let requestId: String?

    public init(code: String, details: String, requestId: String? = nil) {
        self.code = code
        self.details = details
        self.requestId = requestId
    }
}
