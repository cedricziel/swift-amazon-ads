# LegacyAmazonAdsSponsoredProductsAPIv3

Original handwritten Swift client for the Amazon Sponsored Products API v3.

## Overview

This package contains the original, manually-written implementation of the Sponsored Products v3 client. It's preserved for backwards compatibility and as a reference implementation.

> **Note**: For new projects, consider using `AmazonAdsSponsoredProductsAPIv3` (the OpenAPI-generated version) instead.

## Installation

```swift
.product(name: "LegacyAmazonAdsSponsoredProductsAPIv3", package: "swift-amazon-ads")
```

## Features

- Full OAuth 2.0 with PKCE implementation
- Token management with automatic refresh
- Campaign CRUD operations
- Ad Group management
- Keyword and Target operations
- Product Ad management

## Usage

```swift
import LegacyAmazonAdsSponsoredProductsAPIv3

let client = AmazonAdvertisingClient(
    clientId: "your-client-id",
    clientSecret: "your-client-secret",
    storage: yourTokenStorage
)

// Authenticate
let authURL = try await client.initiateAuthorization(for: .northAmerica)

// After authentication, fetch campaigns
let campaigns = try await client.getCampaigns(profileId: "123456")
```

## Migration to Generated Client

The generated `AmazonAdsSponsoredProductsAPIv3` package provides:

- Complete API coverage from OpenAPI spec
- Type-safe request/response handling
- Better IDE autocomplete
- Automatic updates when specs change

To migrate:

```swift
// Old (Legacy)
import LegacyAmazonAdsSponsoredProductsAPIv3
let client = AmazonAdvertisingClient(...)
let campaigns = try await client.getCampaigns(profileId: "123")

// New (Generated)
import AmazonAdsSponsoredProductsAPIv3
let client = SponsoredProductsClient.make(region: .northAmerica, ...)
let response = try await client.listSponsoredProductsCampaigns(...)
```

## When to Use Legacy

- Existing projects already using this client
- Need specific customizations not available in generated client
- Reference for understanding API behavior
