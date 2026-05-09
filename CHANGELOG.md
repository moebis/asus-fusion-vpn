# Changelog

All notable changes to ASUS Fusion VPN will be documented in this file.

This project uses semantic versioning for public releases.

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

- Router credentials are stored in app preferences for unsigned local builds; the README documents this tradeoff.
- README screenshots redact local router details, usernames, IP addresses, and location data.
