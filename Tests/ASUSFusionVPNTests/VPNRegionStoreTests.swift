import Testing
@testable import ASUSFusionVPN

@Test func combinedRegionsPreferCatalogNameOverSelectedEndpointFallback() {
    let catalogRegion = VPNRegion(
        country: "United States",
        countryCode: "US",
        group: "Americas",
        location: "Atlanta",
        endpointHost: "us-atl.prod.surfshark.com",
        publicKey: "catalog-public-key"
    )
    let selectedFallback = VPNRegion(
        country: "Selected",
        countryCode: nil,
        group: nil,
        location: "us-atl.prod.surfshark.com",
        endpointHost: "us-atl.prod.surfshark.com",
        publicKey: "saved-public-key"
    )

    let regions = VPNRegionStore.combinedRegions(
        catalogRegions: [catalogRegion],
        selectedRegion: selectedFallback
    )

    let matchedRegion = VPNRegionCatalog.region(
        matching: "us-atl.prod.surfshark.com",
        in: regions
    )
    #expect(matchedRegion?.displayName == "United States / Atlanta")
    #expect(matchedRegion?.publicKey == "catalog-public-key")
}
