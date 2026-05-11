import AppKit

@MainActor
enum StatusMenuTitleFormatter {
    static let profileColor = NSColor.labelColor
    static let detailColor = NSColor.secondaryLabelColor

    static func title(
        profileName: String,
        regionName: String
    ) -> NSAttributedString {
        let title = NSMutableAttributedString()
        title.append(segment("\(profileName): ", color: profileColor))
        title.append(segment(regionName, color: detailColor))
        return title
    }

    static func plainTitle(_ text: String) -> NSAttributedString {
        segment(text, color: detailColor)
    }

    private static func segment(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: color
            ]
        )
    }
}
