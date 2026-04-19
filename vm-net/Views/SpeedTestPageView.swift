//
//  SpeedTestPageView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import SwiftUI

struct SpeedTestPageView: View {

    @ObservedObject var store: SpeedTestStore
    let onBack: (() -> Void)? = nil

    private var snapshot: SpeedTestSnapshot {
        store.snapshot
    }

    private var recentResults: [SpeedTestResult] {
        store.recentResults
    }

    private var displayedStatusMessage: String {
        switch snapshot.phase {
        case .idle:
            return L10n.tr("speedTest.snapshot.idleStatus")
        case .cancelled:
            return L10n.tr("speedTest.store.cancelled")
        case .completed:
            return L10n.tr("speedTest.store.completed")
        case .failed:
            return L10n.tr("speedTest.store.failed")
        default:
            return snapshot.statusMessage
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerRow
            statusSection
            metricsSection
            historySection
            Spacer(minLength: 0)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Label(L10n.tr("navigation.backToSettings"), systemImage: "chevron.left")
                }
                .buttonStyle(.link)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("navigation.speedTest.title"))
                    .font(.system(size: 18, weight: .semibold))

                Text(L10n.tr("navigation.speedTest.subtitle"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if snapshot.isRunning {
                Button(L10n.tr("common.cancel")) {
                    store.cancelTest()
                }
                .controlSize(.small)
            } else {
                Button(L10n.tr("speedTest.start")) {
                    store.startTest()
                }
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
    }

    private var statusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 18) {
                    SpeedTestActivityView(snapshot: snapshot)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.phase.title)
                                .font(.system(size: 18, weight: .semibold))

                            Text(displayedStatusMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        if let serverName = snapshot.serverName {
                            Label(serverName, systemImage: "network")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        SpeedTestStageStrip(phase: snapshot.phase, snapshot: snapshot)
                    }

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.errorMessage ?? snapshot.phase.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text(L10n.tr("speedTest.disclaimer"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Link(
                            L10n.tr("speedTest.viewPolicy"),
                            destination: URL(string: "https://www.measurementlab.net/aup/")!
                        )
                        .font(.system(size: 12))
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("speedTest.currentStatus"))
        }
    }

    private var metricsSection: some View {
        let lastResult = snapshot.lastResult

        return GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    speedMetricCard(
                        title: L10n.tr("speedTest.metric.latency"),
                        value: SpeedTestFormatter.latencyString(
                            milliseconds: snapshot.latencyMilliseconds
                                ?? lastResult?.latencyMilliseconds
                        )
                    )
                    speedMetricCard(
                        title: L10n.tr("speedTest.metric.download"),
                        value: SpeedTestFormatter.throughputString(
                            mbps: snapshot.downloadMbps ?? lastResult?.downloadMbps
                        )
                    )
                    speedMetricCard(
                        title: L10n.tr("speedTest.metric.upload"),
                        value: SpeedTestFormatter.throughputString(
                            mbps: snapshot.uploadMbps ?? lastResult?.uploadMbps
                        )
                    )
                }

                if snapshot.isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else if let finishedAt = lastResult?.finishedAt {
                    Text(L10n.tr("speedTest.latestResultAt", SpeedTestFormatter.historyTimestampString(date: finishedAt)))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.tr("speedTest.noResult"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("speedTest.resultOverview"))
        }
    }

    private var historySection: some View {
        GroupBox {
            if recentResults.isEmpty {
                Text(L10n.tr("speedTest.history.empty"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(recentResults) { result in
                            historyCard(result)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .vmNetScrollBarsHidden()
                .frame(maxHeight: 220)
                .padding(8)
            }
        } label: {
            Text(L10n.tr("speedTest.recentResults"))
        }
    }

    private func historyCard(_ result: SpeedTestResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(SpeedTestFormatter.historyTimestampString(date: result.finishedAt))
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 12)

                Text(result.serverName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                historyMetricBadge(
                    title: L10n.tr("speedTest.metric.latency"),
                    value: SpeedTestFormatter.latencyString(
                        milliseconds: result.latencyMilliseconds
                    )
                )
                historyMetricBadge(
                    title: L10n.tr("speedTest.metric.download"),
                    value: SpeedTestFormatter.throughputString(mbps: result.downloadMbps)
                )
                historyMetricBadge(
                    title: L10n.tr("speedTest.metric.upload"),
                    value: SpeedTestFormatter.throughputString(mbps: result.uploadMbps)
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func speedMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func historyMetricBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.65))
        )
    }
}

private struct SpeedTestStageStrip: View {

    let phase: SpeedTestPhase
    let snapshot: SpeedTestSnapshot

    var body: some View {
        HStack(spacing: 10) {
            stageItem(title: L10n.tr("speedTest.stage.server"), state: stageState(for: .locatingServer))
            connector
            stageItem(title: L10n.tr("speedTest.metric.download"), state: stageState(for: .measuringDownload))
            connector
            stageItem(title: L10n.tr("speedTest.metric.upload"), state: stageState(for: .measuringUpload))
        }
    }

    private var connector: some View {
        Capsule()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 16, height: 2)
    }

    private func stageItem(title: String, state: StageState) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(state.textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(state.background)
        )
    }

    private func stageState(for stage: SpeedTestPhase) -> StageState {
        if phase == .idle {
            return .pending
        }

        let stageIndex = stageOrder(of: stage)
        let currentIndex = currentStageIndex

        if phase == .completed {
            return .completed
        }

        if phase == .failed {
            return stageIndex < currentIndex ? .completed : stageIndex == currentIndex ? .failed : .pending
        }

        if phase == .cancelled {
            return stageIndex < currentIndex ? .completed : stageIndex == currentIndex ? .cancelled : .pending
        }

        if stageIndex < currentIndex {
            return .completed
        }

        if stageIndex == currentIndex {
            return .current
        }

        return .pending
    }

    private var currentStageIndex: Int {
        switch phase {
        case .idle:
            return 0
        case .locatingServer:
            return 0
        case .measuringDownload:
            return 1
        case .measuringUpload:
            return 2
        case .completed:
            return 2
        case .failed, .cancelled:
            if snapshot.uploadMbps != nil {
                return 2
            }

            if snapshot.downloadMbps != nil {
                return 1
            }

            return 0
        }
    }

    private func stageOrder(of phase: SpeedTestPhase) -> Int {
        switch phase {
        case .locatingServer:
            return 0
        case .measuringDownload:
            return 1
        case .measuringUpload:
            return 2
        default:
            return 0
        }
    }

    private enum StageState {
        case pending
        case current
        case completed
        case failed
        case cancelled

        var tint: Color {
            switch self {
            case .pending:
                return .secondary.opacity(0.35)
            case .current:
                return Color.orange
            case .completed:
                return Color.green
            case .failed:
                return Color.red
            case .cancelled:
                return Color.yellow
            }
        }

        var background: Color {
            switch self {
            case .pending:
                return Color.primary.opacity(0.05)
            case .current:
                return Color.orange.opacity(0.14)
            case .completed:
                return Color.green.opacity(0.12)
            case .failed:
                return Color.red.opacity(0.12)
            case .cancelled:
                return Color.yellow.opacity(0.12)
            }
        }

        var textColor: Color {
            switch self {
            case .pending:
                return .secondary
            case .current:
                return Color.orange
            case .completed:
                return Color.green
            case .failed:
                return Color.red
            case .cancelled:
                return Color.yellow
            }
        }
    }
}

private struct SpeedTestActivityView: View {

    let snapshot: SpeedTestSnapshot

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !snapshot.isRunning)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let pulse = snapshot.isRunning ? (sin(time * 2.4) + 1) / 2 : 0.22
            let pulseScale = 0.92 + pulse * 0.12
            let rotation = snapshot.isRunning
                ? Angle(degrees: (time * 115).truncatingRemainder(dividingBy: 360))
                : .degrees(22)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.18),
                                Color(nsColor: .controlBackgroundColor).opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(accentColor.opacity(0.11))
                    .frame(width: 84, height: 84)
                    .scaleEffect(pulseScale)

                Circle()
                    .stroke(accentColor.opacity(snapshot.isRunning ? 0.18 : 0.08), lineWidth: 1)
                    .frame(width: 80, height: 80)
                    .scaleEffect(0.96 + pulse * 0.08)

                Circle()
                    .trim(from: 0.08, to: 0.34)
                    .stroke(
                        AngularGradient(
                            colors: [
                                accentColor.opacity(0.12),
                                accentColor,
                                accentColor.opacity(0.18)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 98, height: 98)
                    .rotationEffect(rotation)

                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
                    .offset(y: -49)
                    .rotationEffect(rotation)
                    .shadow(color: accentColor.opacity(0.5), radius: 10)

                VStack(spacing: 6) {
                    Image(systemName: snapshot.phase.symbolName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(accentColor)

                    Text(activityValue)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text(activityLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 132, height: 132)
    }

    private var activityLabel: String {
        switch snapshot.phase {
        case .measuringDownload:
            return L10n.tr("speedTest.activity.downloading")
        case .measuringUpload:
            return L10n.tr("speedTest.activity.uploading")
        case .completed:
            return L10n.tr("common.completed")
        case .failed:
            return L10n.tr("common.failed")
        case .cancelled:
            return L10n.tr("common.cancelled")
        case .locatingServer:
            return L10n.tr("speedTest.activity.locating")
        case .idle:
            return L10n.tr("common.pendingStart")
        }
    }

    private var activityValue: String {
        switch snapshot.phase {
        case .measuringDownload:
            return compactThroughput(snapshot.downloadMbps)
        case .measuringUpload:
            return compactThroughput(snapshot.uploadMbps)
        case .completed:
            return compactThroughput(snapshot.lastResult?.downloadMbps ?? snapshot.downloadMbps)
        case .failed, .cancelled:
            return L10n.tr("common.placeholder")
        case .locatingServer:
            return "M-Lab"
        case .idle:
            return L10n.tr("common.ready")
        }
    }

    private var accentColor: Color {
        switch snapshot.phase {
        case .idle:
            return Color.secondary
        case .locatingServer:
            return Color.orange
        case .measuringDownload:
            return Color.blue
        case .measuringUpload:
            return Color.green
        case .completed:
            return Color.green
        case .failed:
            return Color.red
        case .cancelled:
            return Color.yellow
        }
    }

    private func compactThroughput(_ mbps: Double?) -> String {
        guard let mbps else { return L10n.tr("common.placeholder") }

        if mbps < 10 {
            return String(format: "%.1f", mbps)
        }

        return String(format: "%.0f", mbps.rounded())
    }
}
