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
    private let throughputStore = ThroughputStore()
    private let speedTestStore = SpeedTestStore()
    private let diagnosisStore = NetworkDiagnosisStore()
    private var statusItemController: StatusItemController?
    private var floatingBallController: FloatingBallController?
    private lazy var configurationWindowController = ConfigurationWindowController(
        preferences: preferences,
        launchAtLoginManager: launchAtLoginManager,
        speedTestStore: speedTestStore,
        diagnosisStore: diagnosisStore,
        onFloatingBallToggle: { [weak self] isEnabled in
            self?.setFloatingBallEnabled(isEnabled)
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureStatusItemController()
        if preferences.showInFloatingBall {
            ensureFloatingBallController()
        }

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
        statusItemController?.invalidate()
        statusItemController = nil
        floatingBallController?.hide()
        floatingBallController = nil
    }

    func showMainWindow() {
        launchAtLoginManager.refresh()
        configurationWindowController.present()
    }

    private func setFloatingBallEnabled(_ isEnabled: Bool) {
        if isEnabled {
            ensureFloatingBallController()
        } else {
            floatingBallController?.hide()
        }
    }

    private func ensureStatusItemController() {
        guard statusItemController == nil else { return }

        let statusItemController = StatusItemController(
            store: throughputStore,
            preferences: preferences
        )
        statusItemController.openWindowHandler = { [weak self] in
            self?.showMainWindow()
        }

        self.statusItemController = statusItemController
    }

    private func ensureFloatingBallController() {
        if let floatingBallController {
            floatingBallController.show()
            return
        }

        let floatingBallController = FloatingBallController(
            store: throughputStore,
            preferences: preferences
        )
        floatingBallController.openWindowHandler = { [weak self] in
            self?.showMainWindow()
        }
        floatingBallController.show()

        self.floatingBallController = floatingBallController
    }
}
