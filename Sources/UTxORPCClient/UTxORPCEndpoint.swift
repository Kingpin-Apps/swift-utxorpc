import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

/// Where a UTxO RPC server listens and how to reach it.
///
/// - A hosted or self-run server (Dolos, Demeter) listens on TCP, usually with TLS.
///   Hosted providers often want an API key header, for example Demeter's
///   `dmtr-api-key`.
/// - cardano-node 11.1.x serves UTxO RPC only on a Unix socket (`rpc.sock`, next to
///   `node.socket`), always in plaintext.
/// - cardano-node-api speaks only the older v1alpha API; set ``apiVersion`` to
///   `.v1alpha` for it.
public struct UTxORPCEndpoint: Sendable, Hashable {
    /// The address the server listens on.
    public enum Target: Sendable, Hashable {
        /// A host name or IP address and a TCP port.
        case host(String, port: Int)
        /// A Unix domain socket, such as a node's `rpc.sock`.
        case unixSocket(path: String)
    }

    /// The address the server listens on.
    public var target: Target
    /// Whether to connect over TLS. Unix sockets are always plaintext.
    public var useTLS: Bool
    /// Sent as gRPC metadata on every call. Keys must be lowercase.
    public var headers: [String: String]
    /// The API version the server speaks.
    public var apiVersion: UTxORPCAPIVersion

    /// An endpoint from its parts.
    public init(
        target: Target,
        useTLS: Bool,
        headers: [String: String] = [:],
        apiVersion: UTxORPCAPIVersion = .v1beta
    ) {
        self.target = target
        self.useTLS = useTLS
        self.headers = headers
        self.apiVersion = apiVersion
    }

    /// A node's local `rpc.sock`.
    public static func unixSocket(_ path: String) -> Self {
        Self(target: .unixSocket(path: path), useTLS: false)
    }

    /// Parses `https://host[:port]` (TLS, default port 443), `http://host[:port]`
    /// (plaintext, default port 80) or `unix:///path/to/rpc.sock`.
    public init(url: URL, headers: [String: String] = [:], apiVersion: UTxORPCAPIVersion = .v1beta) throws {
        switch url.scheme?.lowercased() {
        case "unix":
            guard !url.path.isEmpty else { throw UTxORPCClientError.invalidURL(url) }
            self.init(target: .unixSocket(path: url.path), useTLS: false, headers: headers, apiVersion: apiVersion)
        case "https":
            guard let host = url.host, !host.isEmpty else { throw UTxORPCClientError.invalidURL(url) }
            self.init(target: .host(host, port: url.port ?? 443), useTLS: true, headers: headers, apiVersion: apiVersion)
        case "http":
            guard let host = url.host, !host.isEmpty else { throw UTxORPCClientError.invalidURL(url) }
            self.init(target: .host(host, port: url.port ?? 80), useTLS: false, headers: headers, apiVersion: apiVersion)
        default:
            throw UTxORPCClientError.invalidURL(url)
        }
    }

    func makeTransport() throws -> UTxORPCTransport<HTTP2ClientTransport.Posix> {
        let resolvable: any ResolvableTarget
        switch target {
        case .host(let host, let port):
            resolvable = .dns(host: host, port: port)
        case .unixSocket(let path):
            resolvable = .unixDomainSocket(path: path)
        }
        let transport = try HTTP2ClientTransport.Posix(
            target: resolvable,
            transportSecurity: useTLS ? .tls : .plaintext
        )
        return UTxORPCTransport(wrapping: transport, apiVersion: apiVersion)
    }

    var interceptors: [any ClientInterceptor] {
        headers.isEmpty ? [] : [HeaderInterceptor(headers: headers)]
    }
}

/// Errors from setting up a UTxO RPC connection.
public enum UTxORPCClientError: Error, Sendable, Equatable {
    /// The URL has no host, or a scheme other than `https`, `http` or `unix`.
    case invalidURL(URL)
}

/// Adds fixed metadata (API keys) to every request.
struct HeaderInterceptor: ClientInterceptor {
    let headers: [String: String]

    func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingClientRequest<Input>,
        context: ClientContext,
        next: (StreamingClientRequest<Input>, ClientContext) async throws -> StreamingClientResponse<Output>
    ) async throws -> StreamingClientResponse<Output> {
        var request = request
        for (key, value) in headers {
            request.metadata.addString(value, forKey: key.lowercased())
        }
        return try await next(request, context)
    }
}
