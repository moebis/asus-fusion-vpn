import Foundation

struct VPNRegion: Codable, Equatable, Hashable, Identifiable, Sendable {
    let country: String
    let countryCode: String?
    let group: String?
    let location: String
    let endpointHost: String
    let publicKey: String

    init(
        country: String,
        countryCode: String?,
        group: String?,
        location: String,
        endpointHost: String,
        publicKey: String
    ) {
        self.country = country
        self.countryCode = countryCode
        self.group = group
        self.location = location
        self.endpointHost = endpointHost
        self.publicKey = publicKey
    }

    var id: String {
        endpointHost.lowercased()
    }

    var displayName: String {
        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCountry.isEmpty {
            return trimmedLocation
        }
        if trimmedLocation.isEmpty || trimmedCountry == trimmedLocation {
            return trimmedCountry
        }
        return "\(country) / \(location)"
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

    static func selectedRegion(endpointHost: String, publicKey: String) -> VPNRegion {
        if let knownLocation = surfsharkEndpointLocation(for: endpointHost) {
            return VPNRegion(
                country: knownLocation.country,
                countryCode: knownLocation.countryCode,
                group: knownLocation.group,
                location: knownLocation.city,
                endpointHost: endpointHost,
                publicKey: publicKey
            )
        }

        return VPNRegion(
            country: "Selected",
            countryCode: nil,
            group: nil,
            location: endpointHost,
            endpointHost: endpointHost,
            publicKey: publicKey
        )
    }

    static func displayLocation(forEndpointHost endpointHost: String?) -> String? {
        guard let endpointHost, let knownLocation = surfsharkEndpointLocation(for: endpointHost) else {
            return nil
        }

        return "\(knownLocation.city), \(knownLocation.countryCode)"
    }

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

    private static func surfsharkEndpointLocation(for endpointHost: String) -> SurfsharkEndpointLocation? {
        let endpointCode = endpointHost
            .lowercased()
            .split(separator: ".")
            .first
            .map(String.init) ?? ""

        return knownSurfsharkEndpointLocations[endpointCode]
    }

    private static let knownSurfsharkEndpointLocations: [String: SurfsharkEndpointLocation] = [
        "at-vie": SurfsharkEndpointLocation(country: "Austria", countryCode: "AT", group: "Europe", city: "Vienna"),
        "au-syd": SurfsharkEndpointLocation(country: "Australia", countryCode: "AU", group: "Asia Pacific", city: "Sydney"),
        "be-bru": SurfsharkEndpointLocation(country: "Belgium", countryCode: "BE", group: "Europe", city: "Brussels"),
        "ca-mon": SurfsharkEndpointLocation(country: "Canada", countryCode: "CA", group: "Americas", city: "Montreal"),
        "ca-tor": SurfsharkEndpointLocation(country: "Canada", countryCode: "CA", group: "Americas", city: "Toronto"),
        "ca-van": SurfsharkEndpointLocation(country: "Canada", countryCode: "CA", group: "Americas", city: "Vancouver"),
        "ch-zur": SurfsharkEndpointLocation(country: "Switzerland", countryCode: "CH", group: "Europe", city: "Zurich"),
        "cz-prg": SurfsharkEndpointLocation(country: "Czechia", countryCode: "CZ", group: "Europe", city: "Prague"),
        "de-ber": SurfsharkEndpointLocation(country: "Germany", countryCode: "DE", group: "Europe", city: "Berlin"),
        "de-fra": SurfsharkEndpointLocation(country: "Germany", countryCode: "DE", group: "Europe", city: "Frankfurt"),
        "dk-cph": SurfsharkEndpointLocation(country: "Denmark", countryCode: "DK", group: "Europe", city: "Copenhagen"),
        "es-mad": SurfsharkEndpointLocation(country: "Spain", countryCode: "ES", group: "Europe", city: "Madrid"),
        "fi-hel": SurfsharkEndpointLocation(country: "Finland", countryCode: "FI", group: "Europe", city: "Helsinki"),
        "fr-par": SurfsharkEndpointLocation(country: "France", countryCode: "FR", group: "Europe", city: "Paris"),
        "it-mil": SurfsharkEndpointLocation(country: "Italy", countryCode: "IT", group: "Europe", city: "Milan"),
        "it-rom": SurfsharkEndpointLocation(country: "Italy", countryCode: "IT", group: "Europe", city: "Rome"),
        "jp-tok": SurfsharkEndpointLocation(country: "Japan", countryCode: "JP", group: "Asia Pacific", city: "Tokyo"),
        "nl-ams": SurfsharkEndpointLocation(country: "Netherlands", countryCode: "NL", group: "Europe", city: "Amsterdam"),
        "no-osl": SurfsharkEndpointLocation(country: "Norway", countryCode: "NO", group: "Europe", city: "Oslo"),
        "pl-waw": SurfsharkEndpointLocation(country: "Poland", countryCode: "PL", group: "Europe", city: "Warsaw"),
        "se-sto": SurfsharkEndpointLocation(country: "Sweden", countryCode: "SE", group: "Europe", city: "Stockholm"),
        "sg-sng": SurfsharkEndpointLocation(country: "Singapore", countryCode: "SG", group: "Asia Pacific", city: "Singapore"),
        "uk-lon": SurfsharkEndpointLocation(country: "United Kingdom", countryCode: "GB", group: "Europe", city: "London"),
        "uk-man": SurfsharkEndpointLocation(country: "United Kingdom", countryCode: "GB", group: "Europe", city: "Manchester"),
        "us-atl": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Atlanta"),
        "us-bos": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Boston"),
        "us-clt": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Charlotte"),
        "us-chi": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Chicago"),
        "us-dal": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Dallas"),
        "us-den": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Denver"),
        "us-dtw": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Detroit"),
        "us-hou": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Houston"),
        "us-lax": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Los Angeles"),
        "us-mia": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Miami"),
        "us-nyc": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "New York"),
        "us-phx": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Phoenix"),
        "us-sea": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Seattle"),
        "us-sfo": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "San Francisco"),
        "us-slc": SurfsharkEndpointLocation(country: "United States", countryCode: "US", group: "Americas", city: "Salt Lake City")
    ]
}

private struct SurfsharkEndpointLocation {
    let country: String
    let countryCode: String
    let group: String
    let city: String
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
