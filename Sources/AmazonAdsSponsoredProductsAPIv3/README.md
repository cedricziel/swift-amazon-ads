# AmazonAdsSponsoredProductsAPIv3

OpenAPI-generated Swift client for the Amazon Sponsored Products API v3.

## Overview

This package provides a complete, type-safe client for managing Sponsored Products campaigns, ad groups, keywords, targets, and product ads.

**Generated from**: `SponsoredProducts_prod_3p.json`
**Lines of code**: ~81,000
**API Version**: v3

## Installation

```swift
.product(name: "AmazonAdsSponsoredProductsAPIv3", package: "swift-amazon-ads")
```

## Quick Start

```swift
import AmazonAdsCore
import AmazonAdsSponsoredProductsAPIv3

// Create an authenticated client
let client = SponsoredProductsClient.make(
    region: .northAmerica,
    tokenProvider: { try await myAuthService.getAccessToken() },
    clientId: "amzn1.application-oa2-client.xxxxx",
    profileId: "1234567890"
)

// List campaigns
let response = try await client.listSponsoredProductsCampaigns(.init(
    headers: .init(
        Amazon_hyphen_Advertising_hyphen_API_hyphen_ClientId: clientId,
        Amazon_hyphen_Advertising_hyphen_API_hyphen_Scope: profileId
    )
))
```

## Type Aliases

For convenience, common types are aliased:

| Alias | Full Type |
|-------|-----------|
| `SponsoredProductsClient` | `Client` |
| `SponsoredProductsTypes` | `Components.Schemas` |
| `SponsoredProductsOperations` | `Operations` |
| `SPCampaign` | `Components.Schemas.SponsoredProductsCampaign` |
| `SPAdGroup` | `Components.Schemas.SponsoredProductsAdGroup` |
| `SPKeyword` | `Components.Schemas.SponsoredProductsKeyword` |
| `SPProductAd` | `Components.Schemas.SponsoredProductsProductAd` |
| `SPTarget` | `Components.Schemas.SponsoredProductsTargetingClause` |
| `SPBudget` | `Components.Schemas.SponsoredProductsBudget` |

## Factory Methods

### Standard Client

```swift
let client = SponsoredProductsClient.make(
    region: .northAmerica,
    tokenProvider: { try await getToken() },
    clientId: "your-client-id",
    profileId: "your-profile-id"
)
```

### Dynamic Profile Client

Switch profiles without recreating the client:

```swift
let (client, transport) = SponsoredProductsClient.makeWithDynamicProfile(
    region: .northAmerica,
    tokenProvider: { try await getToken() },
    clientId: "your-client-id"
)

// Switch profiles
transport.profileId = "profile-1"
// ... make requests ...
transport.profileId = "profile-2"
// ... make requests with different profile ...
```

## API Operations

### Campaigns

```swift
// List campaigns
let list = try await client.listSponsoredProductsCampaigns(...)

// Create campaigns
let create = try await client.CreateSponsoredProductsCampaigns(...)

// Update campaigns
let update = try await client.UpdateSponsoredProductsCampaigns(...)

// Delete campaigns
let delete = try await client.DeleteSponsoredProductsCampaigns(...)
```

### Ad Groups

```swift
let adGroups = try await client.listSponsoredProductsAdGroups(...)
let create = try await client.CreateSponsoredProductsAdGroups(...)
```

### Keywords

```swift
let keywords = try await client.listSponsoredProductsKeywords(...)
let create = try await client.CreateSponsoredProductsKeywords(...)
```

### Targets

```swift
let targets = try await client.listSponsoredProductsTargetingClauses(...)
let create = try await client.CreateSponsoredProductsTargetingClauses(...)
```

### Product Ads

```swift
let ads = try await client.listSponsoredProductsProductAds(...)
let create = try await client.CreateSponsoredProductsProductAds(...)
```

## Response Handling

The SP v3 API uses HTTP 207 Multi-Status responses for batch operations:

```swift
let response = try await client.CreateSponsoredProductsCampaigns(...)

switch response {
case .ok(let success):
    // All items succeeded
    break
case .code207(let multiStatus):
    // Mixed results - check each item
    for item in multiStatus.body.json.campaigns.success {
        print("Created: \(item.campaignId)")
    }
    for item in multiStatus.body.json.campaigns.error {
        print("Failed: \(item.errorValue)")
    }
case .badRequest(let error):
    print("Bad request: \(error)")
default:
    break
}
```

## Regenerating

To regenerate after spec updates:

```bash
make generate-sp
```
