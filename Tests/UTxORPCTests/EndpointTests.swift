import Foundation
import Testing
@testable import UTxORPCClient

@Suite("Endpoint")
struct EndpointTests {
    @Test func httpsDefaultsToTLSOn443() throws {
        let endpoint = try UTxORPCEndpoint(url: URL(string: "https://preview.utxorpc-v0.demeter.run")!)
        #expect(endpoint.target == .host("preview.utxorpc-v0.demeter.run", port: 443))
        #expect(endpoint.useTLS)
    }

    @Test func httpKeepsExplicitPort() throws {
        let endpoint = try UTxORPCEndpoint(url: URL(string: "http://localhost:50051")!)
        #expect(endpoint.target == .host("localhost", port: 50051))
        #expect(!endpoint.useTLS)
    }

    @Test func unixURLIsASocket() throws {
        let endpoint = try UTxORPCEndpoint(url: URL(string: "unix:///tmp/cardano/rpc.sock")!)
        #expect(endpoint == .unixSocket("/tmp/cardano/rpc.sock"))
    }

    @Test(arguments: ["ftp://host", "https://", "unix://"])
    func rejectsUnusableURLs(_ string: String) throws {
        let url = try #require(URL(string: string))
        #expect(throws: UTxORPCClientError.invalidURL(url)) {
            try UTxORPCEndpoint(url: url)
        }
    }

    @Test func headersBecomeAnInterceptor() {
        #expect(UTxORPCEndpoint.unixSocket("/x").interceptors.isEmpty)
        let keyed = UTxORPCEndpoint(target: .host("h", port: 1), useTLS: true, headers: ["dmtr-api-key": "k"])
        #expect(keyed.interceptors.count == 1)
    }
}
