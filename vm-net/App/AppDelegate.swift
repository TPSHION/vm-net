//
//  AppDelegate.swift
//  vm-net
//
//  Created by chen on 2025/4/4.
//

import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let preferences = AppPreferences()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private let desktopPetAccessStore = DesktopPetAccessStore()
    private let configurationNavigationStore = ConfigurationNavigationStore()
    private let throughputStore = ThroughputStore()
    private let processTrafficStore = ProcessTrafficStore()
    private let speedTestStore = SpeedTestStore()
    private let diagnosisStore = NetworkDiagnosisStore()
    private var cancellables = Set<AnyCancellable>()
    private var statusItemController: StatusItemController?
    private var floatingBallController: FloatingBallController?
    private var petWorldController: PetWorldController?
    private lazy var configurationWindowController = ConfigurationWindowController(
        preferences: preferences,
        navigationStore: configurationNavigationStore,
        desktopPetAccessStore: desktopPetAccessStore,
        launchAtLoginManager: launchAtLoginManager,
        throughputStore: throughputStore,
        processTrafficStore: processTrafficStore,
        speedTestStore: speedTestStore,
        diagnosisStore: diagnosisStore,
        onFloatingBallToggle: { [weak self] isEnabled in
            self?.setFloatingBallEnabled(isEnabled)
        },
        onDesktopPetToggle: { [weak self] isEnabled in
            self?.setDesktopPetEnabled(isEnabled)
        },
        onDesktopPetRoamingToggle: { [weak self] isEnabled in
            self?.setDesktopPetRoamingEnabled(isEnabled)
        },
        onDesktopPetAssetApply: { [weak self] assetID in
            self?.applyDesktopPetAsset(assetID)
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        bindPreferences()
        ensureStatusItemController()
        refreshLocalization()
        Task { [weak self] in
            await self?.desktopPetAccessStore.prepare()
            self?.synchronizeDesktopPetAccess()
        }
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
        petWorldController?.hide()
        petWorldController = nil
    }

    func showMainWindow(page: ConfigurationPage = .settings) {
        configurationNavigationStore.show(page)
        launchAtLoginManager.refresh()
        refreshLocalization()
        Task { [weak self] in
            await self?.desktopPetAccessStore.prepare()
            self?.synchronizeDesktopPetAccess()
        }
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
        guard !isEnabled || desktopPetAccessStore.prepareForUse() else {
            preferences.showDesktopPet = false
            petWorldController?.hide()
            return
        }

        if isEnabled {
            refreshDesktopPetVisibility()
        } else {
            petWorldController?.hide()
        }
    }

    private func setDesktopPetRoamingEnabled(_ isEnabled: Bool) {
        petWorldController?.setRoamingEnabled(isEnabled)
        refreshDesktopPetVisibility()
    }

    private func applyDesktopPetAsset(_ assetID: DesktopPetAssetID) {
        guard preferences.desktopPetAssetID != assetID else {
            petWorldController?.applyAsset(preferences.desktopPetAsset)
            refreshDesktopPetVisibility()
            return
        }

        preferences.desktopPetAssetID = assetID
        let asset = preferences.desktopPetAsset
        petWorldController?.applyAsset(asset)
        refreshDesktopPetVisibility()
    }

    private func ensureStatusItemController() {
        guard statusItemController == nil else { return }

        let statusItemController = StatusItemController(
            store: throughputStore,
            preferences: preferences
        )
        statusItemController.openWindowHandler = { [weak self] in
            self?.showMainWindow(page: .settings)
        }
        statusItemController.openNetworkActivityHandler = { [weak self] in
            self?.showMainWindow(page: .activity)
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
            self?.showMainWindow(page: .settings)
        }
        floatingBallController.openNetworkActivityHandler = { [weak self] in
            self?.showMainWindow(page: .activity)
        }
        floatingBallController.frameChangeHandler = { [weak self] frame, screen in
            self?.updateDesktopPetAttachment(anchorFrame: frame, screen: screen)
        }
        floatingBallController.show()

        self.floatingBallController = floatingBallController
    }

    private func refreshDesktopPetVisibility() {
        guard
            desktopPetAccessStore.status.hasAccess,
            preferences.showDesktopPet,
            preferences.showInFloatingBall
        else {
            petWorldController?.hide()
            return
        }

        guard
            let floatingBallController,
            let anchorFrame = floatingBallController.currentFrame
        else {
            return
        }

        let petWorldController = ensurePetWorldController()
        petWorldController.show(
            homeAnchorFrame: anchorFrame,
            on: floatingBallController.currentScreen
        )
    }

    private func ensurePetWorldController() -> PetWorldController {
        if let petWorldController {
            petWorldController.applyAsset(preferences.desktopPetAsset)
            petWorldController.setRoamingEnabled(preferences.desktopPetAllowsRoaming)
            return petWorldController
        }

        let petWorldController = PetWorldController(
            preferences: preferences,
            asset: preferences.desktopPetAsset,
            isRoamingEnabled: preferences.desktopPetAllowsRoaming
        )
        self.petWorldController = petWorldController
        return petWorldController
    }

    private func updateDesktopPetAttachment(
        anchorFrame: CGRect,
        screen: NSScreen?
    ) {
        guard
            desktopPetAccessStore.status.hasAccess,
            preferences.showDesktopPet,
            preferences.showInFloatingBall
        else {
            petWorldController?.hide()
            return
        }

        ensurePetWorldController().show(
            homeAnchorFrame: anchorFrame,
            on: screen
        )
    }

    private func bindPreferences() {
        preferences.$desktopPetAssetID
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                self.petWorldController?.applyAsset(self.preferences.desktopPetAsset)
                self.refreshDesktopPetVisibility()
            }
            .store(in: &cancellables)

        preferences.$desktopPetAllowsRoaming
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }
                self.petWorldController?.setRoamingEnabled(isEnabled)
                self.refreshDesktopPetVisibility()
            }
            .store(in: &cancellables)

        preferences.$appLanguage
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                self.speedTestStore.reloadLocalization()
                self.diagnosisStore.reloadLocalization()
                self.processTrafficStore.reloadLocalization()
            }
            .store(in: &cancellables)

        desktopPetAccessStore.$status
            .dropFirst()
            .sink { [weak self] _ in
                self?.synchronizeDesktopPetAccess()
            }
            .store(in: &cancellables)
    }

    private func refreshLocalization() {
        speedTestStore.reloadLocalization()
        diagnosisStore.reloadLocalization()
    }

    private func synchronizeDesktopPetAccess() {
        guard desktopPetAccessStore.status.hasAccess else {
            if preferences.showDesktopPet {
                preferences.showDesktopPet = false
            }
            petWorldController?.hide()
            return
        }

        refreshDesktopPetVisibility()
    }
}
