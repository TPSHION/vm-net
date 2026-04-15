//
//  StatusItemController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

@MainActor
final class StatusItemController {

    private enum Layout {
        static let statusItemWidth: CGFloat = 68
    }

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let contentView = StatusItemContentView()
    private let formatter = ByteRateFormatter()
    private let networkMonitor: NetworkMonitor
    private let preferences: AppPreferences
    private let openWindowItem = NSMenuItem()

    var openWindowHandler: (() -> Void)?

    init(
        networkMonitor: NetworkMonitor = NetworkMonitor(),
        preferences: AppPreferences
    ) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: Layout.statusItemWidth
        )
        self.networkMonitor = networkMonitor
        self.preferences = preferences

        configureMenu()
        configureButton()
        render(.idle)

        self.networkMonitor.updateHandler = { [weak self] snapshot in
            self?.render(snapshot)
        }
        self.networkMonitor.startMonitoring()
    }

    deinit {
        networkMonitor.stopMonitoring()
    }

    private func configureMenu() {
        openWindowItem.title = "Open vm-net"
        openWindowItem.action = #selector(handleOpenWindow)
        openWindowItem.target = self
        menu.addItem(openWindowItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.title = ""
        button.image = nil
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: button.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
    }

    private func render(_ snapshot: NetworkMonitorSnapshot) {
        let displayed = preferences.displayMode.throughput(from: snapshot)

        contentView.render(
            uploadText:
                "\(formatter.string(for: displayed.uploadBytesPerSecond)) ↑",
            downloadText:
                "\(formatter.string(for: displayed.downloadBytesPerSecond)) ↓",
            isActive: displayed.isActive
        )

        statusItem.button?.toolTip = snapshot.monitoredInterfaceName.map {
            "Monitoring \($0)"
        } ?? "Monitoring network throughput"
    }

    @objc
    private func handleOpenWindow() {
        openWindowHandler?()
    }
}
