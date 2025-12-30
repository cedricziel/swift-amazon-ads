//
//  Extensions.swift
//  AmazonAdsReportingAPIv3
//
//  Public API surface for the generated Reporting API v3 client
//

import Foundation
import AmazonAdsCore
import OpenAPIRuntime
import OpenAPIURLSession

// MARK: - Module Info

/// Module version information
public enum AmazonAdsReportingAPIv3Info {
    /// The API version this module targets
    public static let apiVersion = "v3"

    /// Module version
    public static let moduleVersion = "1.0.0"
}

// MARK: - Type Aliases for Discoverability

/// Reporting API v3 Client
///
/// Use ``ReportingClient/make(region:tokenProvider:clientId:profileId:)`` to create an authenticated client.
///
/// Example:
/// ```swift
/// let client = ReportingClient.make(
///     region: .northAmerica,
///     tokenProvider: { try await authService.getAccessToken() },
///     clientId: "your-client-id",
///     profileId: "your-profile-id"
/// )
///
/// let response = try await client.createAsyncReport(...)
/// ```
public typealias ReportingClient = Client

/// Reporting API v3 Types namespace
public typealias ReportingTypes = Components.Schemas

/// Reporting API v3 Operations namespace
public typealias ReportingOperations = Operations

// MARK: - Client Factory

extension Client {
    /// Creates a Reporting API v3 client configured for the specified Amazon region
    /// - Parameters:
    ///   - region: The Amazon region to connect to
    ///   - tokenProvider: A closure that provides the current OAuth access token
    ///   - clientId: Your Amazon Advertising API Client ID
    ///   - profileId: The profile ID to scope requests to (required for report creation)
    ///   - logLevel: Optional log level for request/response logging (default: none)
    /// - Returns: A configured Reporting API v3 client
    public static func make(
        region: AmazonRegion,
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil,
        logLevel: LogLevel = .none
    ) -> Client {
        let transport = AuthenticatedTransport(
            tokenProvider: tokenProvider,
            clientId: clientId,
            profileId: profileId
        )

        var middlewares: [any ClientMiddleware] = []

        // Add logging middleware if enabled
        if logLevel > .none {
            middlewares.append(LoggingMiddleware(logLevel: logLevel))
        }

        // Add content type normalizing middleware (handles Amazon returning application/json instead of vendor types)
        middlewares.append(ContentTypeNormalizingMiddleware())

        // Add error normalizing middleware (handles Amazon returning text/plain for errors)
        middlewares.append(ErrorNormalizingMiddleware())

        return Client(
            serverURL: region.advertisingAPIBaseURL,
            transport: transport,
            middlewares: middlewares
        )
    }

    /// Creates a Reporting API v3 client with a dynamic profile transport
    ///
    /// Use this when you need to switch profiles without recreating the client.
    /// - Parameters:
    ///   - region: The Amazon region to connect to
    ///   - tokenProvider: A closure that provides the current OAuth access token
    ///   - clientId: Your Amazon Advertising API Client ID
    ///   - profileId: Optional initial profile ID
    ///   - logLevel: Optional log level for request/response logging (default: none)
    /// - Returns: A tuple of the configured client and the transport (for changing profile)
    public static func makeWithDynamicProfile(
        region: AmazonRegion,
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil,
        logLevel: LogLevel = .none
    ) -> (client: Client, transport: DynamicProfileTransport) {
        let transport = DynamicProfileTransport(
            tokenProvider: tokenProvider,
            clientId: clientId,
            profileId: profileId
        )

        var middlewares: [any ClientMiddleware] = []

        // Add logging middleware if enabled
        if logLevel > .none {
            middlewares.append(LoggingMiddleware(logLevel: logLevel))
        }

        // Add content type normalizing middleware (handles Amazon returning application/json instead of vendor types)
        middlewares.append(ContentTypeNormalizingMiddleware())

        // Add error normalizing middleware (handles Amazon returning text/plain for errors)
        middlewares.append(ErrorNormalizingMiddleware())

        let client = Client(
            serverURL: region.advertisingAPIBaseURL,
            transport: transport,
            middlewares: middlewares
        )

        return (client, transport)
    }
}

// MARK: - Report Polling

/// Options for polling async reports
public struct ReportPollingOptions: Sendable {
    /// Maximum number of polling attempts
    public var maxAttempts: Int

    /// Initial delay between polling attempts
    public var initialDelay: Duration

    /// Maximum delay between polling attempts (with exponential backoff)
    public var maxDelay: Duration

    /// Multiplier for exponential backoff
    public var backoffMultiplier: Double

    /// Default polling options
    public static var `default`: ReportPollingOptions {
        .init(
            maxAttempts: 60,           // ~30 minutes with backoff
            initialDelay: .seconds(5),
            maxDelay: .seconds(60),
            backoffMultiplier: 1.5
        )
    }

    public init(
        maxAttempts: Int = 60,
        initialDelay: Duration = .seconds(5),
        maxDelay: Duration = .seconds(60),
        backoffMultiplier: Double = 1.5
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
    }
}

/// Errors that can occur during report polling
public enum ReportPollingError: Error, LocalizedError {
    case reportCreationFailed(String)
    case timeout
    case failed(reason: String?)
    case noDownloadURL
    case downloadFailed(Error)
    case invalidReportId

    public var errorDescription: String? {
        switch self {
        case .reportCreationFailed(let reason):
            "Failed to create report: \(reason)"
        case .timeout:
            "Report generation timed out"
        case .failed(let reason):
            "Report generation failed: \(reason ?? "Unknown reason")"
        case .noDownloadURL:
            "Report completed but no download URL provided"
        case .downloadFailed(let error):
            "Failed to download report: \(error.localizedDescription)"
        case .invalidReportId:
            "Invalid or missing report ID"
        }
    }
}

/// Result of a successful report creation and polling
public struct ReportResult: Sendable {
    /// The unique report ID
    public let reportId: String

    /// The presigned S3 URL to download the report (expires in ~1 hour)
    public let downloadURL: URL

    /// The file size in bytes
    public let fileSize: Int64?

    public init(reportId: String, downloadURL: URL, fileSize: Int64? = nil) {
        self.reportId = reportId
        self.downloadURL = downloadURL
        self.fileSize = fileSize
    }
}

// MARK: - Report Download

import Compression

extension Client {
    /// Downloads and decompresses a gzipped report from the given URL
    /// - Parameter url: The presigned S3 URL from the report status response
    /// - Returns: The decompressed report data
    /// - Throws: `ReportPollingError.downloadFailed` if download or decompression fails
    public func downloadReport(from url: URL) async throws -> Data {
        // Note: The S3 presigned URL should NOT have auth headers
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ReportPollingError.downloadFailed(
                URLError(.badServerResponse)
            )
        }

        // Decompress gzip data
        return try decompressGzip(data)
    }

    /// Downloads, decompresses, and decodes a report as the specified type
    /// - Parameters:
    ///   - url: The presigned S3 URL from the report status response
    ///   - type: The type to decode the JSON as
    /// - Returns: The decoded report data
    public func downloadReport<T: Decodable>(from url: URL, as type: T.Type) async throws -> T {
        let data = try await downloadReport(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Decompresses gzip data using Apple's Compression framework
    private func decompressGzip(_ data: Data) throws -> Data {
        // Check for gzip magic bytes
        guard data.count >= 2,
              data[0] == 0x1f,
              data[1] == 0x8b else {
            // Not gzipped, return as-is
            return data
        }

        // Skip gzip header (minimum 10 bytes)
        // Format: magic(2) + method(1) + flags(1) + mtime(4) + xfl(1) + os(1)
        var headerSize = 10
        let flags = data[3]

        // Check for optional header fields
        if flags & 0x04 != 0 { // FEXTRA
            guard data.count > headerSize + 2 else { throw ReportPollingError.downloadFailed(URLError(.cannotDecodeContentData)) }
            let extraLen = Int(data[headerSize]) | (Int(data[headerSize + 1]) << 8)
            headerSize += 2 + extraLen
        }

        if flags & 0x08 != 0 { // FNAME
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1 // skip null terminator
        }

        if flags & 0x10 != 0 { // FCOMMENT
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1 // skip null terminator
        }

        if flags & 0x02 != 0 { // FHCRC
            headerSize += 2
        }

        guard headerSize < data.count - 8 else {
            throw ReportPollingError.downloadFailed(URLError(.cannotDecodeContentData))
        }

        // Get compressed data (excluding header and trailer)
        let compressedData = data.subdata(in: headerSize..<(data.count - 8))

        // Use Compression framework to decompress
        let decompressed = try compressedData.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Data in
            guard let sourcePtr = rawBuffer.baseAddress else {
                throw ReportPollingError.downloadFailed(URLError(.cannotDecodeContentData))
            }

            // Allocate destination buffer (start with 4x size, will grow if needed)
            var destinationBuffer = [UInt8](repeating: 0, count: compressedData.count * 4)
            var destinationSize = destinationBuffer.count

            while true {
                let result = compression_decode_buffer(
                    &destinationBuffer,
                    destinationSize,
                    sourcePtr.assumingMemoryBound(to: UInt8.self),
                    compressedData.count,
                    nil,
                    COMPRESSION_ZLIB
                )

                if result == 0 {
                    throw ReportPollingError.downloadFailed(URLError(.cannotDecodeContentData))
                }

                if result < destinationSize {
                    // Success - return the decompressed data
                    return Data(destinationBuffer.prefix(result))
                }

                // Buffer too small, double it and try again
                destinationSize *= 2
                destinationBuffer = [UInt8](repeating: 0, count: destinationSize)
            }
        }

        return decompressed
    }
}
