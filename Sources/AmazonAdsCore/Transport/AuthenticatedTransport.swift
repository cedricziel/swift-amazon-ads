//
//  AuthenticatedTransport.swift
//  AmazonAdsCore
//
//  ClientTransport wrapper that injects Amazon Advertising API authentication headers
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession
import os.log

private let transportLogger = Logger(subsystem: "com.amazon.ads", category: "transport")

/// A transport that wraps another transport and adds Amazon Advertising API authentication headers
public struct AuthenticatedTransport: ClientTransport {
    /// The underlying transport to use for making requests
    private let underlying: any ClientTransport

    /// Provider for the current access token
    private let tokenProvider: @Sendable () async throws -> String

    /// Amazon Advertising API Client ID
    private let clientId: String

    /// Optional profile ID for scoped requests
    private let profileId: String?

    /// Creates an authenticated transport
    /// - Parameters:
    ///   - underlying: The underlying transport to wrap
    ///   - tokenProvider: A closure that provides the current access token
    ///   - clientId: The Amazon Advertising API Client ID
    ///   - profileId: Optional profile ID to include in requests
    public init(
        underlying: any ClientTransport,
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil
    ) {
        self.underlying = underlying
        self.tokenProvider = tokenProvider
        self.clientId = clientId
        self.profileId = profileId
    }

    /// Creates an authenticated transport using URLSession
    /// - Parameters:
    ///   - tokenProvider: A closure that provides the current access token
    ///   - clientId: The Amazon Advertising API Client ID
    ///   - profileId: Optional profile ID to include in requests
    ///   - configuration: Optional URLSession configuration
    public init(
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil,
        configuration: URLSessionTransport.Configuration = .init()
    ) {
        self.underlying = URLSessionTransport(configuration: configuration)
        self.tokenProvider = tokenProvider
        self.clientId = clientId
        self.profileId = profileId
    }

    public func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var modifiedRequest = request

        // Get the current access token
        let token = try await tokenProvider()
        let tokenPrefix = String(token.prefix(10))
        transportLogger.debug("Transport: Adding Authorization header (token starts with: \(tokenPrefix)...)")

        // Add authorization header (not in OpenAPI spec, so transport must add it)
        modifiedRequest.headerFields.append(HTTPField(name: .authorization, value: "Bearer \(token)"))

        // Only add ClientId and Scope if not already present in the request
        // (The generated client Input already sets these, so avoid duplicates)
        let hasClientId = request.headerFields.contains { $0.name.rawName == "Amazon-Advertising-API-ClientId" }
        let hasScope = request.headerFields.contains { $0.name.rawName == "Amazon-Advertising-API-Scope" }

        if !hasClientId {
            transportLogger.debug("Transport: Adding ClientId header")
            modifiedRequest.headerFields.append(HTTPField(
                name: HTTPField.Name("Amazon-Advertising-API-ClientId")!,
                value: clientId
            ))
        } else {
            transportLogger.debug("Transport: ClientId already present, skipping")
        }

        if !hasScope, let profileId {
            transportLogger.debug("Transport: Adding Scope header: \(profileId)")
            modifiedRequest.headerFields.append(HTTPField(
                name: HTTPField.Name("Amazon-Advertising-API-Scope")!,
                value: profileId
            ))
        } else {
            transportLogger.debug("Transport: Scope already present or not set, skipping")
        }

        return try await underlying.send(modifiedRequest, body: body, baseURL: baseURL, operationID: operationID)
    }
}

/// A transport that allows setting the profile ID dynamically
public final class DynamicProfileTransport: ClientTransport, @unchecked Sendable {
    /// The underlying transport to use for making requests
    private let underlying: any ClientTransport

    /// Provider for the current access token
    private let tokenProvider: @Sendable () async throws -> String

    /// Amazon Advertising API Client ID
    private let clientId: String

    /// Current profile ID (can be changed)
    private var _profileId: String?
    private let lock = NSLock()

    /// Current profile ID for scoped requests
    public var profileId: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _profileId
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _profileId = newValue
        }
    }

    /// Creates a dynamic profile transport
    /// - Parameters:
    ///   - underlying: The underlying transport to wrap
    ///   - tokenProvider: A closure that provides the current access token
    ///   - clientId: The Amazon Advertising API Client ID
    ///   - profileId: Optional initial profile ID
    public init(
        underlying: any ClientTransport,
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil
    ) {
        self.underlying = underlying
        self.tokenProvider = tokenProvider
        self.clientId = clientId
        self._profileId = profileId
    }

    /// Creates a dynamic profile transport using URLSession
    /// - Parameters:
    ///   - tokenProvider: A closure that provides the current access token
    ///   - clientId: The Amazon Advertising API Client ID
    ///   - profileId: Optional initial profile ID
    ///   - configuration: Optional URLSession configuration
    public init(
        tokenProvider: @escaping @Sendable () async throws -> String,
        clientId: String,
        profileId: String? = nil,
        configuration: URLSessionTransport.Configuration = .init()
    ) {
        self.underlying = URLSessionTransport(configuration: configuration)
        self.tokenProvider = tokenProvider
        self.clientId = clientId
        self._profileId = profileId
    }

    public func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var modifiedRequest = request

        // Get the current access token
        let token = try await tokenProvider()
        let tokenPrefix = String(token.prefix(10))
        transportLogger.debug("Transport: Adding Authorization header (token starts with: \(tokenPrefix)...)")

        // Add authorization header (not in OpenAPI spec, so transport must add it)
        modifiedRequest.headerFields.append(HTTPField(name: .authorization, value: "Bearer \(token)"))

        // Only add ClientId and Scope if not already present in the request
        // (The generated client Input already sets these, so avoid duplicates)
        let hasClientId = request.headerFields.contains { $0.name.rawName == "Amazon-Advertising-API-ClientId" }
        let hasScope = request.headerFields.contains { $0.name.rawName == "Amazon-Advertising-API-Scope" }

        if !hasClientId {
            transportLogger.debug("Transport: Adding ClientId header")
            modifiedRequest.headerFields.append(HTTPField(
                name: HTTPField.Name("Amazon-Advertising-API-ClientId")!,
                value: clientId
            ))
        } else {
            transportLogger.debug("Transport: ClientId already present, skipping")
        }

        if !hasScope, let currentProfileId = profileId {
            transportLogger.debug("Transport: Adding Scope header: \(currentProfileId)")
            modifiedRequest.headerFields.append(HTTPField(
                name: HTTPField.Name("Amazon-Advertising-API-Scope")!,
                value: currentProfileId
            ))
        } else {
            transportLogger.debug("Transport: Scope already present or not set, skipping")
        }

        return try await underlying.send(modifiedRequest, body: body, baseURL: baseURL, operationID: operationID)
    }
}
