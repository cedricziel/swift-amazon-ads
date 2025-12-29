//
//  OAuthHTMLProvider.swift
//  AmazonAdsCore
//
//  Protocol for providing custom HTML pages for OAuth callback
//

import Foundation

/// Protocol for providing HTML content for OAuth callback pages
public protocol OAuthHTMLProvider: Sendable {
    /// HTML page shown when OAuth authorization succeeds
    func successHTML() -> String

    /// HTML page shown when OAuth authorization fails
    /// - Parameter message: The error message to display
    func errorHTML(message: String) -> String
}
