//
//  Exports.swift
//  AmazonAdsProfilesAPIv2
//
//  Re-exports core types and provides documentation for the Profiles API.
//  The Client and Types are generated at build time by the OpenAPIGenerator plugin.
//

import Foundation

// Re-export OpenAPIRuntime types that consumers may need
@_exported import OpenAPIRuntime

// MARK: - Module Documentation

/// Amazon Advertising Profiles API v2 Client
///
/// This module provides generated Swift types and client for the Amazon Advertising
/// Profiles API v2.
///
/// ## Overview
///
/// Profiles represent an advertiser and their account's marketplace, and are used
/// in all subsequent API calls via a management scope (`Amazon-Advertising-API-Scope`).
/// Reports and all entity management operations are associated with a single profile.
///
/// ## Usage
///
/// ```swift
/// import AmazonAdsProfilesAPIv2
/// import AmazonAdsCore
///
/// // Create authenticated transport
/// let transport = DynamicProfileTransport(
///     tokenProvider: { try await getAccessToken() },
///     clientId: "your-client-id"
/// )
///
/// // Create client for North America
/// let client = Client(
///     serverURL: try Servers.Server1.url(),
///     transport: transport
/// )
///
/// // List profiles
/// let response = try await client.listProfiles(
///     .init(headers: .init(Amazon_hyphen_Advertising_hyphen_API_hyphen_ClientId: clientId))
/// )
/// ```
///
/// ## Regional Endpoints
///
/// - North America: `https://advertising-api.amazon.com` (Server1)
/// - Europe: `https://advertising-api-eu.amazon.com` (Server2)
/// - Far East: `https://advertising-api-fe.amazon.com` (Server3)
public enum AmazonAdsProfilesAPIv2 {}
