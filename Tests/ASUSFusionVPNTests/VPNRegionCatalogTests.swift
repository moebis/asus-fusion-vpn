import Foundation
import Testing
@testable import ASUSFusionVPN

@Test func surfsharkClustersParseIntoRegions() throws {
    let data = """
    [
      {
        "country": "United States",
        "countryCode": "US",
        "region": "Americas",
        "location": "New York",
        "connectionName": "us-nyc.prod.surfshark.com",
        "pubKey": "ny-public-key",
        "type": "generic"
      },
      {
        "country": "Germany",
        "countryCode": "DE",
        "region": "Europe",
        "location": "Frankfurt",
        "connectionName": "de-fra.prod.surfshark.com",
        "pubKey": "de-public-key",
        "type": "generic"
      },
      {
        "country": "Broken",
        "location": "Nowhere",
        "connectionName": "",
        "pubKey": "",
        "type": "generic"
      }
    ]
    """.data(using: .utf8)!

    let regions = try VPNRegionCatalog.regions(from: data)

    #expect(regions.count == 2)
    #expect(regions[0].displayName == "Germany / Frankfurt")
    #expect(regions[0].endpointHost == "de-fra.prod.surfshark.com")
    #expect(regions[0].publicKey == "de-public-key")
    #expect(regions[1].displayName == "United States / New York")
}

@Test func favoriteRegionsSortBeforeRegularRegions() throws {
    let regions = [
        VPNRegion(country: "Germany", countryCode: "DE", group: "Europe", location: "Frankfurt", endpointHost: "de-fra.prod.surfshark.com", publicKey: "de-public-key"),
        VPNRegion(country: "United States", countryCode: "US", group: "Americas", location: "New York", endpointHost: "us-nyc.prod.surfshark.com", publicKey: "ny-public-key"),
        VPNRegion(country: "Australia", countryCode: "AU", group: "Asia Pacific", location: "Sydney", endpointHost: "au-syd.prod.surfshark.com", publicKey: "au-public-key")
    ]

    let sorted = VPNRegionCatalog.sortedRegions(
        regions,
        favoriteEndpoints: ["us-nyc.prod.surfshark.com"],
        selectedEndpoint: "de-fra.prod.surfshark.com"
    )

    #expect(sorted.map { $0.endpointHost } == [
        "us-nyc.prod.surfshark.com",
        "de-fra.prod.surfshark.com",
        "au-syd.prod.surfshark.com"
    ])
}
