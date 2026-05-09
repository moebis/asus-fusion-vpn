import Foundation

enum VPNRegionStore {
    private static let cachedRegionsKey = "cachedSurfsharkRegions"

    static func initialRegions(settings: AppSettings) -> [VPNRegion] {
        var regions = cachedRegions()
        if regions.isEmpty {
            regions = [VPNRegionCatalog.fallbackRegion]
        }

        if
            let selectedRegion = settings.selectedRegion,
            VPNRegionCatalog.region(matching: selectedRegion.endpointHost, in: regions) == nil
        {
            regions.append(selectedRegion)
        }

        return regions.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    static func cachedRegions() -> [VPNRegion] {
        guard
            let data = UserDefaults.standard.data(forKey: cachedRegionsKey),
            let regions = try? JSONDecoder().decode([VPNRegion].self, from: data)
        else {
            return []
        }

        return regions
    }

    static func saveCachedRegions(_ regions: [VPNRegion]) {
        guard let data = try? JSONEncoder().encode(regions) else { return }
        UserDefaults.standard.set(data, forKey: cachedRegionsKey)
    }

    static func fetchRegions() async throws -> [VPNRegion] {
        let (data, response) = try await URLSession.shared.data(from: VPNRegionCatalog.sourceURL)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw RegionFetchError(message: "Surfshark region list returned HTTP \(httpResponse.statusCode).")
        }

        return try VPNRegionCatalog.regions(from: data)
    }
}

struct RegionFetchError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
