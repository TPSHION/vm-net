//
//  AppPreferences.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Combine
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
            return "减小跳动，更适合常驻状态栏查看。"
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

    private enum Keys {
        static let displayMode = "cn.tpshion.vm-net.display-mode"
    }

    private let defaults: UserDefaults

    @Published var displayMode: ThroughputDisplayMode {
        didSet {
            defaults.set(displayMode.rawValue, forKey: Keys.displayMode)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.displayMode = ThroughputDisplayMode(
            rawValue: defaults.string(forKey: Keys.displayMode) ?? ""
        ) ?? .smoothed
    }
}
