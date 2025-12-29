//
//  ErrorNormalizingMiddleware.swift
//  AmazonAdsCore
//
//  Middleware that normalizes error responses from Amazon Advertising API
//  to handle cases where the API returns text/plain instead of application/json
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// A middleware that normalizes error responses from the Amazon Advertising API
///
/// Amazon's API sometimes returns error responses with `text/plain` content type
/// instead of `application/json`, which causes the generated OpenAPI client to fail
/// with "Unexpected content type" errors. This middleware intercepts error responses
/// and normalizes them to JSON format.
public struct ErrorNormalizingMiddleware: ClientMiddleware {
    /// Creates a new error normalizing middleware
    public init() {}

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)

        // Check if this is an error response (4xx or 5xx)
        let statusCode = response.status.code
        guard statusCode >= 400 else {
            return (response, responseBody)
        }

        // Check if the content type is text/plain (or missing)
        let contentType = response.headerFields[.contentType]
        let isTextPlain = contentType?.contains("text/plain") == true
        let isNotJSON = contentType?.contains("application/json") != true

        // If it's an error response with non-JSON content type, normalize it
        if isTextPlain || (isNotJSON && contentType != nil) {
            // Read the body content if available
            var bodyText = ""
            if let responseBody {
                do {
                    var data = Data()
                    for try await chunk in responseBody {
                        data.append(contentsOf: chunk)
                    }
                    bodyText = String(data: data, encoding: .utf8) ?? ""
                } catch {
                    bodyText = "Failed to read error body"
                }
            }

            // Create a JSON error response
            let errorMessage = bodyText.isEmpty ? "HTTP \(statusCode) error" : bodyText
            let jsonError: [String: Any] = [
                "code": statusCode,
                "message": errorMessage,
            ]

            if let jsonData = try? JSONSerialization.data(withJSONObject: jsonError) {
                // Create a new response with JSON content type
                var modifiedResponse = response
                modifiedResponse.headerFields[.contentType] = "application/json"

                // Create new body from JSON data
                let newBody = makeHTTPBody(from: jsonData)

                return (modifiedResponse, newBody)
            }
        }

        return (response, responseBody)
    }
}

// MARK: - HTTPBody Helper

/// Creates an HTTPBody from data
private func makeHTTPBody(from data: Data) -> HTTPBody {
    HTTPBody(data)
}
