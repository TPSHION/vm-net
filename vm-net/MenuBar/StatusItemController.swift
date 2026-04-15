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
    private let interfaceItem = NSMenuItem()
    private let uploadItem = NSMenuItem()
    private let downloadItem = NSMenuItem()
    private let updatedAtItem = NSMenuItem()

    init(networkMonitor: NetworkMonitor = NetworkMonitor()) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: Layout.statusItemWidth
        )
        self.networkMonitor = networkMonitor

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
        [interfaceItem, uploadItem, downloadItem, updatedAtItem].forEach {
            $0.isEnabled = false
            menu.addItem($0)
        }
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
        let displayed = snapshot.displayedThroughput

        contentView.render(
            uploadText:
                "\(formatter.string(for: displayed.uploadBytesPerSecond)) ↑",
            downloadText:
                "\(formatter.string(for: displayed.downloadBytesPerSecond)) ↓",
            isActive: displayed.isActive
        )

        interfaceItem.title = snapshot.monitoredInterfaceName.map {
            "Interface: \($0)"
        } ?? "Interface: waiting for network"
        uploadItem.title =
            "Upload: \(formatter.string(for: displayed.uploadBytesPerSecond, style: .detailed))"
        downloadItem.title =
            "Download: \(formatter.string(for: displayed.downloadBytesPerSecond, style: .detailed))"
        updatedAtItem.title = snapshot.lastUpdatedAt.map {
            "Updated: \(Self.timeFormatter.string(from: $0))"
        } ?? "Updated: --"

        statusItem.button?.toolTip = snapshot.monitoredInterfaceName.map {
            "Monitoring \($0)"
        } ?? "Monitoring network throughput"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}
