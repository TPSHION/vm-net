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
        static let statusItemWidth: CGFloat = 94
    }

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let contentView = StatusItemContentView()
    private let formatter = ByteRateFormatter()
    private let networkMonitor: NetworkMonitor

    init(networkMonitor: NetworkMonitor = NetworkMonitor()) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: Layout.statusItemWidth
        )
        self.networkMonitor = networkMonitor

        configureMenu()
        configureButton()
        render(.zero)

        self.networkMonitor.updateHandler = { [weak self] throughput in
            self?.render(throughput)
        }
        self.networkMonitor.startMonitoring()
    }

    deinit {
        networkMonitor.stopMonitoring()
    }

    private func configureMenu() {
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

    private func render(_ throughput: NetworkThroughput) {
        contentView.render(
            uploadText: "\(formatter.string(for: throughput.uploadBytesPerSecond)) ↑",
            downloadText:
                "\(formatter.string(for: throughput.downloadBytesPerSecond)) ↓"
        )
    }
}
