//
//  NetworkDiagnosisStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Combine
import Foundation

@MainActor
final class NetworkDiagnosisStore: ObservableObject {

    static let defaultTarget = NetworkDiagnosisTarget.cloudflare

    private enum Keys {
        static let recentResults = "cn.tpshion.vm-net.network-diagnosis-recent-results"
        static let target = "cn.tpshion.vm-net.network-diagnosis-target"
        static let legacyTargetInput = "cn.tpshion.vm-net.network-diagnosis-target-input"
    }

    private enum Constants {
        static let maxRecentResults = 8
    }

    @Published private(set) var snapshot: NetworkDiagnosisSnapshot
    @Published private(set) var recentResults: [NetworkDiagnosisResult]
    @Published var selectedTarget: NetworkDiagnosisTarget {
        didSet {
            defaults.set(selectedTarget.rawValue, forKey: Keys.target)
            syncTargetHost()
        }
    }

    private let service: NetworkDiagnosisService
    private let defaults: UserDefaults
    private var runningTask: Task<Void, Never>?

    init(
        service: NetworkDiagnosisService = NetworkDiagnosisService(),
        defaults: UserDefaults = .standard
    ) {
        let recentResults = Self.loadRecentResults(from: defaults)
        let selectedTarget = Self.loadSelectedTarget(from: defaults)

        self.service = service
        self.defaults = defaults
        self.recentResults = recentResults
        self.selectedTarget = selectedTarget
        self.snapshot = NetworkDiagnosisSnapshot(
            phase: .idle,
            statusMessage: "手动发起一次网络诊断。",
            targetHost: selectedTarget.host,
            checks: [],
            lastResult: recentResults.first,
            lastUpdatedAt: recentResults.first?.finishedAt,
            errorMessage: nil
        )

        // The diagnosis target is now a fixed preset list, so stale free-form
        // input from older builds should not override the new default.
        if defaults.string(forKey: Keys.target) != selectedTarget.rawValue {
            defaults.set(selectedTarget.rawValue, forKey: Keys.target)
        }
        defaults.removeObject(forKey: Keys.legacyTargetInput)
    }

    func startDiagnosis() {
        guard runningTask == nil else { return }

        snapshot = NetworkDiagnosisSnapshot(
            phase: .checkingPath,
            statusMessage: "正在准备网络诊断…",
            targetHost: selectedTarget.host,
            checks: [],
            lastResult: snapshot.lastResult,
            lastUpdatedAt: Date(),
            errorMessage: nil
        )

        runningTask = Task { [weak self] in
            guard let self else { return }

            do {
                let target = selectedTarget.host
                let result = try await service.run(target: target) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.apply(progress)
                    }
                }

                snapshot = NetworkDiagnosisSnapshot(
                    phase: result.overallStatus == .failure ? .failed : .completed,
                    statusMessage: result.headline,
                    targetHost: result.targetHost,
                    checks: result.checks,
                    lastResult: result,
                    lastUpdatedAt: result.finishedAt,
                    errorMessage: nil
                )
                appendRecentResult(result)
            } catch is CancellationError {
                snapshot = NetworkDiagnosisSnapshot(
                    phase: .cancelled,
                    statusMessage: "网络诊断已取消",
                    targetHost: snapshot.targetHost,
                    checks: snapshot.checks,
                    lastResult: snapshot.lastResult,
                    lastUpdatedAt: Date(),
                    errorMessage: nil
                )
            } catch {
                snapshot = NetworkDiagnosisSnapshot(
                    phase: .failed,
                    statusMessage: "网络诊断失败",
                    targetHost: snapshot.targetHost,
                    checks: snapshot.checks,
                    lastResult: snapshot.lastResult,
                    lastUpdatedAt: Date(),
                    errorMessage: error.localizedDescription
                )
            }

            runningTask = nil
        }
    }

    func cancelDiagnosis() {
        guard runningTask != nil else { return }
        runningTask?.cancel()
    }

    func resetTarget() {
        selectedTarget = Self.defaultTarget
    }

    private func apply(_ progress: NetworkDiagnosisService.Progress) {
        snapshot = NetworkDiagnosisSnapshot(
            phase: progress.phase,
            statusMessage: progress.statusMessage,
            targetHost: progress.targetHost,
            checks: progress.checks,
            lastResult: snapshot.lastResult,
            lastUpdatedAt: progress.updatedAt,
            errorMessage: nil
        )
    }

    private func appendRecentResult(_ result: NetworkDiagnosisResult) {
        recentResults.insert(result, at: 0)
        if recentResults.count > Constants.maxRecentResults {
            recentResults = Array(recentResults.prefix(Constants.maxRecentResults))
        }

        guard
            let data = try? JSONEncoder().encode(recentResults)
        else {
            defaults.removeObject(forKey: Keys.recentResults)
            return
        }

        defaults.set(data, forKey: Keys.recentResults)
    }

    private static func loadRecentResults(from defaults: UserDefaults) -> [NetworkDiagnosisResult] {
        guard
            let data = defaults.data(forKey: Keys.recentResults),
            let results = try? JSONDecoder().decode([NetworkDiagnosisResult].self, from: data)
        else {
            return []
        }

        return results.sorted { $0.finishedAt > $1.finishedAt }
    }

    private static func loadSelectedTarget(from defaults: UserDefaults) -> NetworkDiagnosisTarget {
        if let stored = defaults.string(forKey: Keys.target),
           let target = NetworkDiagnosisTarget(rawValue: stored) {
            return target
        }

        return defaultTarget
    }

    private func syncTargetHost() {
        guard !snapshot.isRunning else { return }

        snapshot = NetworkDiagnosisSnapshot(
            phase: snapshot.phase,
            statusMessage: snapshot.statusMessage,
            targetHost: selectedTarget.host,
            checks: snapshot.checks,
            lastResult: snapshot.lastResult,
            lastUpdatedAt: snapshot.lastUpdatedAt,
            errorMessage: snapshot.errorMessage
        )
    }
}
