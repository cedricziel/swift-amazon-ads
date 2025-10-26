//
//  DefaultOAuthHTMLProvider.swift
//  AmazonAdvertisingAPI
//
//  Default HTML pages for OAuth callback
//

import Foundation

/// Default implementation of OAuthHTMLProvider with styled success and error pages
public struct DefaultOAuthHTMLProvider: OAuthHTMLProvider {
    public init() {}

    public func successHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Authentication Successful</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                }
                .container {
                    background: white;
                    padding: 40px;
                    border-radius: 10px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.2);
                    text-align: center;
                    max-width: 400px;
                }
                .checkmark {
                    font-size: 64px;
                    color: #4CAF50;
                    margin-bottom: 20px;
                }
                h1 {
                    color: #333;
                    margin: 0 0 10px 0;
                    font-size: 24px;
                }
                p {
                    color: #666;
                    margin: 0;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="checkmark">✓</div>
                <h1>Authentication Successful!</h1>
                <p>You can now close this window and return to your app.</p>
            </div>
        </body>
        </html>
        """
    }

    public func errorHTML(message: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Authentication Error</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
                }
                .container {
                    background: white;
                    padding: 40px;
                    border-radius: 10px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.2);
                    text-align: center;
                    max-width: 400px;
                }
                .error-icon {
                    font-size: 64px;
                    color: #f44336;
                    margin-bottom: 20px;
                }
                h1 {
                    color: #333;
                    margin: 0 0 10px 0;
                    font-size: 24px;
                }
                p {
                    color: #666;
                    margin: 0;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="error-icon">✗</div>
                <h1>Authentication Error</h1>
                <p>\(message)</p>
            </div>
        </body>
        </html>
        """
    }
}
