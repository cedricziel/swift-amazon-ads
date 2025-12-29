//
//  AmazonProfile.swift
//  AmazonAdsCore
//
//  Amazon Advertising API profile models
//

import Foundation

/// Amazon Advertising API profile
public struct AmazonProfile: Codable, Sendable {
    public let profileId: String
    public let countryCode: String
    public let currencyCode: String
    public let timezone: String
    public let accountInfo: AmazonAccountInfo

    enum CodingKeys: String, CodingKey {
        case profileId
        case countryCode
        case currencyCode
        case timezone
        case accountInfo
    }

    public init(
        profileId: String,
        countryCode: String,
        currencyCode: String,
        timezone: String,
        accountInfo: AmazonAccountInfo
    ) {
        self.profileId = profileId
        self.countryCode = countryCode
        self.currencyCode = currencyCode
        self.timezone = timezone
        self.accountInfo = accountInfo
    }
}

/// Amazon Advertising account information
public struct AmazonAccountInfo: Codable, Sendable {
    public let id: String
    public let type: String
    public let name: String
    public let validPaymentMethod: Bool?

    public init(
        id: String,
        type: String,
        name: String,
        validPaymentMethod: Bool? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.validPaymentMethod = validPaymentMethod
    }
}

/// Amazon Manager Accounts Response (wrapper for /managerAccounts endpoint)
public struct AmazonManagerAccountsResponse: Codable, Sendable {
    public let managerAccounts: [AmazonManagerAccount]

    public init(managerAccounts: [AmazonManagerAccount]) {
        self.managerAccounts = managerAccounts
    }
}

/// Amazon Manager Account (for Merch By Amazon)
public struct AmazonManagerAccount: Codable, Sendable {
    public let managerAccountId: String
    public let managerAccountName: String
    public let linkedAccounts: [AmazonLinkedAccount]

    enum CodingKeys: String, CodingKey {
        case managerAccountId
        case managerAccountName
        case linkedAccounts
    }

    public init(
        managerAccountId: String,
        managerAccountName: String,
        linkedAccounts: [AmazonLinkedAccount]
    ) {
        self.managerAccountId = managerAccountId
        self.managerAccountName = managerAccountName
        self.linkedAccounts = linkedAccounts
    }
}

/// Amazon Linked Account (profiles within a manager account)
public struct AmazonLinkedAccount: Codable, Sendable {
    public let profileId: String
    public let accountId: String
    public let accountName: String
    public let marketplaceId: String

    enum CodingKeys: String, CodingKey {
        case profileId
        case accountId
        case accountName
        case marketplaceId
    }

    public init(
        profileId: String,
        accountId: String,
        accountName: String,
        marketplaceId: String
    ) {
        self.profileId = profileId
        self.accountId = accountId
        self.accountName = accountName
        self.marketplaceId = marketplaceId
    }
}
