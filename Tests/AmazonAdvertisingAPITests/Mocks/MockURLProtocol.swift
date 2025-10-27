//
//  MockURLProtocol.swift
//  AmazonAdvertisingAPITests
//
//  Mock URL Protocol for intercepting and mocking HTTP requests
//

import Foundation

/// Mock URL protocol for testing HTTP requests without network calls
class MockURLProtocol: URLProtocol {

    // MARK: - Response Configuration

    struct MockResponse {
        let data: Data?
        let response: HTTPURLResponse?
        let error: Error?

        static func success(data: Data, statusCode: Int = 200, headers: [String: String]? = nil) -> MockResponse {
            let response = HTTPURLResponse(
                url: URL(string: "https://advertising-api.amazon.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: headers
            )
            return MockResponse(data: data, response: response, error: nil)
        }

        static func failure(error: Error) -> MockResponse {
            return MockResponse(data: nil, response: nil, error: error)
        }

        static func httpError(statusCode: Int, data: Data? = nil) -> MockResponse {
            let response = HTTPURLResponse(
                url: URL(string: "https://advertising-api.amazon.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            return MockResponse(data: data, response: response, error: nil)
        }
    }

    // MARK: - Static Configuration

    static var mockResponses: [URL: MockResponse] = [:]
    static var requestHandler: ((URLRequest) -> MockResponse)?
    static var capturedRequests: [URLRequest] = []

    // MARK: - URLProtocol Override

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept all requests in tests
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Capture the request
        Self.capturedRequests.append(request)

        // Get mock response
        let mockResponse: MockResponse
        if let handler = Self.requestHandler {
            mockResponse = handler(request)
        } else if let url = request.url, let response = Self.mockResponses[url] {
            mockResponse = response
        } else {
            // Default 404 response
            mockResponse = .httpError(statusCode: 404)
        }

        // Send response
        if let error = mockResponse.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let response = mockResponse.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = mockResponse.data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        // No-op
    }

    // MARK: - Test Helpers

    /// Reset all mock state
    static func reset() {
        mockResponses.removeAll()
        requestHandler = nil
        capturedRequests.removeAll()
    }

    /// Configure response for specific URL
    static func setResponse(for url: URL, response: MockResponse) {
        mockResponses[url] = response
    }

    /// Configure dynamic request handler
    static func setRequestHandler(_ handler: @escaping (URLRequest) -> MockResponse) {
        requestHandler = handler
    }

    /// Get last captured request
    static func lastRequest() -> URLRequest? {
        return capturedRequests.last
    }

    /// Get all captured requests
    static func allRequests() -> [URLRequest] {
        return capturedRequests
    }

    /// Find requests matching predicate
    static func requests(matching predicate: (URLRequest) -> Bool) -> [URLRequest] {
        return capturedRequests.filter(predicate)
    }
}

// MARK: - Mock Response Builder Helpers

extension MockURLProtocol.MockResponse {
    /// Create successful JSON response
    static func json<T: Encodable>(_ value: T, statusCode: Int = 200) -> MockURLProtocol.MockResponse {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(value)
        return .success(data: data, statusCode: statusCode, headers: ["Content-Type": "application/json"])
    }

    /// Create 401 Unauthorized response
    static func unauthorized() -> MockURLProtocol.MockResponse {
        return .httpError(statusCode: 401)
    }

    /// Create 403 Forbidden response
    static func forbidden() -> MockURLProtocol.MockResponse {
        return .httpError(statusCode: 403)
    }

    /// Create 404 Not Found response
    static func notFound() -> MockURLProtocol.MockResponse {
        return .httpError(statusCode: 404)
    }

    /// Create 429 Rate Limited response
    static func rateLimited() -> MockURLProtocol.MockResponse {
        return .httpError(statusCode: 429)
    }

    /// Create 500 Internal Server Error response
    static func serverError() -> MockURLProtocol.MockResponse {
        return .httpError(statusCode: 500)
    }
}

// MARK: - URLSession Extension for Testing

extension URLSession {
    /// Create test URL session with mock protocol
    static func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
