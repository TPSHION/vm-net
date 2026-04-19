//
//  NetworkDiagnosisPageView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import SwiftUI

struct NetworkDiagnosisPageView: View {

    @ObservedObject var store: NetworkDiagnosisStore
    let onBack: (() -> Void)? = nil

    private var snapshot: NetworkDiagnosisSnapshot {
        store.snapshot
    }

    private var isIdleEmptyState: Bool {
        snapshot.phase == .idle && snapshot.checks.isEmpty && snapshot.errorMessage == nil
    }

    private var shouldShowCurrentSummary: Bool {
        guard let _ = snapshot.lastResult else { return false }
        return (snapshot.phase == .completed || snapshot.phase == .failed) && !snapshot.checks.isEmpty
    }

    private var displayedStatusMessage: String {
        switch snapshot.phase {
        case .idle:
            return L10n.tr("diagnosis.snapshot.idleStatus")
        case .cancelled:
            return L10n.tr("diagnosis.store.cancelled")
        default:
            return snapshot.statusMessage
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerRow

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    targetSection
                    statusSection
                    resultSection
                    historySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .vmNetScrollBarsHidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                Text(L10n.tr("navigation.diagnosis.title"))
                    .font(.system(size: 18, weight: .semibold))

                Text(L10n.tr("navigation.diagnosis.subtitle"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if snapshot.isRunning {
                Button(L10n.tr("common.cancel")) {
                    store.cancelDiagnosis()
                }
                .controlSize(.small)
            } else {
                Button(L10n.tr("diagnosis.start")) {
                    store.startDiagnosis()
                }
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
    }

    private var statusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                statusHeroLayout

                Text(snapshot.errorMessage ?? snapshot.phase.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("diagnosis.currentStatus"))
        }
    }

    private var targetSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    targetControlsRow
                    targetControlsColumn
                }

                Text(L10n.tr("diagnosis.target.hint"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("diagnosis.target.sectionTitle"))
        }
    }

    private var resultSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if isIdleEmptyState {
                    idleResultStateCard
                } else if snapshot.checks.isEmpty {
                    transientResultStateText
                } else {
                    ForEach(snapshot.checks) { check in
                        diagnosisCheckCard(check)
                    }
                }

                if shouldShowCurrentSummary, let lastResult = snapshot.lastResult {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(lastResult.headline)
                            .font(.system(size: 13, weight: .medium))

                        Text(lastResult.summary)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("diagnosis.result.sectionTitle"))
        }
    }

    private var idleResultStateCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "stethoscope.circle")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("diagnosis.result.emptyTitle"))
                    .font(.system(size: 13, weight: .medium))

                Text(L10n.tr("diagnosis.result.emptyDescription"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        )
    }

    private var transientResultStateText: some View {
        Text(transientResultMessage)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    private var transientResultMessage: String {
        switch snapshot.phase {
        case .checkingPath, .resolvingDNS, .checkingHTTPS:
            return L10n.tr("diagnosis.result.collecting")
        case .cancelled:
            return L10n.tr("diagnosis.result.cancelled")
        case .completed, .failed:
            return L10n.tr("diagnosis.result.noDetails")
        case .idle:
            return L10n.tr("diagnosis.result.idleHint")
        }
    }

    private var historySection: some View {
        GroupBox {
            if store.recentResults.isEmpty {
                Text(L10n.tr("diagnosis.history.empty"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(store.recentResults) { result in
                        historyCard(result)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } label: {
            Text(L10n.tr("diagnosis.history.sectionTitle"))
        }
    }

    private var statusHeroLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                DiagnosisActivityView(snapshot: snapshot)

                statusSummaryBlock

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer(minLength: 0)
                    DiagnosisActivityView(snapshot: snapshot)
                    Spacer(minLength: 0)
                }

                statusSummaryBlock
            }
        }
    }

    private var statusSummaryBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.phase.title)
                    .font(.system(size: 18, weight: .semibold))

                Text(displayedStatusMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Label(snapshot.targetHost, systemImage: "network")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            DiagnosisStageStrip(phase: snapshot.phase, checks: snapshot.checks)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var targetControlsRow: some View {
        HStack(spacing: 10) {
            targetPicker

            resetTargetButton
        }
    }

    private var targetControlsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            targetPicker

            HStack {
                resetTargetButton
                Spacer(minLength: 0)
            }
        }
    }

    private var targetPicker: some View {
        Picker(L10n.tr("diagnosis.target.picker"), selection: $store.selectedTarget) {
            ForEach(NetworkDiagnosisTarget.allCases) { target in
                Text(target.title).tag(target)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(snapshot.isRunning)
    }

    private var resetTargetButton: some View {
        Button(L10n.tr("common.restoreDefault")) {
            store.resetTarget()
        }
        .controlSize(.small)
        .disabled(snapshot.isRunning || store.selectedTarget == NetworkDiagnosisStore.defaultTarget)
    }

    private func diagnosisCheckCard(_ check: NetworkDiagnosisCheck) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(check.status.tintColor)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(check.kind.title)
                        .font(.system(size: 13, weight: .medium))

                    Text(check.status.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(check.status.tintColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(check.status.tintColor.opacity(0.12))
                        )
                }

                Text(check.summary)
                    .font(.system(size: 12))

                if let detail = check.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func historyCard(_ result: NetworkDiagnosisResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(NetworkDiagnosisFormatter.timestampString(result.finishedAt))
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 12)

                Text(result.targetHost)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text(result.headline)
                .font(.system(size: 12, weight: .medium))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                compactMetric(
                    title: "DNS",
                    value: NetworkDiagnosisFormatter.latencyString(result.dnsLatencyMilliseconds)
                )
                compactMetric(
                    title: "HTTPS",
                    value: NetworkDiagnosisFormatter.latencyString(result.httpsLatencyMilliseconds)
                )
                compactMetric(
                    title: L10n.tr("diagnosis.metric.status"),
                    value: NetworkDiagnosisFormatter.statusCodeString(result.httpStatusCode)
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

    private func compactMetric(title: String, value: String) -> some View {
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

private struct DiagnosisStageStrip: View {

    let phase: NetworkDiagnosisPhase
    let checks: [NetworkDiagnosisCheck]

    var body: some View {
        HStack(spacing: 10) {
            stageItem(kind: .path, state: state(for: .path))
            connector
            stageItem(kind: .dns, state: state(for: .dns))
            connector
            stageItem(kind: .https, state: state(for: .https))
        }
    }

    private var connector: some View {
        Capsule()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 16, height: 2)
    }

    private func stageItem(kind: NetworkDiagnosisCheckKind, state: StageState) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.tint)
                .frame(width: 8, height: 8)

            Text(kind.title)
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

    private func state(for kind: NetworkDiagnosisCheckKind) -> StageState {
        if let check = checks.first(where: { $0.kind == kind }) {
            return switch check.status {
            case .success:
                .completed
            case .warning:
                .warning
            case .failure:
                .failed
            case .skipped:
                .skipped
            }
        }

        return switch phase {
        case .idle:
            .pending
        case .checkingPath where kind == .path:
            .current
        case .resolvingDNS where kind == .dns:
            .current
        case .checkingHTTPS where kind == .https:
            .current
        default:
            .pending
        }
    }

    private enum StageState {
        case pending
        case current
        case completed
        case warning
        case failed
        case skipped

        var tint: Color {
            switch self {
            case .pending:
                return .secondary.opacity(0.35)
            case .current:
                return .orange
            case .completed:
                return .green
            case .warning:
                return .yellow
            case .failed:
                return .red
            case .skipped:
                return .secondary
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
            case .warning:
                return Color.yellow.opacity(0.16)
            case .failed:
                return Color.red.opacity(0.12)
            case .skipped:
                return Color.secondary.opacity(0.1)
            }
        }

        var textColor: Color {
            switch self {
            case .pending, .skipped:
                return .secondary
            case .current:
                return .orange
            case .completed:
                return .green
            case .warning:
                return .yellow
            case .failed:
                return .red
            }
        }
    }
}

private struct DiagnosisActivityView: View {

    let snapshot: NetworkDiagnosisSnapshot

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !snapshot.isRunning)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let pulse = snapshot.isRunning ? (sin(time * 2.1) + 1) / 2 : 0.24
            let pulseScale = 0.94 + pulse * 0.1
            let rotation = snapshot.isRunning
                ? Angle(degrees: (time * 90).truncatingRemainder(dividingBy: 360))
                : .degrees(18)

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
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 84, height: 84)
                    .scaleEffect(pulseScale)

                Circle()
                    .stroke(accentColor.opacity(snapshot.isRunning ? 0.18 : 0.08), lineWidth: 1)
                    .frame(width: 80, height: 80)
                    .scaleEffect(0.98 + pulse * 0.06)

                Circle()
                    .trim(from: 0.12, to: 0.36)
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
                    .shadow(color: accentColor.opacity(0.45), radius: 10)

                VStack(spacing: 6) {
                    Image(systemName: snapshot.phase.symbolName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(accentColor)

                    Text(activityLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(activityValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 132, height: 132)
    }

    private var activityLabel: String {
        switch snapshot.phase {
        case .idle:
            return L10n.tr("common.pendingStart")
        case .checkingPath:
            return L10n.tr("diagnosis.activity.path")
        case .resolvingDNS:
            return "DNS"
        case .checkingHTTPS:
            return "HTTPS"
        case .completed:
            return L10n.tr("common.completed")
        case .failed:
            return L10n.tr("common.failed")
        case .cancelled:
            return L10n.tr("common.cancelledShort")
        }
    }

    private var activityValue: String {
        if snapshot.isRunning {
            return snapshot.phase.title
        }

        switch snapshot.phase {
        case .idle:
            return L10n.tr("diagnosis.activity.waiting")
        case .cancelled:
            return L10n.tr("diagnosis.activity.stopped")
        case .completed, .failed:
            return snapshot.lastResult?.headline ?? snapshot.phase.title
        case .checkingPath, .resolvingDNS, .checkingHTTPS:
            return snapshot.phase.title
        }
    }

    private var accentColor: Color {
        switch snapshot.phase {
        case .idle:
            return .secondary
        case .checkingPath:
            return .blue
        case .resolvingDNS:
            return .orange
        case .checkingHTTPS:
            return .green
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .yellow
        }
    }
}

private extension NetworkDiagnosisCheckStatus {
    var tintColor: Color {
        switch self {
        case .success:
            return .green
        case .warning:
            return .yellow
        case .failure:
            return .red
        case .skipped:
            return .secondary
        }
    }
}
