.PHONY: all build test clean generate generate-sp generate-api generate-accounts generate-profiles lint format

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
generate: generate-sp generate-api generate-accounts generate-profiles
	@echo "✅ All OpenAPI clients regenerated"

# Generate Sponsored Products v3 client
generate-sp:
	@echo "🔄 Generating AmazonAdsSponsoredProductsAPIv3..."
	swift run swift-openapi-generator generate \
		Sources/AmazonAdsSponsoredProductsAPIv3/openapi.json \
		--config Sources/AmazonAdsSponsoredProductsAPIv3/openapi-generator-config.yaml \
		--output-directory Sources/AmazonAdsSponsoredProductsAPIv3/GeneratedSources

# Generate unified API v1 client
generate-api:
	@echo "🔄 Generating AmazonAdsAPIv1..."
	swift run swift-openapi-generator generate \
		Sources/AmazonAdsAPIv1/openapi.json \
		--config Sources/AmazonAdsAPIv1/openapi-generator-config.yaml \
		--output-directory Sources/AmazonAdsAPIv1/GeneratedSources

# Generate Accounts API client
generate-accounts:
	@echo "🔄 Generating AmazonAdsAccounts..."
	swift run swift-openapi-generator generate \
		Sources/AmazonAdsAccounts/openapi.json \
		--config Sources/AmazonAdsAccounts/openapi-generator-config.yaml \
		--output-directory Sources/AmazonAdsAccounts/GeneratedSources

# Generate Profiles API v2 client
generate-profiles:
	@echo "🔄 Generating AmazonAdsProfilesAPIv2..."
	swift run swift-openapi-generator generate \
		Sources/AmazonAdsProfilesAPIv2/openapi.yaml \
		--config Sources/AmazonAdsProfilesAPIv2/openapi-generator-config.yaml \
		--output-directory Sources/AmazonAdsProfilesAPIv2/GeneratedSources

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
	cp specs/Profiles_prod_3p.yaml Sources/AmazonAdsProfilesAPIv2/openapi.yaml
	@echo "✅ Specs updated. Run 'make generate' to regenerate clients."

# Full regeneration: update specs and generate
regenerate: update-specs generate
	@echo "✅ Full regeneration complete"
