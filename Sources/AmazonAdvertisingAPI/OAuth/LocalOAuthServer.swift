//
//  LocalOAuthServer.swift
//  AmazonAdvertisingAPI
//
//  Local HTTP server for OAuth callback handling
//

import Foundation
import Network

/// Local HTTP server for capturing OAuth callbacks on localhost
public actor LocalOAuthServer {
    private var listener: NWListener?
    private var connection: NWConnection?
    private var continuation: CheckedContinuation<String, Error>?

    private let port: UInt16
    private var isRunning = false
    private let htmlProvider: OAuthHTMLProvider

    /// Initialize with specific port and HTML provider
    /// - Parameters:
    ///   - port: Port number (0 for random available port)
    ///   - htmlProvider: Provider for success/error HTML pages
    public init(port: UInt16 = 0, htmlProvider: OAuthHTMLProvider = DefaultOAuthHTMLProvider()) {
        self.port = port
        self.htmlProvider = htmlProvider
    }

    // MARK: - Server Lifecycle

    /// Start the HTTP server and return the actual port being used
    public func start() async throws -> UInt16 {
        guard !isRunning else {
            throw LocalOAuthServerError.alreadyRunning
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        // Create listener
        let port = NWEndpoint.Port(integerLiteral: self.port)
        guard let listener = try? NWListener(using: parameters, on: port) else {
            throw LocalOAuthServerError.failedToStart
        }

        self.listener = listener

        // Set up new connection handler
        listener.newConnectionHandler = { connection in
            Task {
                await self.handleConnection(connection)
            }
        }

        // Wait for listener to be ready
        return try await withCheckedThrowingContinuation { continuation in
            // Set up state update handler
            listener.stateUpdateHandler = { state in
                Task {
                    await self.handleStateUpdate(state, continuation: continuation)
                }
            }

            // Start listening
            listener.start(queue: .main)
        }
    }

    /// Wait for OAuth callback and return the authorization code
    public func waitForCallback() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    /// Stop the server
    public func stop() {
        guard isRunning else { return }

        connection?.cancel()
        connection = nil

        listener?.cancel()
        listener = nil

        isRunning = false
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        self.connection = connection

        connection.stateUpdateHandler = { state in
            Task {
                await self.handleConnectionState(state)
            }
        }

        connection.start(queue: .main)

        // Receive HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            Task {
                await self.handleReceivedData(data: data, isComplete: isComplete, error: error)
            }
        }
    }

    private func handleReceivedData(data: Data?, isComplete: Bool, error: Error?) {
        if let error = error {
            continuation?.resume(throwing: LocalOAuthServerError.connectionError(error))
            continuation = nil
            stop()
            return
        }

        guard let data = data, let request = String(data: data, encoding: .utf8) else {
            return
        }

        // Parse HTTP request
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first,
              requestLine.hasPrefix("GET ") else {
            sendResponse(html: htmlProvider.errorHTML(message: "Invalid request"), statusCode: 400)
            return
        }

        // Extract path and query
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            sendResponse(html: htmlProvider.errorHTML(message: "Invalid request format"), statusCode: 400)
            return
        }

        let urlPath = components[1]

        // Check if it's the callback path
        guard urlPath.hasPrefix("/callback") else {
            sendResponse(html: htmlProvider.errorHTML(message: "Invalid callback path"), statusCode: 404)
            return
        }

        // Parse query parameters
        guard let urlComponents = URLComponents(string: "http://localhost\(urlPath)"),
              let queryItems = urlComponents.queryItems else {
            sendResponse(html: htmlProvider.errorHTML(message: "Missing query parameters"), statusCode: 400)
            return
        }

        // Extract authorization code
        if let code = queryItems.first(where: { $0.name == "code" })?.value {
            sendResponse(html: htmlProvider.successHTML(), statusCode: 200)

            // Resume the continuation with the authorization code
            continuation?.resume(returning: code)
            continuation = nil

            // Give the response time to be sent before stopping
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                stop()
            }
        } else if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value ?? error
            sendResponse(html: htmlProvider.errorHTML(message: errorDescription), statusCode: 400)
            continuation?.resume(throwing: LocalOAuthServerError.oauthError(error))
            continuation = nil
            stop()
        } else {
            sendResponse(html: htmlProvider.errorHTML(message: "Missing authorization code"), statusCode: 400)
            continuation?.resume(throwing: LocalOAuthServerError.missingCode)
            continuation = nil
            stop()
        }
    }

    private func sendResponse(html: String, statusCode: Int) {
        let response = """
        HTTP/1.1 \(statusCode) \(httpStatusText(statusCode))
        Content-Type: text/html; charset=utf-8
        Content-Length: \(html.utf8.count)
        Connection: close

        \(html)
        """

        guard let data = response.data(using: .utf8) else { return }

        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    // MARK: - State Handlers

    private func handleStateUpdate(_ state: NWListener.State, continuation: CheckedContinuation<UInt16, Error>) {
        switch state {
        case .ready:
            isRunning = true
            if let actualPort = listener?.port?.rawValue {
                continuation.resume(returning: actualPort)
            } else {
                continuation.resume(throwing: LocalOAuthServerError.failedToGetPort)
            }
        case .failed(let error):
            continuation.resume(throwing: LocalOAuthServerError.listenerFailed(error))
        default:
            break
        }
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        // Handle connection state changes if needed
    }

    // MARK: - Helpers

    private func httpStatusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        default: return "Error"
        }
    }
}

// MARK: - Errors

public enum LocalOAuthServerError: LocalizedError {
    case alreadyRunning
    case failedToStart
    case failedToGetPort
    case connectionError(Error)
    case listenerFailed(Error)
    case oauthError(String)
    case missingCode

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Server is already running"
        case .failedToStart:
            return "Failed to start OAuth server"
        case .failedToGetPort:
            return "Failed to get server port"
        case .connectionError(let error):
            return "Connection error: \(error.localizedDescription)"
        case .listenerFailed(let error):
            return "Listener failed: \(error.localizedDescription)"
        case .oauthError(let error):
            return "OAuth error: \(error)"
        case .missingCode:
            return "Authorization code not received"
        }
    }
}
