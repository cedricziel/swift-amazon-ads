# AmazonAdsProfilesAPIv2

Generated Swift client for Amazon Advertising Profiles API v2.

## Overview

This target provides access to the Amazon Advertising Profiles API, which allows you to:

- List advertising profiles for an account
- Get profile details by ID
- Update profile settings (daily budget for sellers)

## Generation

This client is auto-generated from the OpenAPI specification. To regenerate:

```bash
make generate-profiles
```

## API Endpoints

- `GET /v2/profiles` - List all profiles
- `GET /v2/profiles/{profileId}` - Get profile by ID
- `PUT /v2/profiles` - Update profile(s)

## Regional Endpoints

The API supports three regional endpoints:

- **North America**: `https://advertising-api.amazon.com`
- **Europe**: `https://advertising-api-eu.amazon.com`
- **Far East**: `https://advertising-api-fe.amazon.com`

## Usage

```swift
import AmazonAdsProfilesAPIv2
import AmazonAdsCore

// Create authenticated transport
let transport = AuthenticatedTransport(
    tokenProvider: { try await getAccessToken() },
    clientId: "your-client-id"
)

// Create client for North America
let client = Client(
    serverURL: try Servers.Server1.url(),
    transport: transport
)

// List profiles
let response = try await client.listProfiles(
    .init(headers: .init(Amazon_hyphen_Advertising_hyphen_API_hyphen_ClientId: clientId))
)
```
