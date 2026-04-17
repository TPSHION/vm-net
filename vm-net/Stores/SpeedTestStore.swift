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
            statusMessage: L10n.tr("speedTest.snapshot.idleStatus"),
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
            statusMessage: L10n.tr("speedTest.store.locatingServer"),
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
                    statusMessage: L10n.tr("speedTest.store.completed"),
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
                    statusMessage: L10n.tr("speedTest.store.cancelled"),
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
                    statusMessage: L10n.tr("speedTest.store.failed"),
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

    func reloadLocalization() {
        let localizedStatusMessage: String

        switch snapshot.phase {
        case .idle:
            localizedStatusMessage = L10n.tr("speedTest.snapshot.idleStatus")
        case .completed:
            localizedStatusMessage = L10n.tr("speedTest.store.completed")
        case .failed:
            localizedStatusMessage = L10n.tr("speedTest.store.failed")
        case .cancelled:
            localizedStatusMessage = L10n.tr("speedTest.store.cancelled")
        case .locatingServer, .measuringDownload, .measuringUpload:
            return
        }

        snapshot = SpeedTestSnapshot(
            phase: snapshot.phase,
            statusMessage: localizedStatusMessage,
            serverName: snapshot.serverName,
            latencyMilliseconds: snapshot.latencyMilliseconds,
            downloadMbps: snapshot.downloadMbps,
            uploadMbps: snapshot.uploadMbps,
            lastResult: snapshot.lastResult,
            lastUpdatedAt: snapshot.lastUpdatedAt,
            errorMessage: snapshot.errorMessage
        )
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
