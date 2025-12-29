// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AmazonAds",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        // Core shared functionality (auth, transport, types)
        .library(
            name: "AmazonAdsCore",
            targets: ["AmazonAdsCore"]),

        // Generated: New unified API v1
        .library(
            name: "AmazonAdsAPIv1",
            targets: ["AmazonAdsAPIv1"]),

        // Generated: Sponsored Products v3 from OpenAPI spec
        .library(
            name: "AmazonAdsSponsoredProductsAPIv3",
            targets: ["AmazonAdsSponsoredProductsAPIv3"]),

        // Legacy: Existing handwritten Sponsored Products v3 code
        .library(
            name: "LegacyAmazonAdsSponsoredProductsAPIv3",
            targets: ["LegacyAmazonAdsSponsoredProductsAPIv3"]),

        // Generated: Accounts API
        .library(
            name: "AmazonAdsAccounts",
            targets: ["AmazonAdsAccounts"]),

        // Generated: Profiles API v2
        .library(
            name: "AmazonAdsProfilesAPIv2",
            targets: ["AmazonAdsProfilesAPIv2"]),

        // Deprecated: Original library name for backwards compatibility during migration
        .library(
            name: "AmazonAdvertisingAPI",
            targets: ["LegacyAmazonAdsSponsoredProductsAPIv3"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
        // Required for Xcode 16 explicit module builds - transitive deps from swift-openapi-runtime
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
    ],
    targets: [
        // MARK: - Core (shared auth, transport, types)
        .target(
            name: "AmazonAdsCore",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                // Explicit transitive deps for Xcode 16 module scanning
                .product(name: "DequeModule", package: "swift-collections"),
            ],
            exclude: ["README.md"]
        ),

        // MARK: - Generated: New unified API v1
        // Regenerate with: make generate-api
        .target(
            name: "AmazonAdsAPIv1",
            dependencies: [
                "AmazonAdsCore",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            exclude: ["openapi.json", "openapi-generator-config.yaml", "README.md"]
        ),

        // MARK: - Generated: Sponsored Products v3 from OpenAPI spec
        // Regenerate with: make generate-sp
        .target(
            name: "AmazonAdsSponsoredProductsAPIv3",
            dependencies: [
                "AmazonAdsCore",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            exclude: ["openapi.json", "openapi-generator-config.yaml", "README.md"]
        ),

        // MARK: - Legacy: Existing handwritten Sponsored Products v3 code
        .target(
            name: "LegacyAmazonAdsSponsoredProductsAPIv3",
            dependencies: ["AmazonAdsCore"],
            exclude: ["README.md"]
        ),

        // MARK: - Generated: Accounts API
        // Regenerate with: make generate-accounts
        .target(
            name: "AmazonAdsAccounts",
            dependencies: [
                "AmazonAdsCore",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            exclude: ["openapi.json", "openapi-generator-config.yaml", "README.md"]
        ),

        // MARK: - Generated: Profiles API v2
        // Regenerate with: make generate-profiles
        .target(
            name: "AmazonAdsProfilesAPIv2",
            dependencies: [
                "AmazonAdsCore",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            exclude: ["openapi.yaml", "openapi-generator-config.yaml", "README.md"]
        ),

        // MARK: - Tests
        .testTarget(
            name: "AmazonAdsCoreTests",
            dependencies: ["AmazonAdsCore"]
        ),
        .testTarget(
            name: "AmazonAdsAPIv1Tests",
            dependencies: ["AmazonAdsAPIv1"]
        ),
        .testTarget(
            name: "AmazonAdsSponsoredProductsAPIv3Tests",
            dependencies: ["AmazonAdsSponsoredProductsAPIv3"]
        ),
        .testTarget(
            name: "LegacyAmazonAdsSponsoredProductsAPIv3Tests",
            dependencies: ["LegacyAmazonAdsSponsoredProductsAPIv3"]
        ),
        .testTarget(
            name: "AmazonAdsAccountsTests",
            dependencies: ["AmazonAdsAccounts"]
        ),
        .testTarget(
            name: "AmazonAdsProfilesAPIv2Tests",
            dependencies: ["AmazonAdsProfilesAPIv2"]
        ),
    ]
)
