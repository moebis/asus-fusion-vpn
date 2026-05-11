import Foundation
import Testing
@testable import ASUSFusionVPN

@Test func surfsharkSelectedEndpointUsesFriendlyFallbackRegionName() {
    let settings = AppSettings(
        routerHost: "192.168.1.1",
        sshPort: 22,
        username: "admin",
        password: "test",
        profileName: "Surfshark",
        vpnUnit: 5,
        selectedRegionEndpoint: "us-atl.prod.surfshark.com",
        selectedRegionPublicKey: "saved-public-key",
        favoriteRegionEndpoints: []
    )

    let region = settings.selectedRegion

    #expect(region?.displayName == "United States / Atlanta")
    #expect(region?.endpointHost == "us-atl.prod.surfshark.com")
}

@Test func passwordPersistsInAppPreferences() throws {
    let previousPassword = UserDefaults.standard.string(forKey: AppSettings.Keys.password)
    defer {
        if let previousPassword {
            UserDefaults.standard.set(previousPassword, forKey: AppSettings.Keys.password)
        } else {
            UserDefaults.standard.removeObject(forKey: AppSettings.Keys.password)
        }
    }

    let settings = AppSettings(
        routerHost: "192.168.1.1",
        sshPort: 22,
        username: "admin",
        password: "saved-router-password",
        profileName: "Surfshark",
        vpnUnit: 5,
        selectedRegionEndpoint: "us-nyc.prod.surfshark.com",
        selectedRegionPublicKey: "public-key",
        favoriteRegionEndpoints: []
    )

    try settings.save()
    let loadedSettings = AppSettings.load()

    #expect(UserDefaults.standard.string(forKey: AppSettings.Keys.password) == "saved-router-password")
    #expect(loadedSettings.password == "saved-router-password")
}
