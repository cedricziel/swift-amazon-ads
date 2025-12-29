import Testing
@testable import AmazonAdsProfilesAPIv2

@Suite("AmazonAdsProfilesAPIv2 Tests")
struct AmazonAdsProfilesAPIv2Tests {
    @Test("Module info is available")
    func moduleInfoAvailable() async throws {
        // Verify that the module's namespace enum is accessible
        let _ = AmazonAdsProfilesAPIv2.self
    }

    @Test("Profile types are accessible")
    func profileTypesAccessible() async throws {
        // Verify generated profile types compile
        let _ = Components.Schemas.Profile.self
        let _ = Components.Schemas.AccountInfo.self
        let _ = Components.Schemas.AccountType.self
        let _ = Components.Schemas.countryCode.self
    }

    @Test("Server URLs are defined")
    func serverUrlsDefined() async throws {
        // Verify all three regional servers are accessible
        let naURL = try Servers.Server1.url()
        #expect(naURL.absoluteString == "https://advertising-api.amazon.com")

        let euURL = try Servers.Server2.url()
        #expect(euURL.absoluteString == "https://advertising-api-eu.amazon.com")

        let feURL = try Servers.Server3.url()
        #expect(feURL.absoluteString == "https://advertising-api-fe.amazon.com")
    }
}
