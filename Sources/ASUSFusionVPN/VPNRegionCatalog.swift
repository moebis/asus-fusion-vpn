import Foundation

struct VPNRegion: Codable, Equatable, Hashable, Identifiable, Sendable {
    let country: String
    let countryCode: String?
    let group: String?
    let location: String
    let endpointHost: String
    let publicKey: String

    var id: String {
        endpointHost.lowercased()
    }

    var displayName: String {
        "\(country) / \(location)"
    }
}

enum VPNRegionCatalog {
    static let sourceURL = URL(string: "https://api.surfshark.com/v4/server/clusters")!
    static let fallbackRegion = VPNRegion(
        country: "United States",
        countryCode: "US",
        group: "Americas",
        location: "New York",
        endpointHost: "us-nyc.prod.surfshark.com",
        publicKey: "rhuoCmHdyYrh0zW3J0YXZK4aN3It7DD26TXlACuWnwU="
    )

    static func regions(from data: Data) throws -> [VPNRegion] {
        let clusters = try JSONDecoder().decode([SurfsharkCluster].self, from: data)
        var seenEndpoints = Set<String>()
        let parsedRegions = clusters.compactMap { cluster -> VPNRegion? in
            let endpointHost = cluster.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let publicKey = cluster.publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let country = cluster.country.trimmingCharacters(in: .whitespacesAndNewlines)
            let location = cluster.location.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                cluster.type == "generic",
                !endpointHost.isEmpty,
                !publicKey.isEmpty,
                !country.isEmpty,
                !location.isEmpty,
                seenEndpoints.insert(endpointHost.lowercased()).inserted
            else {
                return nil
            }

            return VPNRegion(
                country: country,
                countryCode: cluster.countryCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                group: cluster.region?.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location,
                endpointHost: endpointHost,
                publicKey: publicKey
            )
        }

        return parsedRegions.sorted(by: regionSort)
    }

    static func sortedRegions(
        _ regions: [VPNRegion],
        favoriteEndpoints: [String],
        selectedEndpoint: String
    ) -> [VPNRegion] {
        let favoriteSet = Set(favoriteEndpoints.map { $0.lowercased() })
        let selectedEndpoint = selectedEndpoint.lowercased()

        return regions.sorted { lhs, rhs in
            let lhsFavorite = favoriteSet.contains(lhs.id)
            let rhsFavorite = favoriteSet.contains(rhs.id)
            if lhsFavorite != rhsFavorite {
                return lhsFavorite
            }

            let lhsSelected = lhs.id == selectedEndpoint
            let rhsSelected = rhs.id == selectedEndpoint
            if lhsSelected != rhsSelected {
                return lhsSelected
            }

            return regionSort(lhs, rhs)
        }
    }

    static func region(matching endpoint: String, in regions: [VPNRegion]) -> VPNRegion? {
        let normalizedEndpoint = endpoint.lowercased()
        return regions.first { $0.id == normalizedEndpoint }
    }

    private static func regionSort(_ lhs: VPNRegion, _ rhs: VPNRegion) -> Bool {
        lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }
}

private struct SurfsharkCluster: Decodable {
    let country: String
    let countryCode: String?
    let region: String?
    let location: String
    let connectionName: String
    let publicKey: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case country
        case countryCode
        case region
        case location
        case connectionName
        case publicKey = "pubKey"
        case type
    }
}
