# Amazon Ads Swift SDK

A modern Swift SDK for the Amazon Advertising API, featuring OpenAPI-generated clients with full type safety and async/await support.

## Packages

| Package | Description |
|---------|-------------|
| [`AmazonAdsCore`](Sources/AmazonAdsCore/) | Shared authentication, transport, and types |
| [`AmazonAdsSponsoredProductsAPIv3`](Sources/AmazonAdsSponsoredProductsAPIv3/) | Sponsored Products API v3 (generated) |
| [`AmazonAdsAPIv1`](Sources/AmazonAdsAPIv1/) | Unified Amazon Ads API v1 (generated) |
| [`AmazonAdsAccounts`](Sources/AmazonAdsAccounts/) | Accounts/Profiles API (generated) |
| [`LegacyAmazonAdsSponsoredProductsAPIv3`](Sources/LegacyAmazonAdsSponsoredProductsAPIv3/) | Legacy handwritten SP v3 client |

## Features

- ✅ **OpenAPI Generated** - Type-safe clients generated from official Amazon OpenAPI specs
- ✅ **OAuth 2.0 with PKCE** - Secure authorization flow
- ✅ **Multi-region Support** - North America, Europe, and Far East
- ✅ **Async/Await** - Modern Swift concurrency throughout
- ✅ **Automatic Auth Headers** - `AuthenticatedTransport` injects auth automatically
- ✅ **Dynamic Profiles** - Switch profiles without recreating clients
- ✅ **150k+ Lines Generated** - Complete API coverage

## Requirements

- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+ / visionOS 1.0+
- Swift 5.9+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/cedricziel/swift-amazon-ads.git", from: "1.0.0")
]
```

Then add the products you need:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "AmazonAdsCore", package: "swift-amazon-ads"),
        .product(name: "AmazonAdsSponsoredProductsAPIv3", package: "swift-amazon-ads"),
        // Add others as needed
    ]
)
```

## Quick Start

### 1. Create an Authenticated Client

```swift
import AmazonAdsCore
import AmazonAdsSponsoredProductsAPIv3

// Create a Sponsored Products client
let client = SponsoredProductsClient.make(
    region: .northAmerica,
    tokenProvider: { try await myAuthService.getAccessToken() },
    clientId: "amzn1.application-oa2-client.xxxxx",
    profileId: "1234567890"
)
```

### 2. Make API Calls

```swift
// List campaigns
let response = try await client.listSponsoredProductsCampaigns(.init(
    headers: .init(
        Amazon_hyphen_Advertising_hyphen_API_hyphen_ClientId: clientId,
        Amazon_hyphen_Advertising_hyphen_API_hyphen_Scope: profileId
    )
))

switch response {
case .ok(let result):
    // Handle success
    print("Found campaigns")
case .code207(let multiStatus):
    // Handle multi-status response
    break
default:
    // Handle errors
    break
}
```

### 3. Dynamic Profile Switching

```swift
// Create client with dynamic profile support
let (client, transport) = SponsoredProductsClient.makeWithDynamicProfile(
    region: .northAmerica,
    tokenProvider: { try await myAuthService.getAccessToken() },
    clientId: "your-client-id"
)

// Switch profiles without recreating client
transport.profileId = "new-profile-id"
```

## Package Details

### AmazonAdsCore

Shared functionality used by all API clients:

- `AmazonRegion` - API regions with endpoints
- `AuthenticatedTransport` - Injects auth headers into requests
- `DynamicProfileTransport` - Allows changing profile at runtime
- `TokenStorageKey` - Standard key names for token storage

### AmazonAdsSponsoredProductsAPIv3

Generated client for Sponsored Products API v3:

```swift
import AmazonAdsSponsoredProductsAPIv3

// Type aliases for convenience
let client: SponsoredProductsClient = ...
let campaign: SPCampaign = ...
let adGroup: SPAdGroup = ...
```

### AmazonAdsAPIv1

Generated client for the unified Amazon Ads API:

```swift
import AmazonAdsAPIv1

let client: AmazonAdsClient = ...
let campaign: Campaign = ...
```

### AmazonAdsAccounts

Generated client for Accounts/Profiles API:

```swift
import AmazonAdsAccounts

let client: AccountsClient = ...
let account: AdsAccount = ...
```

## Development

### Building

```bash
make build
```

### Testing

```bash
make test
```

### Regenerating OpenAPI Clients

When Amazon updates their OpenAPI specs:

```bash
# Update specs from specs/ directory
make update-specs

# Regenerate all clients
make generate

# Or regenerate individually
make generate-sp      # Sponsored Products v3
make generate-api     # Unified API v1
make generate-accounts # Accounts API
```

### Project Structure

```
swift-amazon-ads/
├── Sources/
│   ├── AmazonAdsCore/                          # Shared auth & types
│   │   ├── Auth/
│   │   ├── Transport/
│   │   └── Types/
│   ├── AmazonAdsSponsoredProductsAPIv3/        # Generated SP v3
│   │   ├── GeneratedSources/
│   │   ├── Extensions.swift
│   │   └── openapi.json
│   ├── AmazonAdsAPIv1/                         # Generated unified API
│   ├── AmazonAdsAccounts/                      # Generated accounts API
│   └── LegacyAmazonAdsSponsoredProductsAPIv3/  # Handwritten legacy
├── Tests/
├── specs/                                       # OpenAPI source specs
└── Makefile
```

## API Coverage

### Sponsored Products v3 (AmazonAdsSponsoredProductsAPIv3)

- Campaigns (CRUD, list, archive)
- Ad Groups (CRUD, list)
- Keywords (CRUD, list)
- Product Ads (CRUD, list)
- Targets (CRUD, list)
- Negative Keywords & Targets
- Budget Recommendations
- Bid Recommendations

### Unified API v1 (AmazonAdsAPIv1)

- Cross-product campaign management
- Ad associations
- Budget rules
- Moderation

### Accounts (AmazonAdsAccounts)

- List advertising accounts
- Account metadata

## Getting Amazon API Credentials

1. Register at [advertising.amazon.com](https://advertising.amazon.com)
2. Complete API onboarding
3. Create an API application
4. Add `http://localhost:8765/callback` as redirect URI

## Contributing

Contributions welcome! Please submit a Pull Request.

## License

Apache License 2.0 - see LICENSE file.

## Author

Cedric Ziel ([@cedricziel](https://github.com/cedricziel))
