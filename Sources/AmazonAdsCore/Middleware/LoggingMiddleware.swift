//
//  LoggingMiddleware.swift
//  AmazonAdsCore
//
//  Middleware that logs HTTP requests and responses for debugging
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import os.log

/// Log level for the logging middleware
public enum LogLevel: Int, Comparable, Sendable {
    case none = 0
    case error = 1
    case info = 2
    case debug = 3
    case verbose = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A middleware that logs HTTP requests and responses for debugging
///
/// Use this middleware to diagnose API issues by logging request/response details.
///
/// Example:
/// ```swift
/// let client = SponsoredProductsClient.make(
///     region: .northAmerica,
///     tokenProvider: { try await getToken() },
///     clientId: "your-client-id",
///     profileId: "your-profile-id",
///     logLevel: .debug
/// )
/// ```
public struct LoggingMiddleware: ClientMiddleware {
    private let logLevel: LogLevel
    private let logger: Logger
    private let redactHeaders: Set<String>
    private let maxBodyLogLength: Int

    /// Creates a new logging middleware
    /// - Parameters:
    ///   - logLevel: The level of detail to log (default: .info)
    ///   - subsystem: The subsystem for os_log (default: "com.amazon.ads")
    ///   - category: The category for os_log (default: "api")
    ///   - redactHeaders: Headers to redact from logs (default: Authorization, Amazon-Advertising-API-ClientId)
    ///   - maxBodyLogLength: Maximum length of request/response body to log (default: 2000)
    public init(
        logLevel: LogLevel = .info,
        subsystem: String = "com.amazon.ads",
        category: String = "api",
        redactHeaders: Set<String> = ["Authorization", "Amazon-Advertising-API-ClientId"],
        maxBodyLogLength: Int = 2000
    ) {
        self.logLevel = logLevel
        self.logger = Logger(subsystem: subsystem, category: category)
        self.redactHeaders = redactHeaders
        self.maxBodyLogLength = maxBodyLogLength
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let requestID = UUID().uuidString.prefix(8)
        let startTime = Date()

        // Log request
        logRequest(request, body: body, baseURL: baseURL, operationID: operationID, requestID: String(requestID))

        do {
            let (response, responseBody) = try await next(request, body, baseURL)
            let duration = Date().timeIntervalSince(startTime)

            // Log response
            logResponse(response, body: responseBody, operationID: operationID, requestID: String(requestID), duration: duration)

            return (response, responseBody)
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            // Log error
            logError(error, operationID: operationID, requestID: String(requestID), duration: duration)

            throw error
        }
    }

    // MARK: - Private Logging Methods

    private func logRequest(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String, requestID: String) {
        guard logLevel >= .info else { return }

        let method = request.method.rawValue
        let path = request.path ?? "/"
        let fullURL = baseURL.appendingPathComponent(path)

        logger.info("[\(requestID)] → \(method) \(fullURL.absoluteString) (\(operationID))")

        if logLevel >= .debug {
            logHeaders(request.headerFields, prefix: "[\(requestID)] → Header", isRequest: true)
        }

        if logLevel >= .verbose, body != nil {
            logger.debug("[\(requestID)] → Body: [async body - not logged synchronously]")
        }
    }

    private func logResponse(_ response: HTTPResponse, body: HTTPBody?, operationID: String, requestID: String, duration: TimeInterval) {
        let statusCode = response.status.code
        let durationMs = String(format: "%.0f", duration * 1000)

        if statusCode >= 400 {
            // Log errors at error level
            logger.error("[\(requestID)] ← \(statusCode) (\(durationMs)ms) \(operationID)")

            if logLevel >= .info {
                logHeaders(response.headerFields, prefix: "[\(requestID)] ← Header", isRequest: false)
            }

            // Try to log error body
            if logLevel >= .debug, let body {
                logBody(body, prefix: "[\(requestID)] ← Body", requestID: requestID)
            }
        } else {
            // Log success at info level
            logger.info("[\(requestID)] ← \(statusCode) (\(durationMs)ms) \(operationID)")

            if logLevel >= .debug {
                logHeaders(response.headerFields, prefix: "[\(requestID)] ← Header", isRequest: false)
            }

            if logLevel >= .verbose, let body {
                logBody(body, prefix: "[\(requestID)] ← Body", requestID: requestID)
            }
        }
    }

    private func logError(_ error: Error, operationID: String, requestID: String, duration: TimeInterval) {
        let durationMs = String(format: "%.0f", duration * 1000)
        let errorDescription = String(describing: error)

        logger.error("[\(requestID)] ✗ Error (\(durationMs)ms) \(operationID): \(errorDescription)")
    }

    private func logHeaders(_ headers: HTTPFields, prefix: String, isRequest: Bool) {
        for field in headers {
            let name = field.name.rawName
            let value: String

            if redactHeaders.contains(name) {
                value = "[REDACTED]"
            } else {
                value = field.value
            }

            logger.debug("\(prefix): \(name): \(value)")
        }
    }

    private func logBody(_ body: HTTPBody, prefix: String, requestID: String) {
        // Note: We can't easily log the body synchronously without consuming it
        // This is logged as a placeholder - actual body logging would require
        // wrapping the body stream
        logger.debug("\(prefix): [body present - length unknown]")
    }
}

// MARK: - Convenience Extensions

extension LoggingMiddleware {
    /// Creates a logging middleware with verbose output for development
    public static var verbose: LoggingMiddleware {
        LoggingMiddleware(logLevel: .verbose)
    }

    /// Creates a logging middleware that only logs errors
    public static var errorsOnly: LoggingMiddleware {
        LoggingMiddleware(logLevel: .error)
    }

    /// Creates a logging middleware with standard info-level logging
    public static var standard: LoggingMiddleware {
        LoggingMiddleware(logLevel: .info)
    }

    /// Creates a logging middleware with debug-level logging
    public static var debug: LoggingMiddleware {
        LoggingMiddleware(logLevel: .debug)
    }
}
