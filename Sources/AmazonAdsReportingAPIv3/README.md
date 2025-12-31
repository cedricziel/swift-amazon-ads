# AmazonAdsReportingAPIv3

Generated Swift client for Amazon Advertising Reporting API v3 (Async Reports).

## Overview

This target provides access to the Amazon Advertising Reporting API v3, which allows you to:

- Create asynchronous report requests for advertising data
- Poll report status until completion
- Download generated report files (gzip-compressed JSON)

The async reporting API is designed for large data exports and supports various report types including campaigns, ad groups, keywords, targeting, and more.

## Generation

This client is auto-generated from the OpenAPI specification. To regenerate:

```bash
make generate-reporting
```

## API Endpoints

- `POST /reporting/reports` - Create a new report request
- `GET /reporting/reports/{reportId}` - Get report status and download URL

## Report Workflow

1. **Create Report**: POST a report configuration specifying date range, metrics, and dimensions
2. **Poll Status**: GET the report by ID until `status` is `COMPLETED` or `FAILED`
3. **Download**: Use the `url` field to download the gzip-compressed JSON report

## Report Status Values

- `PENDING` - Report is created and awaiting processing
- `PROCESSING` - Report is being generated
- `COMPLETED` - Report is ready; check the `url` field for download
- `FAILED` - Report generation failed; check `failureReason` for details

## Regional Endpoints

The API supports three regional endpoints:

- **North America**: `https://advertising-api.amazon.com`
- **Europe**: `https://advertising-api-eu.amazon.com`
- **Far East**: `https://advertising-api-fe.amazon.com`

## Usage

```swift
import AmazonAdsReportingAPIv3
import AmazonAdsCore

// Create authenticated transport
let transport = AuthenticatedTransport(
    tokenProvider: { try await getAccessToken() },
    clientId: "your-client-id"
)

// Create client
let client = Client(
    serverURL: try Servers.Server1.url(),
    transport: transport
)

// Create a report request
let response = try await client.createAsyncReport(
    headers: .init(
        Amazon_hyphen_Advertising_hyphen_API_hyphen_ClientId: clientId,
        Amazon_hyphen_Advertising_hyphen_API_hyphen_Scope: profileId
    ),
    body: .json(.init(
        startDate: "2025-01-01",
        endDate: "2025-01-31",
        configuration: .init(
            adProduct: .SPONSORED_PRODUCTS,
            reportTypeId: "spCampaigns",
            columns: ["campaignName", "impressions", "clicks", "cost"],
            timeUnit: .DAILY
        )
    ))
)

// Poll for completion
let report = try await client.getAsyncReport(
    path: .init(reportId: reportId),
    headers: .init(Amazon_hyphen_Advertising_hyphen_API_hyphen_ClientId: clientId)
)
```

## Supported Report Types

Common report type IDs include:

- `spCampaigns` - Sponsored Products campaigns
- `spTargeting` - Sponsored Products targeting
- `spSearchTerm` - Sponsored Products search terms
- `spAdvertisedProduct` - Sponsored Products advertised products
- `sbCampaigns` - Sponsored Brands campaigns
- `sdCampaigns` - Sponsored Display campaigns

See the Amazon Advertising API documentation for the full list of available report types and metrics.
