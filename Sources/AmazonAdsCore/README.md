# AmazonAdsCore

Shared foundation for all Amazon Ads API clients, providing authentication, transport, and common types.

## Overview

`AmazonAdsCore` provides the building blocks used by all generated API clients:

- **Authentication** - OAuth token management and storage
- **Transport** - HTTP transport with automatic auth header injection
- **Types** - Common types like regions and error handling

## Installation

```swift
.product(name: "AmazonAdsCore", package: "swift-amazon-ads")
```

## Components

### AmazonRegion

Enum representing Amazon Advertising API regions:

```swift
public enum AmazonRegion: String, CaseIterable {
    case northAmerica = "NA"  // advertising-api.amazon.com
    case europe = "EU"        // advertising-api-eu.amazon.com
    case farEast = "FE"       // advertising-api-fe.amazon.com
}

// Get the API base URL for a region
let url = AmazonRegion.northAmerica.advertisingAPIBaseURL
// https://advertising-api.amazon.com

// Get OAuth endpoints
let tokenURL = AmazonRegion.northAmerica.tokenEndpoint
let authURL = AmazonRegion.northAmerica.authorizationURL
```

### AuthenticatedTransport

A `ClientTransport` wrapper that automatically injects Amazon auth headers:

```swift
import AmazonAdsCore
import OpenAPIURLSession

let transport = AuthenticatedTransport(
    tokenProvider: { try await myAuthService.getAccessToken() },
    clientId: "amzn1.application-oa2-client.xxxxx",
    profileId: "1234567890"
)

// Headers automatically added to every request:
// - Authorization: Bearer <token>
// - Amazon-Advertising-API-ClientId: <clientId>
// - Amazon-Advertising-API-Scope: <profileId>
```

### DynamicProfileTransport

Like `AuthenticatedTransport`, but allows changing the profile ID at runtime:

```swift
let transport = DynamicProfileTransport(
    tokenProvider: { try await myAuthService.getAccessToken() },
    clientId: "your-client-id",
    profileId: "initial-profile"
)

// Later, switch to a different profile
transport.profileId = "different-profile"
```

### TokenStorageKey

Standard key names for token storage:

```swift
public enum TokenStorageKey {
    public static let accessToken = "amazon_access_token"
    public static let refreshToken = "amazon_refresh_token"
    public static let tokenExpiry = "amazon_token_expiry"
}
```

## Usage with Generated Clients

All generated clients (SP v3, API v1, Accounts) use `AmazonAdsCore` for authentication:

```swift
import AmazonAdsCore
import AmazonAdsSponsoredProductsAPIv3

// The generated client's make() factory uses AuthenticatedTransport internally
let client = SponsoredProductsClient.make(
    region: .northAmerica,
    tokenProvider: { try await getMyToken() },
    clientId: "your-client-id",
    profileId: "your-profile-id"
)
```

## Custom Transport

You can also create custom transports by wrapping `AuthenticatedTransport`:

```swift
import AmazonAdsCore
import OpenAPIRuntime

struct LoggingTransport: ClientTransport {
    private let wrapped: AuthenticatedTransport

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        print("Calling: \(operationID)")
        return try await wrapped.send(request, body: body, baseURL: baseURL, operationID: operationID)
    }
}
```
