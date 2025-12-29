# AmazonAdsAPIv1

OpenAPI-generated Swift client for the unified Amazon Ads API v1.

## Overview

This package provides a type-safe client for the unified Amazon Advertising API, which offers cross-product campaign management capabilities.

**Generated from**: `AmazonAdsAPIALLMerged_prod_3p.json`
**Lines of code**: ~65,000
**API Version**: v1

## Installation

```swift
.product(name: "AmazonAdsAPIv1", package: "swift-amazon-ads")
```

## Quick Start

```swift
import AmazonAdsCore
import AmazonAdsAPIv1

// Create an authenticated client
let client = AmazonAdsClient.make(
    region: .northAmerica,
    tokenProvider: { try await myAuthService.getAccessToken() },
    clientId: "amzn1.application-oa2-client.xxxxx",
    profileId: "1234567890"
)
```

## Type Aliases

| Alias | Full Type |
|-------|-----------|
| `AmazonAdsClient` | `Client` |
| `AmazonAdsTypes` | `Components.Schemas` |
| `AmazonAdsOperations` | `Operations` |
| `Ad` | `Components.Schemas.Ad` |
| `Campaign` | `Components.Schemas.Campaign` |
| `AdGroup` | `Components.Schemas.AdGroup` |

## Factory Methods

### Standard Client

```swift
let client = AmazonAdsClient.make(
    region: .northAmerica,
    tokenProvider: { try await getToken() },
    clientId: "your-client-id",
    profileId: "your-profile-id"
)
```

### Dynamic Profile Client

```swift
let (client, transport) = AmazonAdsClient.makeWithDynamicProfile(
    region: .northAmerica,
    tokenProvider: { try await getToken() },
    clientId: "your-client-id"
)

// Switch profiles at runtime
transport.profileId = "new-profile-id"
```

## API Coverage

The unified API v1 includes:

- Campaign management across ad products
- Ad group operations
- Ad associations
- Budget rules and management
- Moderation endpoints
- Cross-marketplace operations

## Regenerating

To regenerate after spec updates:

```bash
make generate-api
```
