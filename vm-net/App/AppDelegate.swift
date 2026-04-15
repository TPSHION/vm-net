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
    private var desktopPetController: DesktopPetController?
    private lazy var configurationWindowController = ConfigurationWindowController(
        preferences: preferences,
        launchAtLoginManager: launchAtLoginManager,
        speedTestStore: speedTestStore,
        diagnosisStore: diagnosisStore,
        onFloatingBallToggle: { [weak self] isEnabled in
            self?.setFloatingBallEnabled(isEnabled)
        },
        onDesktopPetToggle: { [weak self] isEnabled in
            self?.setDesktopPetEnabled(isEnabled)
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureStatusItemController()
        if preferences.showInFloatingBall {
            ensureFloatingBallController()
        }
        refreshDesktopPetVisibility()

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
        desktopPetController?.hide()
        desktopPetController = nil
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

        refreshDesktopPetVisibility()
    }

    private func setDesktopPetEnabled(_ isEnabled: Bool) {
        if isEnabled {
            refreshDesktopPetVisibility()
        } else {
            desktopPetController?.hide()
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
        floatingBallController.frameChangeHandler = { [weak self] frame, screen in
            self?.updateDesktopPetAttachment(anchorFrame: frame, screen: screen)
        }
        floatingBallController.show()

        self.floatingBallController = floatingBallController
    }

    private func refreshDesktopPetVisibility() {
        guard preferences.showDesktopPet, preferences.showInFloatingBall else {
            desktopPetController?.hide()
            return
        }

        guard
            let floatingBallController,
            let anchorFrame = floatingBallController.currentFrame
        else {
            return
        }

        let desktopPetController = ensureDesktopPetController()
        desktopPetController.show(
            attachedTo: anchorFrame,
            on: floatingBallController.currentScreen
        )
    }

    private func ensureDesktopPetController() -> DesktopPetController {
        if let desktopPetController {
            return desktopPetController
        }

        let desktopPetController = DesktopPetController()
        self.desktopPetController = desktopPetController
        return desktopPetController
    }

    private func updateDesktopPetAttachment(
        anchorFrame: CGRect,
        screen: NSScreen?
    ) {
        guard preferences.showDesktopPet, preferences.showInFloatingBall else {
            desktopPetController?.hide()
            return
        }

        ensureDesktopPetController().show(
            attachedTo: anchorFrame,
            on: screen
        )
    }
}
