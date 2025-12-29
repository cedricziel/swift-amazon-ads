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

        // Add authorization header
        modifiedRequest.headerFields.append(HTTPField(name: .authorization, value: "Bearer \(token)"))

        // Add client ID header
        modifiedRequest.headerFields.append(HTTPField(
            name: HTTPField.Name("Amazon-Advertising-API-ClientId")!,
            value: clientId
        ))

        // Add profile ID header if provided
        if let profileId = profileId {
            modifiedRequest.headerFields.append(HTTPField(
                name: HTTPField.Name("Amazon-Advertising-API-Scope")!,
                value: profileId
            ))
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

        // Add authorization header
        modifiedRequest.headerFields.append(HTTPField(name: .authorization, value: "Bearer \(token)"))

        // Add client ID header
        modifiedRequest.headerFields.append(HTTPField(
            name: HTTPField.Name("Amazon-Advertising-API-ClientId")!,
            value: clientId
        ))

        // Add profile ID header if set
        if let currentProfileId = profileId {
            modifiedRequest.headerFields.append(HTTPField(
                name: HTTPField.Name("Amazon-Advertising-API-Scope")!,
                value: currentProfileId
            ))
        }

        return try await underlying.send(modifiedRequest, body: body, baseURL: baseURL, operationID: operationID)
    }
}
