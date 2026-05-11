import AppKit
import Testing
@testable import ASUSFusionVPN

@MainActor
@Test func statusTitleShowsProfileAndRegionOnly() throws {
    let title = StatusMenuTitleFormatter.title(
        profileName: "Surfshark",
        regionName: "United States / New York"
    )

    #expect(title.string == "Surfshark: United States / New York")
    let profileColor = try foregroundColor(in: title, matching: "Surfshark:")
    let detailColor = try foregroundColor(in: title, matching: "United States / New York")
    #expect(profileColor === StatusMenuTitleFormatter.profileColor)
    #expect(profileColor.isEqual(NSColor.labelColor))
    #expect(detailColor === StatusMenuTitleFormatter.detailColor)
}

@MainActor
private func foregroundColor(in title: NSAttributedString, matching text: String) throws -> NSColor {
    let range = (title.string as NSString).range(of: text)
    guard range.location != NSNotFound else {
        throw StatusTitleTestError(message: "Could not find \(text) in title.")
    }

    guard let color = title.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor else {
        throw StatusTitleTestError(message: "Could not find foreground color for \(text).")
    }

    return color
}

private struct StatusTitleTestError: Error {
    let message: String
}
