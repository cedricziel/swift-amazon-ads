# AmazonAdvertisingAPI

A modern Swift package for integrating with the Amazon Advertising API. This package provides a clean, protocol-based interface for OAuth authentication, token management, and API operations.

## Features

- ✅ **OAuth 2.0 with PKCE** - Secure authorization flow with local callback server
- ✅ **Protocol-based Design** - Fully testable with dependency injection
- ✅ **Token Management** - Automatic token refresh and expiry handling
- ✅ **Customizable HTML** - Provide your own success/error pages for OAuth callbacks
- ✅ **Storage Agnostic** - Implement your own storage (Keychain, UserDefaults, etc.)
- ✅ **Multi-region Support** - North America, Europe, and Far East regions
- ✅ **Async/Await** - Modern Swift concurrency throughout
- ✅ **Type-safe** - Strongly typed models and enums
- ✅ **Comprehensive Tests** - Full test coverage with mocks

## Requirements

- iOS 16.0+
- macOS 13.0+
- tvOS 16.0+
- watchOS 9.0+
- visionOS 1.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/cedricziel/swift-amazon-ads.git", from: "0.1.0")
]
```

Or add it via Xcode:
1. File > Add Package Dependencies
2. Enter package URL: `https://github.com/cedricziel/swift-amazon-ads.git`
3. Select version: `0.1.0` or later

## Quick Start

### 1. Implement Token Storage

First, implement the `TokenStorageProtocol` to store tokens securely. Here's a Keychain example:

```swift
import Security
import AmazonAdvertisingAPI

actor KeychainTokenStorage: TokenStorageProtocol {
    func save(_ value: String, for key: String, region: AmazonRegion) throws {
        let storageKey = "\(region.rawValue)_\(key)"
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: storageKey,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TokenStorageError.storageError("Keychain save failed")
        }
    }

    func retrieve(for key: String, region: AmazonRegion) throws -> String {
        let storageKey = "\(region.rawValue)_\(key)"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: storageKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw TokenStorageError.notFound
        }

        return value
    }

    func exists(for key: String, region: AmazonRegion) -> Bool {
        (try? retrieve(for: key, region: region)) != nil
    }

    func delete(for key: String, region: AmazonRegion) throws {
        let storageKey = "\(region.rawValue)_\(key)"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: storageKey
        ]

        SecItemDelete(query as CFDictionary)
    }

    func deleteAll(for region: AmazonRegion) throws {
        // Implementation to delete all keys for region
    }
}
```

### 2. Initialize the Client

```swift
import AmazonAdvertisingAPI

let storage = KeychainTokenStorage()
let client = AmazonAdvertisingClient(
    clientId: "your-client-id",
    clientSecret: "your-client-secret",
    storage: storage
)
```

### 3. Authenticate

```swift
import AmazonAdvertisingAPI

// Initiate OAuth flow
let authURL = try await client.initiateAuthorization(for: .northAmerica)

// Open the URL in a browser (platform-specific)
#if os(macOS)
NSWorkspace.shared.open(authURL)
#elseif os(iOS)
await UIApplication.shared.open(authURL)
#endif

// The client will automatically handle the callback and exchange tokens
// Wait for the flow to complete (OAuth server runs in background)
```

### 4. Fetch Profiles

```swift
// Check if authenticated
if await client.isAuthenticated(for: .northAmerica) {
    // Fetch advertising profiles
    let profiles = try await client.fetchProfiles(for: .northAmerica)

    for profile in profiles {
        print("Profile: \(profile.accountInfo.name)")
        print("Profile ID: \(profile.profileId)")
    }

    // Or fetch manager accounts (for Merch By Amazon)
    let managerAccounts = try await client.fetchManagerAccounts(for: .northAmerica)

    for account in managerAccounts.managerAccounts {
        print("Manager Account: \(account.managerAccountName)")
        for linkedAccount in account.linkedAccounts {
            print("  Linked Profile: \(linkedAccount.profileId)")
        }
    }
}
```

## Advanced Usage

### Custom HTML Provider

Provide your own branded success/error pages for the OAuth callback:

```swift
struct CustomHTMLProvider: OAuthHTMLProvider {
    func successHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head><title>Success!</title></head>
        <body>
            <h1>Authentication successful!</h1>
            <p>You can close this window.</p>
        </body>
        </html>
        """
    }

    func errorHTML(message: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head><title>Error</title></head>
        <body>
            <h1>Authentication failed</h1>
            <p>\(message)</p>
        </body>
        </html>
        """
    }
}

let client = AmazonAdvertisingClient(
    clientId: "your-client-id",
    clientSecret: "your-client-secret",
    storage: storage,
    htmlProvider: CustomHTMLProvider()
)
```

### Token Refresh

The client automatically refreshes tokens when they expire (within 5 minutes of expiry):

```swift
// Get access token (automatically refreshes if needed)
let accessToken = try await client.getAccessToken(for: .northAmerica)

// Or manually refresh
try await client.refreshToken(for: .northAmerica)
```

### Logout

```swift
// Clear all tokens for a region
try await client.logout(for: .northAmerica)
```

### Verify Connection

```swift
// Test if API credentials are valid and account has access
let isValid = try await client.verifyConnection(for: .northAmerica)
```

## API Coverage

### Currently Implemented

- ✅ OAuth 2.0 authorization with PKCE
- ✅ Token refresh
- ✅ Profile listing (`/v2/profiles`)
- ✅ Manager account listing (`/managerAccounts`)
- ✅ Connection verification

### Planned for Future Releases

- ⏳ Campaign management
- ⏳ Ad group operations
- ⏳ Keyword and targeting management
- ⏳ Reporting and analytics
- ⏳ Budget and bid management

## Architecture

### Protocol-Based Design

All major components are protocol-based for maximum testability:

- `AmazonAdvertisingClientProtocol` - Main client interface
- `TokenStorageProtocol` - Storage abstraction
- `OAuthHTMLProvider` - HTML customization

### Models

- `AmazonRegion` - API regions (NA, EU, FE)
- `AmazonProfile` - Advertising profile
- `AmazonManagerAccount` - Manager account (Merch By Amazon)
- `AmazonTokenResponse` - OAuth token response
- `AmazonAdvertisingError` - Error types

## Testing

The package includes comprehensive tests with mock implementations:

```swift
import Testing
@testable import AmazonAdvertisingAPI

@Test func testTokenStorage() async throws {
    let storage = InMemoryTokenStorage()
    try await storage.save("token", for: "key", region: .northAmerica)
    let retrieved = try await storage.retrieve(for: "key", region: .northAmerica)
    #expect(retrieved == "token")
}
```

Run tests:

```bash
swift test
```

## Getting Amazon API Credentials

1. Register for Amazon Advertising API access at [advertising.amazon.com](https://advertising.amazon.com)
2. Complete the API onboarding process
3. Create an API application to get your client ID and secret
4. Add `http://localhost:8765/callback` as an allowed redirect URI

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## Author

Cedric Ziel ([@cedricziel](https://github.com/cedricziel))

## Acknowledgments

- Inspired by the needs of [PodDreamer](https://github.com/cedricziel/PodDreamer)
- Built with modern Swift concurrency patterns
- Follows Apple platform best practices
