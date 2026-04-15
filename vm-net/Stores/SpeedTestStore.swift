//
//  SpeedTestStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Combine
import Foundation

@MainActor
final class SpeedTestStore: ObservableObject {

    private enum Keys {
        static let recentResults = "cn.tpshion.vm-net.speed-test-recent-results"
    }

    private enum Constants {
        static let maxRecentResults = 6
    }

    @Published private(set) var snapshot: SpeedTestSnapshot = .idle
    @Published private(set) var recentResults: [SpeedTestResult]

    private let service: MLabSpeedTestService
    private let defaults: UserDefaults
    private var runningTask: Task<Void, Never>?

    init(
        service: MLabSpeedTestService = MLabSpeedTestService(),
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.defaults = defaults
        self.recentResults = Self.loadRecentResults(from: defaults)
        self.snapshot = SpeedTestSnapshot(
            phase: .idle,
            statusMessage: "手动发起一次网络测速。",
            serverName: nil,
            latencyMilliseconds: nil,
            downloadMbps: nil,
            uploadMbps: nil,
            lastResult: recentResults.first,
            lastUpdatedAt: recentResults.first?.finishedAt,
            errorMessage: nil
        )
    }

    deinit {
        runningTask?.cancel()
        let service = service
        Task {
            await service.cancel()
        }
    }

    func startTest() {
        guard runningTask == nil else { return }

        snapshot = SpeedTestSnapshot(
            phase: .locatingServer,
            statusMessage: "正在选择 M-Lab 节点…",
            serverName: nil,
            latencyMilliseconds: nil,
            downloadMbps: nil,
            uploadMbps: nil,
            lastResult: snapshot.lastResult,
            lastUpdatedAt: Date(),
            errorMessage: nil
        )

        runningTask = Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await service.run { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.apply(progress)
                    }
                }

                snapshot = SpeedTestSnapshot(
                    phase: .completed,
                    statusMessage: "测速完成",
                    serverName: result.serverName,
                    latencyMilliseconds: result.latencyMilliseconds,
                    downloadMbps: result.downloadMbps,
                    uploadMbps: result.uploadMbps,
                    lastResult: result,
                    lastUpdatedAt: result.finishedAt,
                    errorMessage: nil
                )
                appendRecentResult(result)
            } catch is CancellationError {
                snapshot = SpeedTestSnapshot(
                    phase: .cancelled,
                    statusMessage: "测速已取消",
                    serverName: snapshot.serverName,
                    latencyMilliseconds: snapshot.latencyMilliseconds,
                    downloadMbps: snapshot.downloadMbps,
                    uploadMbps: snapshot.uploadMbps,
                    lastResult: snapshot.lastResult,
                    lastUpdatedAt: Date(),
                    errorMessage: nil
                )
            } catch {
                snapshot = SpeedTestSnapshot(
                    phase: .failed,
                    statusMessage: "测速失败",
                    serverName: snapshot.serverName,
                    latencyMilliseconds: snapshot.latencyMilliseconds,
                    downloadMbps: snapshot.downloadMbps,
                    uploadMbps: snapshot.uploadMbps,
                    lastResult: snapshot.lastResult,
                    lastUpdatedAt: Date(),
                    errorMessage: error.localizedDescription
                )
            }

            runningTask = nil
        }
    }

    func cancelTest() {
        guard runningTask != nil else { return }

        runningTask?.cancel()
        Task {
            await service.cancel()
        }
    }

    private func apply(_ progress: MLabSpeedTestService.Progress) {
        snapshot = SpeedTestSnapshot(
            phase: progress.phase,
            statusMessage: progress.statusMessage,
            serverName: progress.serverName,
            latencyMilliseconds: progress.latencyMilliseconds,
            downloadMbps: progress.downloadMbps,
            uploadMbps: progress.uploadMbps,
            lastResult: snapshot.lastResult,
            lastUpdatedAt: progress.updatedAt,
            errorMessage: nil
        )
    }

    private func appendRecentResult(_ result: SpeedTestResult) {
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

    private static func loadRecentResults(from defaults: UserDefaults) -> [SpeedTestResult] {
        guard
            let data = defaults.data(forKey: Keys.recentResults),
            let results = try? JSONDecoder().decode([SpeedTestResult].self, from: data)
        else {
            return []
        }

        return results.sorted { $0.finishedAt > $1.finishedAt }
    }
}
