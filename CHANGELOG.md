# Changelog

All notable changes to ASUS Fusion VPN will be documented in this file.

This project uses semantic versioning for public releases.

## [Unreleased]

### Changed

- Make the top status button double as the VPN action/status control: hollow with `Connect to <profile>` while disconnected and dark green with `Disconnect from <profile>` while connected.
- Simplify the profile header line to show only the profile name and selected VPN location.
- Re-align the custom `Refresh Status` shortcut against the native menu shortcut column.
- Restore the known-good `1.0.4` VPN activation path: read the full router status before toggling, write the selected Surfshark endpoint on connect, resolve the endpoint with the router's original `nslookup` flow, and run ASUSWRT service/policy commands in the same order as the working release.
- Roll password storage back to app preferences to avoid Keychain prompts during launch, status refresh, and connect/disconnect.
- Document that users upgrading from the Keychain-based build should re-enter the router password once in Settings.
- Roll the Region picker back to Surfshark catalog locations only; the VPN Unit finder once again only fills the profile name and unit number.
- Keep the router password out of the expect child-process environment by handing it to the SSH helper over standard input.
- Preserve friendly Surfshark region names for selected endpoints, including fallback display names such as `United States / Atlanta` and `Atlanta, US` when live IP location lookup is unavailable.
- Restore the router policy-rule and stale WireGuard route/interface cleanup commands from the working release.
- Treat a live WireGuard interface or route as connected even when the latest-handshake timestamp lags, matching how ASUSWRT reports the VPN as connected.
- Treat an inactive VPN Fusion profile as disconnected even if stale WireGuard routes or interfaces are still present, so the menu does not claim the VPN is connected when the router UI shows it off.

## [1.0.9] - 2026-05-10

### Fixed

- Align the custom `Command-R` shortcut with the native menu shortcut column.
- Stop automatic status refreshes from flashing the menu bar icon into the bright in-progress state when the VPN state has not changed.

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
