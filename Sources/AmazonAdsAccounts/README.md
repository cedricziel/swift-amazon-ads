# AmazonAdsAccounts

OpenAPI-generated Swift client for the Amazon Advertising Accounts API.

## Overview

This package provides a type-safe client for managing Amazon Advertising accounts and profiles. Use this API to discover available advertising accounts before making calls to other APIs.

**Generated from**: `AdvertisingAccounts_prod_3p.json`
**Lines of code**: ~3,600

## Installation

```swift
.product(name: "AmazonAdsAccounts", package: "swift-amazon-ads")
```

## Quick Start

```swift
import AmazonAdsCore
import AmazonAdsAccounts

// Create an authenticated client (no profile ID needed)
let client = AccountsClient.make(
    region: .northAmerica,
    tokenProvider: { try await myAuthService.getAccessToken() },
    clientId: "amzn1.application-oa2-client.xxxxx"
)
```

## Type Aliases

| Alias | Full Type |
|-------|-----------|
| `AccountsClient` | `Client` |
| `AccountsTypes` | `Components.Schemas` |
| `AccountsOperations` | `Operations` |
| `AdsAccount` | `Components.Schemas.AdsAccount` |
| `AdsAccountWithMetaData` | `Components.Schemas.AdsAccountWithMetaData` |

## Factory Method

The Accounts API typically doesn't require a profile ID since it's used to discover available profiles:

```swift
let client = AccountsClient.make(
    region: .northAmerica,
    tokenProvider: { try await getToken() },
    clientId: "your-client-id"
)
```

## Typical Workflow

1. **Authenticate** - Get OAuth tokens
2. **List Accounts** - Use Accounts API to discover available profiles
3. **Select Profile** - User selects which account/profile to use
4. **Use Other APIs** - Use SP v3 or unified API with the selected profile ID

```swift
// 1. Get accounts
let accountsClient = AccountsClient.make(
    region: .northAmerica,
    tokenProvider: { try await getToken() },
    clientId: clientId
)

let accountsResponse = try await accountsClient.listAccounts(...)

// 2. Extract profile IDs from response
// 3. Create SP client with selected profile
let spClient = SponsoredProductsClient.make(
    region: .northAmerica,
    tokenProvider: { try await getToken() },
    clientId: clientId,
    profileId: selectedProfileId
)
```

## Regenerating

To regenerate after spec updates:

```bash
make generate-accounts
```
