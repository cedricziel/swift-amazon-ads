//
//  AmazonAdvertisingClientProtocol.swift
//  LegacyAmazonAdsSponsoredProductsAPIv3
//
//  Protocol for Amazon Advertising API client
//

import Foundation
import AmazonAdsCore

/// Protocol defining Amazon Advertising API operations
public protocol AmazonAdvertisingClientProtocol: Sendable {
    /// Initiate OAuth authorization flow for a specific region
    /// This method starts a local OAuth server, generates the authorization URL, and waits for the callback
    /// Note: The caller is responsible for opening the returned URL in a browser
    /// - Parameter region: The Amazon region to authorize
    /// - Returns: The authorization URL that should be opened in a browser
    func initiateAuthorization(for region: AmazonRegion) async throws -> URL

    /// Cancel ongoing authorization for a region
    /// - Parameter region: The Amazon region
    func cancelAuthorization(for region: AmazonRegion) async

    /// Refresh access token using refresh token
    /// - Parameter region: The Amazon region
    func refreshToken(for region: AmazonRegion) async throws

    /// Get valid access token for a region, refreshing if necessary
    /// - Parameter region: The Amazon region
    /// - Returns: Valid access token
    func getAccessToken(for region: AmazonRegion) async throws -> String

    /// Fetch advertising profiles for a region (regular Sponsored Products accounts)
    /// - Parameter region: The Amazon region
    /// - Returns: Array of advertising profiles
    func fetchProfiles(for region: AmazonRegion) async throws -> [AmazonProfile]

    /// Fetch manager accounts for a region (Merch By Amazon accounts)
    /// - Parameter region: The Amazon region
    /// - Returns: Manager accounts response
    func fetchManagerAccounts(for region: AmazonRegion) async throws -> AmazonManagerAccountsResponse

    /// Verify connection by making a test API call
    /// Returns true if connection is valid, false otherwise
    /// - Parameter region: The Amazon region to verify
    /// - Returns: True if connection is valid
    func verifyConnection(for region: AmazonRegion) async throws -> Bool

    /// Check if authenticated for a specific region
    /// - Parameter region: The Amazon region to check
    /// - Returns: True if valid tokens exist
    func isAuthenticated(for region: AmazonRegion) async -> Bool

    /// Logout and clear stored tokens for a region
    /// - Parameter region: The Amazon region to logout from
    func logout(for region: AmazonRegion) async throws

    // MARK: - Campaign Management

    /// List Sponsored Products campaigns for a profile
    /// - Parameters:
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    ///   - stateFilter: Optional state filter (enabled, paused, archived)
    /// - Returns: Array of campaigns
    func listCampaigns(
        profileId: String,
        region: AmazonRegion,
        stateFilter: [CampaignState]?
    ) async throws -> [SponsoredProductsCampaign]

    /// Get a specific campaign by ID
    /// - Parameters:
    ///   - campaignId: Campaign identifier
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Campaign details
    func getCampaign(
        campaignId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsCampaign

    /// Create a new Sponsored Products campaign
    /// - Parameters:
    ///   - campaign: Campaign to create
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Created campaign with Amazon-assigned ID
    func createCampaign(
        campaign: SponsoredProductsCampaign,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsCampaign

    /// Update an existing campaign
    /// - Parameters:
    ///   - campaign: Campaign with updated fields
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Updated campaign
    func updateCampaign(
        campaign: SponsoredProductsCampaign,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsCampaign

    /// Archive a campaign
    /// - Parameters:
    ///   - campaignId: Campaign identifier
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    func archiveCampaign(
        campaignId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws

    // MARK: - Ad Group Management

    /// List ad groups for a campaign
    /// - Parameters:
    ///   - campaignId: Optional campaign ID to filter by
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    ///   - stateFilter: Optional state filter
    /// - Returns: Array of ad groups
    func listAdGroups(
        campaignId: String?,
        profileId: String,
        region: AmazonRegion,
        stateFilter: [AdGroupState]?
    ) async throws -> [SponsoredProductsAdGroup]

    /// Get a specific ad group by ID
    /// - Parameters:
    ///   - adGroupId: Ad group identifier
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Ad group details
    func getAdGroup(
        adGroupId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsAdGroup

    /// Create a new ad group
    /// - Parameters:
    ///   - adGroup: Ad group to create
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Created ad group with Amazon-assigned ID
    func createAdGroup(
        adGroup: SponsoredProductsAdGroup,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsAdGroup

    /// Update an existing ad group
    /// - Parameters:
    ///   - adGroup: Ad group with updated fields
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Updated ad group
    func updateAdGroup(
        adGroup: SponsoredProductsAdGroup,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsAdGroup

    /// Archive an ad group
    /// - Parameters:
    ///   - adGroupId: Ad group identifier
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    func archiveAdGroup(
        adGroupId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws

    // MARK: - Product Ad Management

    /// List product ads for an ad group
    /// - Parameters:
    ///   - adGroupId: Optional ad group ID to filter by
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    ///   - stateFilter: Optional state filter
    /// - Returns: Array of product ads
    func listProductAds(
        adGroupId: String?,
        profileId: String,
        region: AmazonRegion,
        stateFilter: [ProductAdState]?
    ) async throws -> [SponsoredProductsProductAd]

    /// Create a new product ad
    /// - Parameters:
    ///   - productAd: Product ad to create
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Created product ad with Amazon-assigned ID
    func createProductAd(
        productAd: SponsoredProductsProductAd,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsProductAd

    /// Update an existing product ad
    /// - Parameters:
    ///   - productAd: Product ad with updated fields
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Updated product ad
    func updateProductAd(
        productAd: SponsoredProductsProductAd,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsProductAd

    /// Archive a product ad
    /// - Parameters:
    ///   - adId: Product ad identifier
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    func archiveProductAd(
        adId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws

    // MARK: - Keyword Management

    /// List keywords for an ad group
    /// - Parameters:
    ///   - adGroupId: Optional ad group ID to filter by
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    ///   - stateFilter: Optional state filter
    /// - Returns: Array of keywords
    func listKeywords(
        adGroupId: String?,
        profileId: String,
        region: AmazonRegion,
        stateFilter: [KeywordState]?
    ) async throws -> [SponsoredProductsKeyword]

    /// Create a new keyword
    /// - Parameters:
    ///   - keyword: Keyword to create
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Created keyword with Amazon-assigned ID
    func createKeyword(
        keyword: SponsoredProductsKeyword,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsKeyword

    /// Update an existing keyword
    /// - Parameters:
    ///   - keyword: Keyword with updated fields
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Updated keyword
    func updateKeyword(
        keyword: SponsoredProductsKeyword,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsKeyword

    /// Archive a keyword
    /// - Parameters:
    ///   - keywordId: Keyword identifier
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    func archiveKeyword(
        keywordId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws

    // MARK: - Product Target Management

    /// List product targets for an ad group
    /// - Parameters:
    ///   - adGroupId: Optional ad group ID to filter by
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    ///   - stateFilter: Optional state filter
    /// - Returns: Array of targets
    func listTargets(
        adGroupId: String?,
        profileId: String,
        region: AmazonRegion,
        stateFilter: [TargetState]?
    ) async throws -> [SponsoredProductsTarget]

    /// Create a new product target
    /// - Parameters:
    ///   - target: Target to create
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Created target with Amazon-assigned ID
    func createTarget(
        target: SponsoredProductsTarget,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsTarget

    /// Update an existing target
    /// - Parameters:
    ///   - target: Target with updated fields
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    /// - Returns: Updated target
    func updateTarget(
        target: SponsoredProductsTarget,
        profileId: String,
        region: AmazonRegion
    ) async throws -> SponsoredProductsTarget

    /// Archive a target
    /// - Parameters:
    ///   - targetId: Target identifier
    ///   - profileId: Profile identifier to scope the request
    ///   - region: Amazon region
    func archiveTarget(
        targetId: String,
        profileId: String,
        region: AmazonRegion
    ) async throws
}
