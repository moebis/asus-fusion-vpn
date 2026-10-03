import AppKit

private enum ToggleButtonAppearance {
    static let disconnectedBackground = NSColor.clear
    static let disconnectedBorder = NSColor(calibratedWhite: 0.34, alpha: 1)
    static let connectedBackground = NSColor(calibratedRed: 0.05, green: 0.36, blue: 0.16, alpha: 1)
    static let workingBackground = NSColor(calibratedWhite: 0.12, alpha: 1)
}

private final class MenuActionRowView: NSView {
    enum Style {
        case plain
        case button
    }

    private static let rowWidth: CGFloat = 452
    private static let plainRowHeight: CGFloat = 28
    private static let buttonRowHeight: CGFloat = 44
    private static let shortcutColumnLeadingFromTrailing: CGFloat = -40
    private static let shortcutColumnWidth: CGFloat = 50
    private static let symbolCenterX: CGFloat = 21.5

    let button: NSButton
    private let shortcutField: NSTextField
    private let symbolView: NSImageView?
    private let style: Style
    private var buttonBackgroundColor: NSColor?
    private var buttonBorderColor: NSColor?
    private var buttonTitleColor = NSColor.white

    var title: String {
        get { button.title }
        set {
            button.title = newValue
            updateButtonTitle()
        }
    }

    var isEnabled: Bool {
        get { button.isEnabled }
        set {
            button.isEnabled = newValue
            if style == .button {
                button.contentTintColor = newValue ? buttonTitleColor : .disabledControlTextColor
                updateButtonAppearance()
                updateButtonTitle()
            } else {
                button.contentTintColor = newValue ? .labelColor : .disabledControlTextColor
            }
            shortcutField.textColor = newValue ? .tertiaryLabelColor : .disabledControlTextColor
            symbolView?.contentTintColor = newValue ? .labelColor : .disabledControlTextColor
        }
    }

    init(
        title: String,
        shortcut: String = "",
        style: Style = .plain,
        leadingInset: CGFloat? = nil,
        symbolName: String? = nil
    ) {
        self.style = style
        symbolView = symbolName
            .flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
            .map { NSImageView(image: $0) }
        button = NSButton(title: title, target: nil, action: nil)
        shortcutField = NSTextField(labelWithString: shortcut)
        let rowHeight = style == .button ? Self.buttonRowHeight : Self.plainRowHeight
        super.init(frame: NSRect(x: 0, y: 0, width: Self.rowWidth, height: rowHeight))
        let resolvedLeadingInset = leadingInset ?? (style == .button ? 12 : 38)

        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.alignment = style == .button ? .center : .left
        button.font = .menuFont(ofSize: 0)
        button.contentTintColor = style == .button ? .white : .labelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        if style == .button {
            button.wantsLayer = true
            button.layer?.cornerRadius = 8
            button.layer?.masksToBounds = true
            button.layer?.borderWidth = 0
            updateButtonTitle()
        }

        shortcutField.font = .menuFont(ofSize: 0)
        shortcutField.textColor = .tertiaryLabelColor
        shortcutField.alignment = .left
        shortcutField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(button)
        addSubview(shortcutField)
        if let symbolView {
            // Sits in the same column macOS uses for menu item images, so the title
            // lines up with native items such as Settings.
            symbolView.symbolConfiguration = .init(pointSize: NSFont.menuFont(ofSize: 0).pointSize, weight: .regular)
            symbolView.contentTintColor = .labelColor
            symbolView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(symbolView)
            NSLayoutConstraint.activate([
                symbolView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: Self.symbolCenterX),
                symbolView.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }

        if shortcut.isEmpty {
            shortcutField.isHidden = true
        }

        var constraints = [
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: resolvedLeadingInset),
            shortcutField.leadingAnchor.constraint(equalTo: trailingAnchor, constant: Self.shortcutColumnLeadingFromTrailing),
            shortcutField.widthAnchor.constraint(equalToConstant: Self.shortcutColumnWidth),
            shortcutField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ]

        if style == .button {
            constraints.append(contentsOf: [
                button.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
                button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
            ])
        } else {
            constraints.append(contentsOf: [
                button.topAnchor.constraint(equalTo: topAnchor),
                button.bottomAnchor.constraint(equalTo: bottomAnchor),
                button.trailingAnchor.constraint(equalTo: shortcutField.leadingAnchor, constant: -12)
            ])
        }

        NSLayoutConstraint.activate(constraints)
    }

    func setButtonBackground(_ color: NSColor) {
        setButtonAppearance(background: color)
    }

    func setButtonAppearance(
        background: NSColor,
        border: NSColor? = nil,
        titleColor: NSColor = .white
    ) {
        buttonBackgroundColor = background
        buttonBorderColor = border
        buttonTitleColor = titleColor
        button.contentTintColor = button.isEnabled ? titleColor : .disabledControlTextColor
        updateButtonAppearance()
        updateButtonTitle()
    }

    private func updateButtonAppearance() {
        guard style == .button else {
            return
        }

        let background = buttonBackgroundColor ?? .clear
        let border = buttonBorderColor
        button.layer?.backgroundColor = (button.isEnabled ? background : background.withAlphaComponent(0.35)).cgColor
        button.layer?.borderColor = (button.isEnabled ? border : border?.withAlphaComponent(0.45))?.cgColor
        button.layer?.borderWidth = border == nil ? 0 : 1
    }

    private func updateButtonTitle() {
        guard style == .button else {
            return
        }

        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: button.isEnabled ? buttonTitleColor : NSColor.disabledControlTextColor
            ]
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Status: Checking...", action: nil, keyEquivalent: "")
    private let wanIPMenuItem = NSMenuItem(title: "Internet IP: Checking...", action: nil, keyEquivalent: "")
    private let wanLocationMenuItem = NSMenuItem(title: "Internet Location: Checking...", action: nil, keyEquivalent: "")
    private let vpnTunnelIPMenuItem = NSMenuItem(title: "VPN Tunnel IP: Checking...", action: nil, keyEquivalent: "")
    private let vpnExitIPMenuItem = NSMenuItem(title: "VPN Exit IP: Checking...", action: nil, keyEquivalent: "")
    private let vpnLocationMenuItem = NSMenuItem(title: "VPN Location: Checking...", action: nil, keyEquivalent: "")
    private let routerCPUMenuItem = NSMenuItem(title: "Router CPU: Checking...", action: nil, keyEquivalent: "")
    private let routerMemoryMenuItem = NSMenuItem(title: "Router Memory: Checking...", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem()
    private let toggleMenuView = MenuActionRowView(title: "Connect", style: .button)
    private let refreshMenuItem = NSMenuItem()
    private let refreshMenuView = MenuActionRowView(
        title: "Refresh Status",
        shortcut: "⌘R",
        leadingInset: 35.5,
        symbolName: "arrow.clockwise"
    )
    private var settingsWindowController: SettingsWindowController?
    private var refreshTimer: Timer?
    private var settings = ScreenshotDemo.isEnabled ? ScreenshotDemo.settings : AppSettings.load()
    private var regions: [VPNRegion] = []
    private var lastStatus: VPNStatus?
    private var lastDisplayState: VPNConnectionState?
    private var lastToggleProfileName: String?
    private var lastRefreshDate: Date?
    private var lastCPUSample: RouterCPUSample?
    private var locationLabels: [String: String] = [:]
    private var isBusy = false
    private var routerTask: Task<Void, Never>?
    private var followUpRefreshTask: Task<Void, Never>?
    private var wakeObservers: [NSObjectProtocol] = []

    override init() {
        super.init()
        regions = VPNRegionStore.initialRegions(settings: settings)
        configureStatusItem()
        configureMenu()
        if let scene = ScreenshotDemo.scene {
            presentScreenshotDemo(scene)
            return
        }
        refreshRegionCatalog()
        refreshStatus()
        startRefreshTimer()
        observeSleepAndWake()
    }

    private func presentScreenshotDemo(_ scene: ScreenshotDemo.Scene) {
        handle(
            result: .success(ScreenshotDemo.status),
            presentation: .statusRefresh,
            displayState: nil,
            followUpDelay: nil
        )
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            switch scene {
            case .menu:
                self?.statusItem.button?.performClick(nil)
            case .settings:
                self?.openSettings()
                self?.settingsWindowController?.window?.makeFirstResponder(nil)
            }
        }
    }

    func shutdown() {
        refreshTimer?.invalidate()
        followUpRefreshTask?.cancel()
        routerTask?.cancel()
        wakeObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        wakeObservers = []
        if !ScreenshotDemo.isEnabled {
            SSHRouterClient(settings: settings).closeSharedConnection()
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: StatusRefreshPolicy.regularRefreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshStatus()
            }
        }
        // Let macOS coalesce the wake-up with other timers to save energy.
        timer.tolerance = StatusRefreshPolicy.regularRefreshTolerance
        RunLoop.main.add(timer, forMode: StatusRefreshPolicy.regularRefreshRunLoopMode)
        refreshTimer = timer
    }

    private func observeSleepAndWake() {
        let center = NSWorkspace.shared.notificationCenter
        wakeObservers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refreshTimer?.invalidate()
                self.refreshTimer = nil
                self.cancelFollowUpRefresh()
                SSHRouterClient(settings: self.settings).closeSharedConnection()
            }
        })
        wakeObservers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.startRefreshTimer()
                // Give Wi-Fi a moment to reassociate before talking to the router.
                self.scheduleFollowUpRefresh(after: StatusRefreshPolicy.wakeRefreshDelay)
            }
        })
    }

    private func configureStatusItem() {
        statusItem.button?.image = IconFactory.menuBarIcon(state: .unknown)
        statusItem.button?.toolTip = "ASUS Fusion VPN"
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.autoenablesItems = false
        menu.delegate = self
        updateToggleButton(for: .unknown)
        toggleMenuView.button.target = self
        toggleMenuView.button.action = #selector(toggleVPN)
        toggleMenuItem.view = toggleMenuView
        refreshMenuView.button.target = self
        refreshMenuView.button.action = #selector(refreshStatusFromOpenMenu)
        refreshMenuItem.view = refreshMenuView
        refreshMenuItem.target = self
        refreshMenuItem.action = #selector(refreshStatusFromOpenMenu)
        refreshMenuItem.keyEquivalent = "r"
        refreshMenuItem.keyEquivalentModifierMask = .command
        [
            wanIPMenuItem,
            wanLocationMenuItem,
            vpnTunnelIPMenuItem,
            vpnExitIPMenuItem,
            vpnLocationMenuItem,
            routerCPUMenuItem,
            routerMemoryMenuItem
        ].forEach {
            $0.isEnabled = false
        }

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)

        let routerItem = NSMenuItem(title: "Open Router VPN Page", action: #selector(openRouterPage), keyEquivalent: "o")
        routerItem.target = self
        routerItem.image = NSImage(systemSymbolName: "network", accessibilityDescription: nil)

        let quitItem = NSMenuItem(title: "Quit ASUS Fusion VPN", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)

        menu.addItem(toggleMenuItem)
        menu.addItem(statusMenuItem)
        menu.addItem(wanIPMenuItem)
        menu.addItem(wanLocationMenuItem)
        menu.addItem(vpnTunnelIPMenuItem)
        menu.addItem(vpnExitIPMenuItem)
        menu.addItem(vpnLocationMenuItem)
        menu.addItem(.separator())
        menu.addItem(routerCPUMenuItem)
        menu.addItem(routerMemoryMenuItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(routerItem)
        menu.addItem(refreshMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        if !ScreenshotDemo.isEnabled, StatusRefreshPolicy.shouldRefreshOnMenuOpen(lastRefreshDate: lastRefreshDate) {
            refreshStatus()
        }
    }

    @objc private func refreshStatus() {
        runRouterTask(
            busyTitle: "Status: Checking...",
            presentation: .statusRefresh
        ) { client in
            try await client.status()
        }
    }

    @objc private func refreshStatusFromOpenMenu() {
        refreshStatus()
    }

    @objc private func toggleVPN() {
        let shouldConnect = lastStatus?.state != .connected
        runRouterTask(
            busyTitle: shouldConnect ? "Status: Connecting..." : "Status: Disconnecting...",
            busyIconState: .connecting,
            busyButtonTitle: shouldConnect ? "Connecting to \(settings.profileName)..." : "Disconnecting from \(settings.profileName)...",
            followUpDelay: StatusRefreshPolicy.toggleFollowUpRefreshDelay
        ) { client in
            try await client.setEnabled(shouldConnect)
        }
    }

    private func reconnectVPNForRegionChange() {
        runRouterTask(
            busyTitle: "Status: Switching Region...",
            busyIconState: .connecting,
            busyButtonTitle: "Switching \(settings.profileName)...",
            resultDisplayState: .connecting,
            followUpDelay: StatusRefreshPolicy.toggleFollowUpRefreshDelay
        ) { client in
            _ = try await client.setEnabled(false)
            return try await client.setEnabled(true)
        }
    }

    @objc private func openSettings() {
        if let settingsWindowController, settingsWindowController.window?.isVisible == true {
            settingsWindowController.show()
            return
        }

        let controller = SettingsWindowController(settings: settings) { [weak self] newSettings in
            guard let self else { return }
            let oldSettings = self.settings
            let action = SettingsChangePolicy.action(
                oldSettings: oldSettings,
                newSettings: newSettings,
                currentState: self.lastStatus?.state,
                currentEndpointHost: self.lastStatus?.vpnEndpointHost
            )

            if StatusRefreshPolicy.connectionSettingsChanged(from: oldSettings, to: newSettings) {
                // Drop the shared SSH session so new credentials are actually used.
                SSHRouterClient(settings: oldSettings).closeSharedConnection()
                self.lastCPUSample = nil
            }
            self.settings = newSettings
            self.regions = VPNRegionStore.initialRegions(settings: newSettings)
            self.refreshStatusMenuTitle()
            self.refreshToggleButtonTitle()
            if let lastStatus = self.lastStatus {
                self.updateNetworkItems(for: self.displayStatus(lastStatus))
            }

            switch action {
            case .refresh:
                self.refreshStatus()
            case .reconnect:
                self.reconnectVPNForRegionChange()
            }
        }
        controller.onClose = { [weak self, weak controller] in
            if self?.settingsWindowController === controller {
                self?.settingsWindowController = nil
            }
        }
        settingsWindowController = controller
        controller.show()
    }

    @objc private func openRouterPage() {
        guard let url = URL(string: "http://\(settings.routerHost)/Advanced_VPNClient_Content.asp") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func runRouterTask(
        busyTitle: String,
        busyIconState: VPNConnectionState? = nil,
        busyButtonTitle: String? = nil,
        resultDisplayState: VPNConnectionState? = nil,
        followUpDelay: TimeInterval? = nil,
        presentation: RouterTaskPresentation = .visibleAction,
        task: @Sendable @escaping (SSHRouterClient) async throws -> VPNStatus
    ) {
        guard !isBusy else { return }
        if presentation.appliesBusyState {
            cancelFollowUpRefresh()
        }
        isBusy = true
        if presentation.appliesBusyState, lastStatus == nil {
            setPlainStatusTitle(busyTitle)
        }
        if presentation.appliesBusyState, let busyButtonTitle {
            toggleMenuView.title = busyButtonTitle
            toggleMenuView.setButtonAppearance(
                background: ToggleButtonAppearance.workingBackground,
                border: ToggleButtonAppearance.disconnectedBorder,
                titleColor: .labelColor
            )
        }
        if presentation.disablesControls {
            toggleMenuView.isEnabled = false
            refreshMenuView.isEnabled = false
        }
        if presentation.appliesBusyState, let busyIconState {
            statusItem.button?.image = IconFactory.menuBarIcon(state: busyIconState)
        }

        let client = SSHRouterClient(settings: settings)
        routerTask = Task { [weak self] in
            let result: Result<VPNStatus, Error>
            do {
                result = .success(try await task(client))
            } catch {
                result = .failure(error)
            }
            self?.handle(
                result: result,
                presentation: presentation,
                displayState: resultDisplayState,
                followUpDelay: followUpDelay
            )
        }
    }

    private func handle(
        result: Result<VPNStatus, Error>,
        presentation: RouterTaskPresentation,
        displayState: VPNConnectionState?,
        followUpDelay: TimeInterval?
    ) {
        isBusy = false
        routerTask = nil
        if presentation.disablesControls {
            toggleMenuView.isEnabled = true
            refreshMenuView.isEnabled = true
        }

        switch result {
        case .success(var status):
            lastRefreshDate = Date()
            applyCPUUsage(to: &status)
            updateMenu(for: status, displayState: displayState)
            lastStatus = status
            resolveLocations(for: status)
            scheduleFollowUpRefreshIfNeeded(
                after: displayState ?? status.state,
                forcedDelay: followUpDelay
            )
        case .failure(let error):
            if error is CancellationError {
                return
            }
            if presentation.appliesBusyState {
                cancelFollowUpRefresh()
            }
            let hadLastStatus = lastStatus != nil
            if presentation.clearsStatusOnFailure {
                lastStatus = nil
                lastDisplayState = nil
                lastToggleProfileName = nil
            }
            if let failureTitle = presentation.failureTitle(hasLastStatus: hadLastStatus) {
                setPlainStatusTitle(failureTitle)
                updateNetworkItems(for: nil)
                updateToggleButton(for: .unknown)
                statusItem.button?.image = IconFactory.menuBarIcon(state: .unknown)
                statusItem.button?.toolTip = "ASUS Fusion VPN - Unknown"
            }
            if presentation.showsFailureAlert {
                showError(error.localizedDescription)
            }
        }
    }

    /// Router CPU usage is the busy share of jiffies between this poll and the previous one.
    private func applyCPUUsage(to status: inout VPNStatus) {
        guard let sample = status.routerCPUSample else { return }
        status.routerCPUPercent = lastCPUSample.flatMap { sample.usagePercent(since: $0) }
            ?? lastStatus?.routerCPUPercent
        lastCPUSample = sample
    }

    /// Looks up display locations off the main path; the status is shown immediately and
    /// the location rows fill in when a lookup for a new address completes.
    private func resolveLocations(for status: VPNStatus) {
        guard settings.showIPLocations, !ScreenshotDemo.isEnabled else { return }
        let addresses = [status.wanIP, status.state == .connected ? status.vpnEndpointIP : nil]
            .compactMap { IPLocationResolver.normalizedIPAddress($0) }
            .filter { locationLabels[$0] == nil }

        for address in addresses {
            Task { [weak self] in
                guard let location = await IPLocationResolver.shared.location(for: address) else { return }
                guard let self else { return }
                self.locationLabels[address] = location
                if let lastStatus = self.lastStatus, lastStatus.wanIP == address || lastStatus.vpnEndpointIP == address {
                    self.updateNetworkItems(for: self.displayStatus(lastStatus))
                }
            }
        }
    }

    private func displayStatus(_ status: VPNStatus) -> VPNStatus {
        guard settings.showIPLocations else { return status }
        var status = status
        if let wanIP = status.wanIP, let location = locationLabels[wanIP] {
            status.wanLocation = location
        }
        if let endpointIP = status.vpnEndpointIP, let location = locationLabels[endpointIP] {
            status.vpnLocation = location
        }
        return status
    }

    private func scheduleFollowUpRefreshIfNeeded(
        after state: VPNConnectionState,
        forcedDelay: TimeInterval? = nil
    ) {
        cancelFollowUpRefresh()

        guard let delay = forcedDelay ?? StatusRefreshPolicy.followUpRefreshDelay(after: state) else {
            return
        }
        scheduleFollowUpRefresh(after: delay)
    }

    private func scheduleFollowUpRefresh(after delay: TimeInterval) {
        cancelFollowUpRefresh()
        followUpRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.followUpRefreshTask = nil
            self?.refreshStatus()
        }
    }

    private func cancelFollowUpRefresh() {
        followUpRefreshTask?.cancel()
        followUpRefreshTask = nil
    }

    private func updateMenu(for status: VPNStatus, displayState: VPNConnectionState? = nil) {
        let resolvedDisplayState = displayState ?? status.state
        if StatusDisplayUpdatePolicy.shouldUpdateStatusDetails(previousStatus: lastStatus, nextStatus: status) {
            setStatusTitle(for: status)
            updateNetworkItems(for: displayStatus(status))
        }
        if StatusDisplayUpdatePolicy.shouldUpdateStateChrome(
            previousDisplayState: lastDisplayState,
            nextDisplayState: resolvedDisplayState,
            previousProfileName: lastToggleProfileName,
            nextProfileName: settings.profileName
        ) {
            updateToggleButton(for: resolvedDisplayState)
            statusItem.button?.image = IconFactory.menuBarIcon(state: resolvedDisplayState)
            statusItem.button?.toolTip = "ASUS Fusion VPN - \(resolvedDisplayState.displayName)"
            lastDisplayState = resolvedDisplayState
            lastToggleProfileName = settings.profileName
        }
    }

    private func refreshStatusMenuTitle() {
        guard let lastStatus else {
            return
        }

        setStatusTitle(for: lastStatus)
    }

    private func setStatusTitle(for status: VPNStatus) {
        statusMenuItem.attributedTitle = StatusMenuTitleFormatter.title(
            profileName: settings.profileName,
            regionName: selectedRegionDisplayName()
        )
    }

    private func refreshToggleButtonTitle() {
        updateToggleButton(for: lastDisplayState ?? lastStatus?.state ?? .unknown)
        lastToggleProfileName = settings.profileName
    }

    private func updateToggleButton(for state: VPNConnectionState) {
        switch state {
        case .connected:
            toggleMenuView.title = "Disconnect from \(settings.profileName)"
            toggleMenuView.setButtonAppearance(
                background: ToggleButtonAppearance.connectedBackground,
                titleColor: .white
            )
        case .connecting:
            toggleMenuView.title = "Connecting to \(settings.profileName)..."
            toggleMenuView.setButtonAppearance(
                background: ToggleButtonAppearance.workingBackground,
                border: ToggleButtonAppearance.disconnectedBorder,
                titleColor: .labelColor
            )
        case .disconnected, .unknown:
            toggleMenuView.title = "Connect to \(settings.profileName)"
            toggleMenuView.setButtonAppearance(
                background: ToggleButtonAppearance.disconnectedBackground,
                border: ToggleButtonAppearance.disconnectedBorder,
                titleColor: .labelColor
            )
        }
    }

    private func setPlainStatusTitle(_ title: String) {
        statusMenuItem.attributedTitle = StatusMenuTitleFormatter.plainTitle(title)
    }

    private func selectedRegionDisplayName() -> String {
        VPNRegionCatalog.region(
            matching: settings.selectedRegionEndpoint,
            in: regions
        )?.displayName ?? settings.selectedRegionEndpoint
    }

    private func refreshRegionCatalog() {
        Task { [weak self] in
            do {
                let fetchedRegions = try await VPNRegionStore.fetchRegions()
                await MainActor.run {
                    guard let self else { return }
                    VPNRegionStore.saveCachedRegions(fetchedRegions)
                    self.regions = VPNRegionStore.combinedRegions(
                        catalogRegions: fetchedRegions,
                        selectedRegion: self.settings.selectedRegion
                    )
                    self.syncSelectedRegionPublicKey()
                    self.refreshStatusMenuTitle()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.refreshStatusMenuTitle()
                }
            }
        }
    }

    private func syncSelectedRegionPublicKey() {
        guard
            let selectedRegion = VPNRegionCatalog.region(matching: settings.selectedRegionEndpoint, in: regions),
            selectedRegion.publicKey != settings.selectedRegionPublicKey
        else {
            return
        }

        settings.selectedRegionPublicKey = selectedRegion.publicKey
        settings.saveNonSecretSettings()
    }

    private func updateNetworkItems(for status: VPNStatus?) {
        wanIPMenuItem.title = "Internet IP: \(status?.wanIP ?? "Unavailable")"
        wanLocationMenuItem.title = "Internet Location: \(status?.wanLocation ?? "Unavailable")"

        if status?.state == .connected {
            vpnTunnelIPMenuItem.title = "VPN Tunnel IP: \(status?.vpnTunnelIP ?? "Unavailable")"
            vpnExitIPMenuItem.title = "VPN Exit IP: \(status?.vpnEndpointIP ?? "Unavailable")"
            vpnLocationMenuItem.title = "VPN Location: \(status?.vpnLocation ?? "Unavailable")"
        } else {
            vpnTunnelIPMenuItem.title = "VPN Tunnel IP: Not connected"
            vpnExitIPMenuItem.title = "VPN Exit IP: Not connected"
            vpnLocationMenuItem.title = "VPN Location: Not connected"
        }

        routerCPUMenuItem.title = "Router CPU: \(formatRouterCPU(status?.routerCPUPercent))"
        routerMemoryMenuItem.title = "Router Memory: \(formatRouterMemory(status))"
    }

    private func formatRouterCPU(_ percent: Int?) -> String {
        guard let percent else {
            return "Unavailable"
        }

        return "\(clampedPercent(percent))%"
    }

    private func formatRouterMemory(_ status: VPNStatus?) -> String {
        guard
            let usedMB = status?.routerMemoryUsedMB,
            let totalMB = status?.routerMemoryTotalMB
        else {
            if let percent = status?.routerMemoryPercent {
                return "\(clampedPercent(percent))%"
            }
            return "Unavailable"
        }

        if let percent = status?.routerMemoryPercent {
            return "\(usedMB) MB / \(totalMB) MB (\(clampedPercent(percent))%)"
        }
        return "\(usedMB) MB / \(totalMB) MB"
    }

    private func clampedPercent(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "ASUS Fusion VPN"
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate()
        alert.runModal()
    }
}
