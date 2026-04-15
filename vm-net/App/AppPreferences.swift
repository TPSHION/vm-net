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

enum ThroughputDisplayMode: String, CaseIterable, Identifiable {
    case smoothed
    case realtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smoothed:
            return "平滑显示"
        case .realtime:
            return "实时显示"
        }
    }

    var summary: String {
        switch self {
        case .smoothed:
            return "减小跳动，更适合常驻查看。"
        case .realtime:
            return "直接显示瞬时速率，响应更快。"
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
        static let displayMode = "cn.tpshion.vm-net.display-mode"
        static let showInFloatingBall = "cn.tpshion.vm-net.show-in-floating-ball"
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
        static let floatingBallScreenIdentifier =
            "cn.tpshion.vm-net.floating-ball-screen-identifier"
    }

    private let defaults: UserDefaults

    @Published var displayMode: ThroughputDisplayMode {
        didSet {
            defaults.set(displayMode.rawValue, forKey: Keys.displayMode)
        }
    }

    @Published var showInFloatingBall: Bool {
        didSet {
            defaults.set(showInFloatingBall, forKey: Keys.showInFloatingBall)
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

    var floatingBallOrigin: CGPoint? {
        guard let floatingBallOriginX, let floatingBallOriginY else {
            return nil
        }

        return CGPoint(x: floatingBallOriginX, y: floatingBallOriginY)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedShowInFloatingBall =
            defaults.object(forKey: Keys.showInFloatingBall) as? Bool ?? false

        self.displayMode = ThroughputDisplayMode(
            rawValue: defaults.string(forKey: Keys.displayMode) ?? ""
        ) ?? .smoothed
        self.showInFloatingBall = storedShowInFloatingBall
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
        self.floatingBallScreenIdentifier = defaults.string(
            forKey: Keys.floatingBallScreenIdentifier
        )
    }

    func setFloatingBallPlacement(
        origin: CGPoint?,
        screenIdentifier: String?
    ) {
        floatingBallOriginX = origin.map { Double($0.x) }
        floatingBallOriginY = origin.map { Double($0.y) }
        floatingBallScreenIdentifier = screenIdentifier
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
