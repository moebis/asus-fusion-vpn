import Foundation

/// Display-only IP geolocation with an in-memory cache.
///
/// WAN and VPN endpoint addresses rarely change, so each address is looked up once and
/// reused for every status poll instead of hitting the lookup services every 30 seconds.
actor IPLocationResolver {
    static let shared = IPLocationResolver()

    private static let successLifetime: TimeInterval = 12 * 60 * 60
    private static let failureLifetime: TimeInterval = 5 * 60

    private struct Entry {
        let location: String?
        let expiresAt: Date
    }

    private var cache: [String: Entry] = [:]
    private var inFlight: [String: Task<String?, Never>] = [:]
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 10
        configuration.waitsForConnectivity = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    func location(for ipAddress: String?) async -> String? {
        guard let ipAddress = Self.normalizedIPAddress(ipAddress) else {
            return nil
        }

        if let entry = cache[ipAddress], entry.expiresAt > Date() {
            return entry.location
        }

        if let task = inFlight[ipAddress] {
            return await task.value
        }

        let session = session
        let task = Task { await Self.lookup(ipAddress, session: session) }
        inFlight[ipAddress] = task
        let location = await task.value
        inFlight[ipAddress] = nil
        cache[ipAddress] = Entry(
            location: location,
            expiresAt: Date().addingTimeInterval(location == nil ? Self.failureLifetime : Self.successLifetime)
        )
        return location
    }

    static func geolocationURLs(for ipAddress: String) -> [URL] {
        [
            "https://api.ip2location.io/?ip=\(ipAddress)",
            "https://ipinfo.io/\(ipAddress)/json"
        ].compactMap(URL.init(string:))
    }

    static func normalizedIPAddress(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        guard trimmed.range(of: #"^([0-9]{1,3}\.){3}[0-9]{1,3}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return trimmed
    }

    private static func lookup(_ ipAddress: String, session: URLSession) async -> String? {
        for url in geolocationURLs(for: ipAddress) {
            guard
                let (data, response) = try? await session.data(from: url),
                let httpResponse = response as? HTTPURLResponse,
                200..<300 ~= httpResponse.statusCode,
                let location = VPNFusionParser.displayLocation(fromIPInfoData: data)
            else {
                continue
            }
            return location
        }
        return nil
    }
}
