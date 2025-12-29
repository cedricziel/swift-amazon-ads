.PHONY: all build test clean generate generate-sp generate-api generate-accounts lint format

# Default target
all: build

# Build the package
build:
	swift build

# Run tests
test:
	swift test

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Generate all OpenAPI clients
generate: generate-sp generate-api generate-accounts
	@echo "✅ All OpenAPI clients regenerated"

# Generate Sponsored Products v3 client
generate-sp:
	@echo "🔄 Generating AmazonAdsSponsoredProductsAPIv3..."
	swift package --allow-writing-to-package-directory generate-code-from-openapi --target AmazonAdsSponsoredProductsAPIv3

# Generate unified API v1 client
generate-api:
	@echo "🔄 Generating AmazonAdsAPIv1..."
	swift package --allow-writing-to-package-directory generate-code-from-openapi --target AmazonAdsAPIv1

# Generate Accounts API client
generate-accounts:
	@echo "🔄 Generating AmazonAdsAccounts..."
	swift package --allow-writing-to-package-directory generate-code-from-openapi --target AmazonAdsAccounts

# Lint with SwiftLint (if available)
lint:
	@which swiftlint > /dev/null && swiftlint lint --strict || echo "SwiftLint not installed"

# Format with SwiftFormat (if available)
format:
	@which swiftformat > /dev/null && swiftformat Sources Tests || echo "SwiftFormat not installed"

# Update OpenAPI specs from specs/ directory
update-specs:
	@echo "📋 Copying specs..."
	cp specs/SponsoredProducts_prod_3p.json Sources/AmazonAdsSponsoredProductsAPIv3/openapi.json
	cp specs/AmazonAdsAPIALLMerged_prod_3p.json Sources/AmazonAdsAPIv1/openapi.json
	cp specs/AdvertisingAccounts_prod_3p.json Sources/AmazonAdsAccounts/openapi.json
	@echo "✅ Specs updated. Run 'make generate' to regenerate clients."

# Full regeneration: update specs and generate
regenerate: update-specs generate
	@echo "✅ Full regeneration complete"
