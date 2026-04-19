//
//  AppPreferences.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return L10n.tr("language.system")
        case .english:
            return L10n.tr("language.english")
        case .simplifiedChinese:
            return L10n.tr("language.simplifiedChinese")
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }

    var localizationIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
}

enum ThroughputDisplayMode: String, CaseIterable, Identifiable {
    case smoothed
    case realtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smoothed:
            return L10n.tr("displayMode.smoothed.title")
        case .realtime:
            return L10n.tr("displayMode.realtime.title")
        }
    }

    var summary: String {
        switch self {
        case .smoothed:
            return L10n.tr("displayMode.smoothed.summary")
        case .realtime:
            return L10n.tr("displayMode.realtime.summary")
        }
    }

    func throughput(from snapshot: NetworkMonitorSnapshot) -> NetworkThroughput {
        switch self {
        case .smoothed:
            return snapshot.displayedThroughput
        case .realtime:
            return snapshot.instantaneousThroughput
        }
    }
}

@MainActor
final class AppPreferences: ObservableObject {

    static var defaultFloatingBallBackgroundColor: NSColor {
        normalizedColor(
            NSColor(
                calibratedRed: 0,
                green: 0,
                blue: 0,
                alpha: 1
            )
        )
    }

    static var defaultFloatingBallTextColor: NSColor {
        .white
    }

    static let defaultFloatingBallBackgroundTransparency = 0.08

    private enum Keys {
        static let appLanguage = "cn.tpshion.vm-net.app-language"
        static let displayMode = "cn.tpshion.vm-net.display-mode"
        static let screenshotShortcutKeyCode =
            "cn.tpshion.vm-net.screenshot-shortcut-key-code"
        static let screenshotShortcutModifierFlags =
            "cn.tpshion.vm-net.screenshot-shortcut-modifier-flags"
        static let showInFloatingBall = "cn.tpshion.vm-net.show-in-floating-ball"
        static let showDesktopPet = "cn.tpshion.vm-net.show-desktop-pet"
        static let desktopPetAllowsRoaming =
            "cn.tpshion.vm-net.desktop-pet-allows-roaming"
        static let desktopPetAssetID = "cn.tpshion.vm-net.desktop-pet-asset-id"
        static let floatingBallBackgroundColor =
            "cn.tpshion.vm-net.floating-ball-background-color"
        static let floatingBallTextColor =
            "cn.tpshion.vm-net.floating-ball-text-color"
        static let floatingBallBackgroundTransparency =
            "cn.tpshion.vm-net.floating-ball-background-transparency"
        static let legacyFloatingBallBackgroundStyle =
            "cn.tpshion.vm-net.floating-ball-background-style"
        static let legacyFloatingBallBackgroundOpacity =
            "cn.tpshion.vm-net.floating-ball-background-opacity"
        static let floatingBallOriginX = "cn.tpshion.vm-net.floating-ball-origin-x"
        static let floatingBallOriginY = "cn.tpshion.vm-net.floating-ball-origin-y"
        static let floatingBallNormalizedOriginX =
            "cn.tpshion.vm-net.floating-ball-normalized-origin-x"
        static let floatingBallNormalizedOriginY =
            "cn.tpshion.vm-net.floating-ball-normalized-origin-y"
        static let floatingBallScreenIdentifier =
            "cn.tpshion.vm-net.floating-ball-screen-identifier"
        static let desktopPetRelativeHomeOffsets =
            "cn.tpshion.vm-net.desktop-pet-relative-home-offsets"
        static let activityAlertsEnabled = "cn.tpshion.vm-net.activity-alerts-enabled"
        static let activityAlertsEnableSystemNotifications =
            "cn.tpshion.vm-net.activity-alerts-system-notifications"
    }

    private let defaults: UserDefaults

    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            L10n.setLanguage(appLanguage)
        }
    }

    @Published var displayMode: ThroughputDisplayMode {
        didSet {
            defaults.set(displayMode.rawValue, forKey: Keys.displayMode)
        }
    }

    @Published var screenshotShortcut: KeyboardShortcut {
        didSet {
            defaults.set(
                Int(screenshotShortcut.keyCode),
                forKey: Keys.screenshotShortcutKeyCode
            )
            defaults.set(
                screenshotShortcut.modifiers.rawValue,
                forKey: Keys.screenshotShortcutModifierFlags
            )
        }
    }

    @Published var showInFloatingBall: Bool {
        didSet {
            defaults.set(showInFloatingBall, forKey: Keys.showInFloatingBall)
        }
    }

    @Published var showDesktopPet: Bool {
        didSet {
            defaults.set(showDesktopPet, forKey: Keys.showDesktopPet)
        }
    }

    @Published var desktopPetAllowsRoaming: Bool {
        didSet {
            defaults.set(
                desktopPetAllowsRoaming,
                forKey: Keys.desktopPetAllowsRoaming
            )
        }
    }

    @Published var desktopPetAssetID: DesktopPetAssetID {
        didSet {
            defaults.set(desktopPetAssetID.rawValue, forKey: Keys.desktopPetAssetID)
        }
    }

    @Published var floatingBallBackgroundColor: NSColor {
        didSet {
            persistColor(
                floatingBallBackgroundColor,
                forKey: Keys.floatingBallBackgroundColor
            )
        }
    }

    @Published var floatingBallTextColor: NSColor {
        didSet {
            persistColor(
                floatingBallTextColor,
                forKey: Keys.floatingBallTextColor
            )
        }
    }

    @Published var floatingBallBackgroundTransparency: Double {
        didSet {
            defaults.set(
                floatingBallBackgroundTransparency,
                forKey: Keys.floatingBallBackgroundTransparency
            )
        }
    }

    @Published private(set) var floatingBallOriginX: Double? {
        didSet {
            persistOptionalDouble(
                floatingBallOriginX,
                forKey: Keys.floatingBallOriginX
            )
        }
    }

    @Published private(set) var floatingBallOriginY: Double? {
        didSet {
            persistOptionalDouble(
                floatingBallOriginY,
                forKey: Keys.floatingBallOriginY
            )
        }
    }

    @Published private(set) var floatingBallScreenIdentifier: String? {
        didSet {
            persistOptionalString(
                floatingBallScreenIdentifier,
                forKey: Keys.floatingBallScreenIdentifier
            )
        }
    }

    @Published private(set) var floatingBallNormalizedOriginX: Double? {
        didSet {
            persistOptionalDouble(
                floatingBallNormalizedOriginX,
                forKey: Keys.floatingBallNormalizedOriginX
            )
        }
    }

    @Published private(set) var floatingBallNormalizedOriginY: Double? {
        didSet {
            persistOptionalDouble(
                floatingBallNormalizedOriginY,
                forKey: Keys.floatingBallNormalizedOriginY
            )
        }
    }

    @Published private(set) var desktopPetRelativeHomeOffsets: [String: [String: Double]] {
        didSet {
            defaults.set(
                desktopPetRelativeHomeOffsets,
                forKey: Keys.desktopPetRelativeHomeOffsets
            )
        }
    }

    @Published var activityAlertsEnabled: Bool {
        didSet {
            defaults.set(activityAlertsEnabled, forKey: Keys.activityAlertsEnabled)
        }
    }

    @Published var activityAlertsEnableSystemNotifications: Bool {
        didSet {
            defaults.set(
                activityAlertsEnableSystemNotifications,
                forKey: Keys.activityAlertsEnableSystemNotifications
            )
        }
    }

    var floatingBallOrigin: CGPoint? {
        guard let floatingBallOriginX, let floatingBallOriginY else {
            return nil
        }

        return CGPoint(x: floatingBallOriginX, y: floatingBallOriginY)
    }

    var floatingBallNormalizedOrigin: CGPoint? {
        guard let floatingBallNormalizedOriginX, let floatingBallNormalizedOriginY else {
            return nil
        }

        return CGPoint(
            x: floatingBallNormalizedOriginX,
            y: floatingBallNormalizedOriginY
        )
    }

    var desktopPetAsset: DesktopPetAsset {
        DesktopPetCatalog.asset(for: desktopPetAssetID)
    }

    var desktopPetDefinition: PetDefinition {
        PetDefinitionCatalog.definition(for: desktopPetAsset)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedShowInFloatingBall =
            defaults.object(forKey: Keys.showInFloatingBall) as? Bool ?? true
        let storedShowDesktopPet =
            defaults.object(forKey: Keys.showDesktopPet) as? Bool ?? true
        let storedDesktopPetAllowsRoaming =
            defaults.object(forKey: Keys.desktopPetAllowsRoaming) as? Bool ?? true

        self.appLanguage = AppLanguage(
            rawValue: defaults.string(forKey: Keys.appLanguage) ?? ""
        ) ?? .system
        self.displayMode = ThroughputDisplayMode(
            rawValue: defaults.string(forKey: Keys.displayMode) ?? ""
        ) ?? .realtime
        if
            let storedKeyCode = defaults.object(
                forKey: Keys.screenshotShortcutKeyCode
            ) as? Int,
            let storedModifierFlags = defaults.object(
                forKey: Keys.screenshotShortcutModifierFlags
            ) as? UInt
        {
            let shortcut = KeyboardShortcut(
                keyCode: UInt16(storedKeyCode),
                modifiers: NSEvent.ModifierFlags(rawValue: storedModifierFlags)
            )
            self.screenshotShortcut = shortcut.isValid
                ? shortcut
                : .defaultRegionScreenshot
        } else {
            self.screenshotShortcut = .defaultRegionScreenshot
        }
        self.showInFloatingBall = storedShowInFloatingBall
        self.showDesktopPet = storedShowDesktopPet
        self.desktopPetAllowsRoaming = storedDesktopPetAllowsRoaming
        self.desktopPetAssetID = DesktopPetAssetID(
            rawValue: defaults.string(forKey: Keys.desktopPetAssetID) ?? ""
        ) ?? DesktopPetCatalog.defaultAssetID
        self.floatingBallBackgroundColor = Self.loadBackgroundColor(from: defaults)
        self.floatingBallTextColor = Self.loadColor(
            from: defaults,
            forKey: Keys.floatingBallTextColor,
            default: Self.defaultFloatingBallTextColor
        )
        if let storedTransparency = defaults.object(
            forKey: Keys.floatingBallBackgroundTransparency
        ) as? Double {
            self.floatingBallBackgroundTransparency = storedTransparency
        } else if let legacyOpacity = defaults.object(
            forKey: Keys.legacyFloatingBallBackgroundOpacity
        ) as? Double {
            self.floatingBallBackgroundTransparency = max(
                0,
                min(0.6, 1 - legacyOpacity)
            )
        } else {
            self.floatingBallBackgroundTransparency =
                Self.defaultFloatingBallBackgroundTransparency
        }
        self.floatingBallOriginX = defaults.object(
            forKey: Keys.floatingBallOriginX
        ) as? Double
        self.floatingBallOriginY = defaults.object(
            forKey: Keys.floatingBallOriginY
        ) as? Double
        self.floatingBallNormalizedOriginX = defaults.object(
            forKey: Keys.floatingBallNormalizedOriginX
        ) as? Double
        self.floatingBallNormalizedOriginY = defaults.object(
            forKey: Keys.floatingBallNormalizedOriginY
        ) as? Double
        self.floatingBallScreenIdentifier = defaults.string(
            forKey: Keys.floatingBallScreenIdentifier
        )
        self.desktopPetRelativeHomeOffsets = defaults.dictionary(
            forKey: Keys.desktopPetRelativeHomeOffsets
        ) as? [String: [String: Double]] ?? [:]
        self.activityAlertsEnabled =
            defaults.object(forKey: Keys.activityAlertsEnabled) as? Bool ?? true
        self.activityAlertsEnableSystemNotifications =
            defaults.object(
                forKey: Keys.activityAlertsEnableSystemNotifications
            ) as? Bool ?? false
        L10n.setLanguage(appLanguage)
    }

    func setFloatingBallPlacement(
        origin: CGPoint?,
        normalizedOrigin: CGPoint?,
        screenIdentifier: String?
    ) {
        floatingBallOriginX = origin.map { Double($0.x) }
        floatingBallOriginY = origin.map { Double($0.y) }
        floatingBallNormalizedOriginX = normalizedOrigin.map { Double($0.x) }
        floatingBallNormalizedOriginY = normalizedOrigin.map { Double($0.y) }
        floatingBallScreenIdentifier = screenIdentifier
    }

    func desktopPetRelativeHomeOffset(
        for assetID: DesktopPetAssetID
    ) -> CGPoint? {
        guard
            let stored = desktopPetRelativeHomeOffsets[assetID.rawValue],
            let x = stored["x"],
            let y = stored["y"]
        else {
            return nil
        }

        return CGPoint(x: x, y: y)
    }

    func setDesktopPetRelativeHomeOffset(
        _ offset: CGPoint?,
        for assetID: DesktopPetAssetID
    ) {
        if let offset {
            desktopPetRelativeHomeOffsets[assetID.rawValue] = [
                "x": offset.x,
                "y": offset.y,
            ]
        } else {
            desktopPetRelativeHomeOffsets.removeValue(forKey: assetID.rawValue)
        }
    }

    func resetFloatingBallAppearance() {
        floatingBallBackgroundColor = Self.defaultFloatingBallBackgroundColor
        floatingBallTextColor = Self.defaultFloatingBallTextColor
        floatingBallBackgroundTransparency =
            Self.defaultFloatingBallBackgroundTransparency
    }

    private func persistOptionalDouble(_ value: Double?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func persistOptionalString(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func persistColor(_ color: NSColor, forKey key: String) {
        guard
            let data = try? NSKeyedArchiver.archivedData(
                withRootObject: Self.normalizedColor(color),
                requiringSecureCoding: true
            )
        else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private static func loadColor(
        from defaults: UserDefaults,
        forKey key: String,
        default defaultColor: NSColor
    ) -> NSColor {
        guard
            let data = defaults.data(forKey: key),
            let color = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSColor.self,
                from: data
            )
        else {
            return defaultColor
        }

        return normalizedColor(color)
    }

    private static func loadBackgroundColor(from defaults: UserDefaults) -> NSColor {
        if defaults.data(forKey: Keys.floatingBallBackgroundColor) != nil {
            return loadColor(
                from: defaults,
                forKey: Keys.floatingBallBackgroundColor,
                default: defaultFloatingBallBackgroundColor
            )
        }

        let legacyStyle = defaults.string(forKey: Keys.legacyFloatingBallBackgroundStyle)
        switch legacyStyle {
        case "matteBlack":
            return normalizedColor(
                NSColor(
                    calibratedRed: 0.14,
                    green: 0.14,
                    blue: 0.16,
                    alpha: 1
                )
            )
        case "polishedBlack", "glossyBlack":
            return normalizedColor(
                NSColor(
                    calibratedRed: 0.2,
                    green: 0.2,
                    blue: 0.22,
                    alpha: 1
                )
            )
        default:
            return defaultFloatingBallBackgroundColor
        }
    }

    private static func normalizedColor(_ color: NSColor) -> NSColor {
        color.usingColorSpace(.deviceRGB) ?? color
    }
}
