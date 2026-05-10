import AppKit

private enum RouterTaskResult: Sendable {
    case success(VPNStatus)
    case failure(String)
}

@MainActor
final class MenuBarController: NSObject {
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
    private let toggleMenuItem = NSMenuItem(title: "Connect", action: #selector(toggleVPN), keyEquivalent: "")
    private let refreshMenuItem = NSMenuItem(title: "Refresh Status", action: #selector(refreshStatus), keyEquivalent: "r")
    private var settingsWindowController: SettingsWindowController?
    private var timer: Timer?
    private var settings = AppSettings.load()
    private var regions: [VPNRegion] = []
    private var lastStatus: VPNStatus?
    private var isBusy = false
    private var pendingFollowUpRefresh: DispatchWorkItem?

    override init() {
        super.init()
        regions = VPNRegionStore.initialRegions(settings: settings)
        configureStatusItem()
        configureMenu()
        refreshRegionCatalog()
        refreshStatus()

        let refreshTimer = Timer(timeInterval: StatusRefreshPolicy.regularRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus()
            }
        }
        timer = refreshTimer
        RunLoop.main.add(refreshTimer, forMode: StatusRefreshPolicy.regularRefreshRunLoopMode)
    }

    private func configureStatusItem() {
        statusItem.button?.image = IconFactory.menuBarIcon(state: .unknown)
        statusItem.button?.toolTip = "ASUS Fusion VPN"
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.autoenablesItems = false
        toggleMenuItem.target = self
        refreshMenuItem.target = self
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

        let routerItem = NSMenuItem(title: "Open Router VPN Page", action: #selector(openRouterPage), keyEquivalent: "")
        routerItem.target = self

        let quitItem = NSMenuItem(title: "Quit ASUS Fusion VPN", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

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
        menu.addItem(toggleMenuItem)
        menu.addItem(refreshMenuItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(routerItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    @objc private func refreshStatus() {
        runRouterTask(busyTitle: "Status: Checking...") { client in
            try client.status()
        }
    }

    @objc private func toggleVPN() {
        let shouldConnect = lastStatus?.state != .connected
        runRouterTask(busyTitle: shouldConnect ? "Status: Connecting..." : "Status: Disconnecting...") { client in
            try client.setEnabled(shouldConnect)
        }
    }

    private func reconnectVPNForRegionChange() {
        runRouterTask(busyTitle: "Status: Switching Region...") { client in
            _ = try client.setEnabled(false)
            return try client.setEnabled(true)
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

            self.settings = newSettings
            self.regions = VPNRegionStore.initialRegions(settings: newSettings)
            self.refreshStatusMenuTitle()

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

    private func runRouterTask(busyTitle: String, task: @Sendable @escaping (SSHRouterClient) throws -> VPNStatus) {
        guard !isBusy else { return }
        cancelFollowUpRefresh()
        isBusy = true
        setPlainStatusTitle(busyTitle)
        toggleMenuItem.isEnabled = false
        refreshMenuItem.isEnabled = false
        statusItem.button?.image = IconFactory.menuBarIcon(state: .connecting)

        let currentSettings = settings

        DispatchQueue.global(qos: .userInitiated).async {
            let result: RouterTaskResult
            do {
                result = .success(try task(SSHRouterClient(settings: currentSettings)))
            } catch {
                result = .failure(error.localizedDescription)
            }

            Task { @MainActor [weak self] in
                self?.handle(result: result)
            }
        }
    }

    private func handle(result: RouterTaskResult) {
        isBusy = false
        toggleMenuItem.isEnabled = true
        refreshMenuItem.isEnabled = true

        switch result {
        case .success(let status):
            lastStatus = status
            updateMenu(for: status)
            scheduleFollowUpRefreshIfNeeded(after: status.state)
        case .failure(let message):
            cancelFollowUpRefresh()
            lastStatus = nil
            setPlainStatusTitle("Status: Error")
            updateNetworkItems(for: nil)
            toggleMenuItem.title = "Connect"
            statusItem.button?.image = IconFactory.menuBarIcon(state: .unknown)
            showError(message)
        }
    }

    private func scheduleFollowUpRefreshIfNeeded(after state: VPNConnectionState) {
        cancelFollowUpRefresh()

        guard let delay = StatusRefreshPolicy.followUpRefreshDelay(after: state) else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshStatus()
            }
        }
        pendingFollowUpRefresh = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelFollowUpRefresh() {
        pendingFollowUpRefresh?.cancel()
        pendingFollowUpRefresh = nil
    }

    private func updateMenu(for status: VPNStatus) {
        setStatusTitle(for: status)
        updateNetworkItems(for: status)
        toggleMenuItem.title = status.state == .connected ? "Disconnect \(settings.profileName)" : "Connect \(settings.profileName)"
        statusItem.button?.image = IconFactory.menuBarIcon(state: status.state)
        statusItem.button?.toolTip = "ASUS Fusion VPN - \(status.state.displayName)"
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
            state: status.state,
            regionName: selectedRegionDisplayName(),
            vpnTunnelIP: status.state == .connected ? status.vpnTunnelIP : nil
        )
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
                    self.regions = fetchedRegions
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
        alert.runModal()
    }
}
