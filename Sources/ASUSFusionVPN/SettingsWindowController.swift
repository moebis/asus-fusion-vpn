import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let routerHostField = NSTextField()
    private let portField = NSTextField()
    private let usernameField = NSTextField()
    private let passwordField = NSSecureTextField()
    private let visiblePasswordField = NSTextField()
    private let passwordVisibilityButton = NSButton()
    private let profileField = NSTextField()
    private let unitField = NSTextField()
    private let findVPNUnitButton = NSButton()
    private let regionPopup = NSPopUpButton()
    private let favoriteRegionButton = NSButton()
    private let onSave: @MainActor (AppSettings) -> Void
    private var regions: [VPNRegion]
    private var selectedRegionEndpoint: String
    private var selectedRegionPublicKey: String
    private var favoriteRegionEndpoints: [String]
    private var regionLoadTask: Task<Void, Never>?
    private var isPasswordVisible = false
    var onClose: (() -> Void)?

    init(settings: AppSettings, onSave: @escaping @MainActor (AppSettings) -> Void) {
        self.onSave = onSave
        self.regions = VPNRegionStore.initialRegions(settings: settings)
        self.selectedRegionEndpoint = settings.selectedRegionEndpoint
        self.selectedRegionPublicKey = settings.selectedRegionPublicKey
        self.favoriteRegionEndpoints = settings.favoriteRegionEndpoints

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 372),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ASUS Fusion VPN Settings"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 620, height: 372)

        super.init(window: window)
        window.delegate = self
        buildContent(settings: settings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        regionLoadTask?.cancel()
        onClose?()
    }

    private func buildContent(settings: AppSettings) {
        guard let contentView = window?.contentView else { return }

        routerHostField.stringValue = settings.routerHost
        portField.stringValue = String(settings.sshPort)
        usernameField.stringValue = settings.username
        passwordField.stringValue = settings.password
        visiblePasswordField.stringValue = settings.password
        profileField.stringValue = settings.profileName
        unitField.stringValue = String(settings.vpnUnit)
        configurePasswordVisibilityControls()
        configureVPNUnitControls()
        configureRegionControls()

        let title = NSTextField(labelWithString: "ASUS Fusion VPN")
        title.font = .systemFont(ofSize: 22, weight: .bold)

        let subtitle = NSTextField(labelWithString: "Connect to your ASUS router over LAN-only SSH and toggle a VPN Fusion profile.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        let form = NSGridView(views: [
            row("Router Host", routerHostField),
            row("SSH Port", portField),
            row("Username", usernameField),
            row("Password", passwordControl()),
            row("Profile Name", profileField),
            row("VPN Unit", vpnUnitControl()),
            row("Region", regionControl())
        ])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 0).width = 112
        form.column(at: 1).width = 400
        form.rowSpacing = 8
        form.columnSpacing = 12
        for rowIndex in 0..<form.numberOfRows {
            form.row(at: rowIndex).yPlacement = .center
            form.cell(atColumnIndex: 0, rowIndex: rowIndex).yPlacement = .center
            form.cell(atColumnIndex: 1, rowIndex: rowIndex).yPlacement = .center
        }

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded

        let buttons = NSStackView(views: [cancelButton, saveButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 10

        let buttonRow = NSView()
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.addSubview(buttons)
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [title, subtitle, form, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -22),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.heightAnchor.constraint(equalToConstant: 32),
            buttons.trailingAnchor.constraint(equalTo: buttonRow.trailingAnchor),
            buttons.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor)
        ])

        loadRegions()
    }

    private func row(_ label: String, _ field: NSTextField) -> [NSView] {
        field.placeholderString = label
        field.lineBreakMode = .byTruncatingTail
        return [labelView(label), field]
    }

    private func row(_ label: String, _ view: NSView) -> [NSView] {
        [labelView(label), view]
    }

    private func labelView(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }

    private func configurePasswordVisibilityControls() {
        passwordField.placeholderString = "Password"
        visiblePasswordField.placeholderString = "Password"
        visiblePasswordField.isHidden = true

        passwordVisibilityButton.image = NSImage(
            systemSymbolName: "eye",
            accessibilityDescription: "Show Password"
        )
        passwordVisibilityButton.bezelStyle = .texturedRounded
        passwordVisibilityButton.isBordered = false
        passwordVisibilityButton.target = self
        passwordVisibilityButton.action = #selector(togglePasswordVisibility)
    }

    private func configureVPNUnitControls() {
        unitField.placeholderString = "VPN Unit"
        unitField.lineBreakMode = .byTruncatingTail

        findVPNUnitButton.title = "Find..."
        findVPNUnitButton.bezelStyle = .rounded
        findVPNUnitButton.toolTip = "Find the VPN Fusion unit from the router"
        findVPNUnitButton.target = self
        findVPNUnitButton.action = #selector(findVPNUnit)
    }

    private func passwordControl() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        passwordField.translatesAutoresizingMaskIntoConstraints = false
        visiblePasswordField.translatesAutoresizingMaskIntoConstraints = false
        passwordVisibilityButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(passwordField)
        container.addSubview(visiblePasswordField)
        container.addSubview(passwordVisibilityButton)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 400),
            container.heightAnchor.constraint(equalToConstant: 28),
            passwordVisibilityButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            passwordVisibilityButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            passwordVisibilityButton.widthAnchor.constraint(equalToConstant: 28),
            passwordVisibilityButton.heightAnchor.constraint(equalToConstant: 24),

            passwordField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: passwordVisibilityButton.leadingAnchor, constant: -8),
            passwordField.topAnchor.constraint(equalTo: container.topAnchor),
            passwordField.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            visiblePasswordField.leadingAnchor.constraint(equalTo: passwordField.leadingAnchor),
            visiblePasswordField.trailingAnchor.constraint(equalTo: passwordField.trailingAnchor),
            visiblePasswordField.topAnchor.constraint(equalTo: passwordField.topAnchor),
            visiblePasswordField.bottomAnchor.constraint(equalTo: passwordField.bottomAnchor)
        ])

        return container
    }

    private func vpnUnitControl() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        unitField.translatesAutoresizingMaskIntoConstraints = false
        findVPNUnitButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(unitField)
        container.addSubview(findVPNUnitButton)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 400),
            container.heightAnchor.constraint(equalToConstant: 28),
            findVPNUnitButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            findVPNUnitButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            findVPNUnitButton.widthAnchor.constraint(equalToConstant: 82),
            findVPNUnitButton.heightAnchor.constraint(equalToConstant: 28),

            unitField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            unitField.trailingAnchor.constraint(equalTo: findVPNUnitButton.leadingAnchor, constant: -8),
            unitField.topAnchor.constraint(equalTo: container.topAnchor),
            unitField.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func configureRegionControls() {
        regionPopup.target = self
        regionPopup.action = #selector(regionSelectionChanged)

        favoriteRegionButton.image = NSImage(
            systemSymbolName: "star",
            accessibilityDescription: "Favorite Region"
        )
        favoriteRegionButton.isBordered = false
        favoriteRegionButton.target = self
        favoriteRegionButton.action = #selector(toggleFavoriteRegion)

        refreshRegionMenu()
    }

    private func regionControl() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        regionPopup.translatesAutoresizingMaskIntoConstraints = false
        favoriteRegionButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(regionPopup)
        container.addSubview(favoriteRegionButton)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 400),
            container.heightAnchor.constraint(equalToConstant: 28),
            regionPopup.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            regionPopup.trailingAnchor.constraint(equalTo: favoriteRegionButton.leadingAnchor, constant: -8),
            regionPopup.topAnchor.constraint(equalTo: container.topAnchor),
            regionPopup.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            favoriteRegionButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            favoriteRegionButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            favoriteRegionButton.widthAnchor.constraint(equalToConstant: 28),
            favoriteRegionButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        return container
    }

    private func refreshRegionMenu() {
        let favoriteSet = Set(favoriteRegionEndpoints.map { $0.lowercased() })
        let sortedRegions = VPNRegionCatalog.sortedRegions(
            regions,
            favoriteEndpoints: favoriteRegionEndpoints,
            selectedEndpoint: selectedRegionEndpoint
        )

        regionPopup.removeAllItems()
        var didAddFavorite = false
        var didAddSeparator = false

        for region in sortedRegions {
            let isFavorite = favoriteSet.contains(region.id)
            if didAddFavorite, !isFavorite, !didAddSeparator {
                regionPopup.menu?.addItem(.separator())
                didAddSeparator = true
            }

            let item = NSMenuItem(
                title: "\(isFavorite ? "★ " : "")\(region.displayName)",
                action: nil,
                keyEquivalent: ""
            )
            item.representedObject = region.endpointHost
            regionPopup.menu?.addItem(item)
            didAddFavorite = didAddFavorite || isFavorite
        }

        if regionPopup.numberOfItems == 0 {
            let fallback = VPNRegionCatalog.fallbackRegion
            let item = NSMenuItem(title: fallback.displayName, action: nil, keyEquivalent: "")
            item.representedObject = fallback.endpointHost
            regionPopup.menu?.addItem(item)
        }

        if let selectedItem = regionPopup.itemArray.first(where: {
            ($0.representedObject as? String)?.caseInsensitiveCompare(selectedRegionEndpoint) == .orderedSame
        }) {
            regionPopup.select(selectedItem)
        } else {
            regionPopup.selectItem(at: 0)
            updateSelectedRegionFromPopup()
        }

        updateFavoriteRegionButton()
    }

    private func loadRegions() {
        regionLoadTask?.cancel()
        regionLoadTask = Task { [weak self] in
            do {
                let fetchedRegions = try await VPNRegionStore.fetchRegions()
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard let self else { return }
                    VPNRegionStore.saveCachedRegions(fetchedRegions)
                    self.regions = fetchedRegions
                    self.repairSelectedRegionFromCatalog()
                    self.refreshRegionMenu()
                }
            } catch {
                // Keep the cached/fallback list. The app can still connect with saved settings.
            }
        }
    }

    private func repairSelectedRegionFromCatalog() {
        guard let region = VPNRegionCatalog.region(matching: selectedRegionEndpoint, in: regions) else {
            return
        }

        selectedRegionPublicKey = region.publicKey
    }

    @objc private func regionSelectionChanged() {
        updateSelectedRegionFromPopup()
        updateFavoriteRegionButton()
    }

    private func updateSelectedRegionFromPopup() {
        guard
            let endpointHost = regionPopup.selectedItem?.representedObject as? String,
            let region = VPNRegionCatalog.region(matching: endpointHost, in: regions)
        else {
            return
        }

        selectedRegionEndpoint = region.endpointHost
        selectedRegionPublicKey = region.publicKey
    }

    @objc private func toggleFavoriteRegion() {
        updateSelectedRegionFromPopup()
        let endpoint = selectedRegionEndpoint.lowercased()
        let wasFavorite = favoriteRegionEndpoints.contains { $0.lowercased() == endpoint }
        favoriteRegionEndpoints.removeAll { $0.lowercased() == endpoint }

        if !wasFavorite {
            favoriteRegionEndpoints.append(selectedRegionEndpoint)
        }

        refreshRegionMenu()
    }

    private func updateFavoriteRegionButton() {
        let isFavorite = favoriteRegionEndpoints.contains {
            $0.caseInsensitiveCompare(selectedRegionEndpoint) == .orderedSame
        }
        favoriteRegionButton.state = isFavorite ? .on : .off
        favoriteRegionButton.image = NSImage(
            systemSymbolName: isFavorite ? "star.fill" : "star",
            accessibilityDescription: isFavorite ? "Unfavorite Region" : "Favorite Region"
        )
    }

    @objc private func togglePasswordVisibility() {
        if isPasswordVisible {
            passwordField.stringValue = visiblePasswordField.stringValue
        } else {
            visiblePasswordField.stringValue = passwordField.stringValue
        }

        isPasswordVisible.toggle()
        passwordField.isHidden = isPasswordVisible
        visiblePasswordField.isHidden = !isPasswordVisible
        passwordVisibilityButton.image = NSImage(
            systemSymbolName: isPasswordVisible ? "eye.slash" : "eye",
            accessibilityDescription: isPasswordVisible ? "Hide Password" : "Show Password"
        )
    }

    @objc private func findVPNUnit() {
        let routerHost = routerHostField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileName = profileField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = currentPassword()
        let sshPort = Int(portField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 22

        guard !routerHost.isEmpty, !username.isEmpty, !password.isEmpty else {
            showAlert(
                title: "Could not find VPN unit",
                message: "Router host, username, and password are required before searching."
            )
            return
        }

        let currentUnit = Int(unitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? AppSettings.defaultVPNUnit
        let settings = AppSettings(
            routerHost: routerHost,
            sshPort: sshPort,
            username: username,
            password: password,
            profileName: profileName.isEmpty ? AppSettings.defaultProfileName : profileName,
            vpnUnit: currentUnit,
            selectedRegionEndpoint: selectedRegionEndpoint,
            selectedRegionPublicKey: selectedRegionPublicKey,
            favoriteRegionEndpoints: favoriteRegionEndpoints
        )

        setVPNUnitSearchInProgress(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try SSHRouterClient(settings: settings).vpnFusionProfiles()
            }

            Task { @MainActor [weak self] in
                self?.setVPNUnitSearchInProgress(false)
                self?.handleVPNUnitSearchResult(result, preferredProfileName: profileName)
            }
        }
    }

    private func currentPassword() -> String {
        isPasswordVisible ? visiblePasswordField.stringValue : passwordField.stringValue
    }

    private func setVPNUnitSearchInProgress(_ isSearching: Bool) {
        findVPNUnitButton.isEnabled = !isSearching
        findVPNUnitButton.title = isSearching ? "Finding..." : "Find..."
    }

    private func handleVPNUnitSearchResult(_ result: Result<[VPNFusionProfile], Error>, preferredProfileName: String) {
        switch result {
        case .success(let profiles):
            applyDiscoveredVPNProfiles(profiles, preferredProfileName: preferredProfileName)
        case .failure(let error):
            showAlert(title: "Could not find VPN unit", message: error.localizedDescription)
        }
    }

    private func applyDiscoveredVPNProfiles(_ profiles: [VPNFusionProfile], preferredProfileName: String) {
        guard !profiles.isEmpty else {
            showAlert(
                title: "Could not find VPN unit",
                message: "The router did not return any VPN Fusion profiles."
            )
            return
        }

        let trimmedProfileName = preferredProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedProfileName.isEmpty {
            let matches = profiles.filter {
                $0.name.caseInsensitiveCompare(trimmedProfileName) == .orderedSame
            }

            if matches.count == 1, let match = matches.first {
                applyVPNFusionProfile(match)
                showAlert(
                    title: "VPN unit found",
                    message: "Found \(match.name) on VPN unit \(match.unit).",
                    style: .informational
                )
                return
            }
        }

        chooseVPNFusionProfile(from: profiles)
    }

    private func chooseVPNFusionProfile(from profiles: [VPNFusionProfile]) {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 28), pullsDown: false)
        popup.removeAllItems()
        for profile in profiles {
            let item = NSMenuItem(
                title: "\(profile.name) - Unit \(profile.unit)\(profile.isEnabled ? " - Enabled" : "")",
                action: nil,
                keyEquivalent: ""
            )
            item.representedObject = profile
            popup.menu?.addItem(item)
        }

        let alert = NSAlert()
        alert.messageText = "Choose VPN Fusion profile"
        alert.informativeText = "Select the router profile this app should control."
        alert.alertStyle = .informational
        alert.accessoryView = popup
        alert.addButton(withTitle: "Use Selected")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn,
              let profile = popup.selectedItem?.representedObject as? VPNFusionProfile
        else {
            return
        }

        applyVPNFusionProfile(profile)
    }

    private func applyVPNFusionProfile(_ profile: VPNFusionProfile) {
        profileField.stringValue = profile.name
        unitField.stringValue = String(profile.unit)
    }

    @objc private func save() {
        let routerHost = routerHostField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileName = profileField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = currentPassword()
        let sshPort = Int(portField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 22
        let vpnUnit = Int(unitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? AppSettings.defaultVPNUnit
        updateSelectedRegionFromPopup()

        guard !routerHost.isEmpty, !username.isEmpty, !password.isEmpty, !profileName.isEmpty else {
            showAlert(message: "Router host, username, password, and profile name are required.")
            return
        }

        let settings = AppSettings(
            routerHost: routerHost,
            sshPort: sshPort,
            username: username,
            password: password,
            profileName: profileName,
            vpnUnit: vpnUnit,
            selectedRegionEndpoint: selectedRegionEndpoint,
            selectedRegionPublicKey: selectedRegionPublicKey,
            favoriteRegionEndpoints: favoriteRegionEndpoints
        )
        settings.save()

        onSave(settings)
        close()
    }

    @objc private func cancel() {
        close()
    }

    private func showAlert(message: String) {
        showAlert(title: "Could not save settings", message: message)
    }

    private func showAlert(title: String, message: String) {
        showAlert(title: title, message: message, style: .warning)
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }
}
