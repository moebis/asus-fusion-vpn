# Changelog

All notable changes to ASUS Fusion VPN will be documented in this file.

This project uses semantic versioning for public releases.

## [1.0.8] - 2026-05-10

### Changed

- Move the connect/disconnect button above the Surfshark status line.
- Color the connect button green and the disconnect button red.
- Widen the custom menu rows and move the `Command-R` shortcut further right to line up with native shortcuts.

## [1.0.7] - 2026-05-10

### Changed

- Move the connect/disconnect action directly under the status line and render it as a button.
- Move `Refresh Status` under `Open Router VPN Page`, align the custom refresh row with the settings section, and add `Command-O` for opening the router VPN page.

## [1.0.6] - 2026-05-10

### Fixed

- Keep the menu open when clicking `Refresh Status` by rendering refresh as an in-menu control instead of a standard closing menu command.

## [1.0.5] - 2026-05-10

### Added

- Show router CPU and memory usage in a separate menu section.
- Add a hard process timeout around SSH/expect command execution so hung router commands are terminated.

### Changed

- Collect router resource usage during the existing status refresh command instead of opening a separate SSH session.

## [1.0.4] - 2026-05-10

### Added

- Add a Settings checkbox to disable display-only IP geolocation lookups from the router.
- Add validation for router host, SSH username, SSH port, and VPN unit settings.

### Changed

- Store router passwords in macOS Keychain and migrate legacy saved passwords out of app preferences.
- Send the router password to the SSH helper through standard input instead of a child-process environment variable.
- Use an app-specific SSH `known_hosts` file under Application Support for host key pinning after first connection.
- Check VPN policy rules and routes against the configured VPN unit instead of hard-coding route table `5`.

### Fixed

- Reject invalid SSH port and VPN unit values before saving settings or running the VPN Unit finder.
- Remove an unused SSH argument helper now that the app uses the expect-based SSH path.

## [1.0.3] - 2026-05-09

### Fixed

- Restore visible menu bar icon nodes while preserving one-pass inactive opacity so nodes do not show transparent overlaps with the connecting lines.

## [1.0.2] - 2026-05-09

### Fixed

- Simplify the menu bar icon to a single solid glyph so inactive opacity is uniform and no line/circle intersections are visible.

## [1.0.1] - 2026-05-09

### Fixed

- Render the menu bar icon with reduced opacity while disconnected or unknown so inactive VPN state is visually distinct from the connected state.

## [1.0] - 2026-05-09

### Added

- Native macOS menu bar app for toggling an ASUSWRT VPN Fusion profile over LAN-only SSH.
- Settings window for router host, SSH port, username, password, VPN Fusion profile name, VPN unit, and Surfshark region.
- VPN Unit `Find...` helper that reads VPN Fusion profiles from the router with a read-only SSH command.
- Surfshark region catalog loading, cached fallback regions, and favorite regions.
- Menu status details for connection state, Internet IP/location, VPN tunnel IP, VPN exit IP, and VPN location.
- Connect/disconnect behavior for ASUSWRT VPN Fusion WireGuard profiles, including stale route/interface cleanup.
- Universal macOS app build for Apple Silicon and Intel Macs.
- Branded DMG installer with app icon, Applications shortcut, blue spotlight, drag arrow, and custom volume icon.
- GitHub-ready README with redacted screenshots and setup documentation.

### Security

- Router credentials were stored in app preferences for unsigned local builds; the README documented this tradeoff.
- README screenshots redact local router details, usernames, IP addresses, and location data.
