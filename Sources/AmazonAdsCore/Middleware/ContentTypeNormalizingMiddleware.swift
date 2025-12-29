//
//  ContentTypeNormalizingMiddleware.swift
//  AmazonAdsCore
//
//  Middleware that normalizes content types between Amazon API and OpenAPI client
//
//  Amazon's API sometimes returns generic `application/json` when the OpenAPI spec
//  expects vendor-specific types like `application/vnd.spCampaign.v3+json`.
//  This middleware normalizes these mismatches.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import os.log

/// A middleware that normalizes content type mismatches between Amazon's API responses
/// and what the OpenAPI-generated client expects.
///
/// Common mismatches:
/// - Amazon returns `application/json` but OpenAPI expects `application/vnd.*.v*+json`
/// - Amazon returns `text/plain` for errors but OpenAPI expects `application/json`
public struct ContentTypeNormalizingMiddleware: ClientMiddleware {
    private let logger = Logger(subsystem: "com.amazon.ads", category: "content-type")

    /// Creates a new content type normalizing middleware
    public init() {}

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        // Extract the expected content type from Accept header
        let acceptHeader = request.headerFields[.accept]
        let expectedVendorType = extractPrimaryVendorType(from: acceptHeader)

        let (response, responseBody) = try await next(request, body, baseURL)

        // Get the actual content type from response
        guard let actualContentType = response.headerFields[.contentType] else {
            logger.debug("No Content-Type header in response")
            return (response, responseBody)
        }

        let statusCode = response.status.code
        logger.debug("ContentType normalization: status=\(statusCode), actual='\(actualContentType)', expected='\(expectedVendorType ?? "nil")'")

        // Normalize content type if needed
        let normalizedContentType = normalizeContentType(
            actual: actualContentType,
            expected: expectedVendorType,
            statusCode: statusCode
        )

        if let normalizedContentType, normalizedContentType != actualContentType {
            logger.info("Normalizing Content-Type from '\(actualContentType)' to '\(normalizedContentType)'")
            var modifiedResponse = response
            modifiedResponse.headerFields[.contentType] = normalizedContentType
            return (modifiedResponse, responseBody)
        }

        logger.debug("No Content-Type normalization needed")
        return (response, responseBody)
    }

    // MARK: - Private Helpers

    /// Extracts the primary vendor content type from Accept header
    /// e.g., "application/vnd.spCampaign.v3+json, application/json" -> "application/vnd.spCampaign.v3+json"
    private func extractPrimaryVendorType(from acceptHeader: String?) -> String? {
        guard let acceptHeader else { return nil }

        // Split by comma and find first vendor type
        let types = acceptHeader.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        for type in types {
            if type.contains("vnd.") && type.contains("+json") {
                return type
            }
        }

        return nil
    }

    /// Determines if content type normalization is needed and returns the normalized type
    private func normalizeContentType(
        actual: String,
        expected: String?,
        statusCode: Int
    ) -> String? {
        let actualLower = actual.lowercased()

        // Case 1: Response is application/json but we expected a vendor type (success responses)
        if actualLower.hasPrefix("application/json"), let expected, expected.contains("vnd.") {
            // Amazon returned generic JSON when we expected vendor-specific JSON
            // Return the expected vendor type so OpenAPI client can parse it
            return expected
        }

        // Case 2: Error response with text/plain
        if statusCode >= 400 && actualLower.hasPrefix("text/plain") {
            return "application/json"
        }

        // Case 3: Error response with vendor type when OpenAPI expects application/json
        // For error responses (4xx, 5xx), OpenAPI specs often expect application/json
        // but Amazon returns vendor types even for errors
        if statusCode >= 400 && actualLower.contains("vnd.") && actualLower.contains("+json") {
            return "application/json"
        }

        // Case 4: Success response with vendor type - this is correct, leave it alone
        // The OpenAPI client should handle vendor types for success responses

        // Case 5: Vendor type variants (e.g., charset differences) - normalize to expected
        if let expected, actualLower.contains("vnd."), expected.contains("vnd.") {
            // Both are vendor types - normalize to expected if they're close enough
            let actualBase = actualLower.split(separator: ";").first.map(String.init) ?? actualLower
            let expectedBase = expected.lowercased().split(separator: ";").first.map(String.init) ?? expected.lowercased()

            if actualBase != expectedBase && isCompatibleVendorType(actual: actualBase, expected: expectedBase) {
                return expected
            }
        }

        return nil
    }

    /// Checks if two vendor types are compatible (same base type, different versions/variants)
    private func isCompatibleVendorType(actual: String, expected: String) -> Bool {
        // Both should be JSON-based
        guard actual.contains("+json") || actual.contains("json"),
              expected.contains("+json") || expected.contains("json") else {
            return false
        }

        // Extract the vendor name (e.g., "spcampaign" from "application/vnd.spcampaign.v3+json")
        let actualVendor = extractVendorName(from: actual)
        let expectedVendor = extractVendorName(from: expected)

        // If both have the same vendor base, they're compatible
        if let actualVendor, let expectedVendor {
            return actualVendor.lowercased() == expectedVendor.lowercased()
        }

        return false
    }

    /// Extracts vendor name from content type
    /// e.g., "application/vnd.spCampaign.v3+json" -> "spcampaign"
    private func extractVendorName(from contentType: String) -> String? {
        guard let vndRange = contentType.range(of: "vnd.") else { return nil }

        let afterVnd = contentType[vndRange.upperBound...]
        // Take everything up to the next dot or plus sign
        if let endIndex = afterVnd.firstIndex(where: { $0 == "." || $0 == "+" }) {
            return String(afterVnd[..<endIndex])
        }
        return String(afterVnd)
    }
}
