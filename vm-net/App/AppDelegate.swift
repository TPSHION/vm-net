//
//  AppDelegate.swift
//  vm-net
//
//  Created by chen on 2025/4/4.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let preferences = AppPreferences()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private var statusItemController: StatusItemController?
    private lazy var configurationWindowController = ConfigurationWindowController(
        preferences: preferences,
        launchAtLoginManager: launchAtLoginManager
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItemController = StatusItemController(preferences: preferences)
        statusItemController.openWindowHandler = { [weak self] in
            self?.showMainWindow()
        }

        self.statusItemController = statusItemController

        if !LaunchAtLoginManager.wasLaunchedAtLogin {
            showMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController = nil
    }

    func showMainWindow() {
        launchAtLoginManager.refresh()
        configurationWindowController.present()
    }
}
