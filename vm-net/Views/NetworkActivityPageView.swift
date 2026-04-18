//
//  NetworkActivityPageView.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import AppKit
import SwiftUI

struct NetworkActivityPageView: View {

    private struct ProcessActionFeedback: Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    private enum ProcessSortOption: String, CaseIterable, Identifiable {
        case total
        case download
        case upload

        var id: String { rawValue }

        var title: String {
            switch self {
            case .total:
                return L10n.tr("activity.process.sort.total")
            case .download:
                return L10n.tr("activity.process.sort.download")
            case .upload:
                return L10n.tr("activity.process.sort.upload")
            }
        }
    }

    private enum ProcessFilterOption: String, CaseIterable, Identifiable {
        case all
        case background
        case alerted

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return L10n.tr("activity.process.filter.all")
            case .background:
                return L10n.tr("activity.process.filter.background")
            case .alerted:
                return L10n.tr("activity.process.filter.alerted")
            }
        }
    }

    @ObservedObject var throughputStore: ThroughputStore
    @ObservedObject var processTrafficStore: ProcessTrafficStore
    @ObservedObject var alertStore: AlertStore
    @ObservedObject var activityTimelineStore: ActivityTimelineStore
    let onBack: () -> Void

    @State private var sortOption: ProcessSortOption = .total
    @State private var filterOption: ProcessFilterOption = .all
    @State private var searchQuery = ""
    @State private var terminationCandidate: ProcessTrafficProcessRecord?
    @State private var processActionFeedback: ProcessActionFeedback?

    private let byteRateFormatter = ByteRateFormatter()
    private let processTerminationService = ProcessTerminationService()

    private var throughputSnapshot: NetworkMonitorSnapshot {
        throughputStore.snapshot
    }

    private var processSnapshot: ProcessTrafficSnapshot {
        processTrafficStore.snapshot
    }

    private var filteredProcesses: [ProcessTrafficProcessRecord] {
        processSnapshot.processes
            .filter(matchesFilter(_:))
            .filter(matchesSearch(_:))
            .sorted(by: sortComparator(_:_:))
    }

    private var displayedProcesses: [ProcessTrafficProcessRecord] {
        filteredProcesses
            .prefix(20)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerRow

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    summarySection
                    alertSection
                    timelineSection
                    processSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDisappear {
            processTrafficStore.deactivateMonitoring()
        }
        .confirmationDialog(
            terminationDialogTitle,
            isPresented: terminationDialogPresented,
            titleVisibility: .visible,
            presenting: terminationCandidate
        ) { process in
            Button(L10n.tr("activity.process.actions.terminate")) {
                performProcessAction(.graceful, for: process)
            }

            Button(
                L10n.tr("activity.process.actions.forceQuit"),
                role: .destructive
            ) {
                performProcessAction(.force, for: process)
            }
        } message: { process in
            Text(
                L10n.tr(
                    "activity.process.actions.dialog.message",
                    process.processName,
                    process.pid
                )
            )
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label(L10n.tr("navigation.backToSettings"), systemImage: "chevron.left")
            }
            .buttonStyle(.link)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.tr("activity.header.title"))
                    .font(.system(size: 18, weight: .semibold))

                Text(L10n.tr("activity.header.subtitle"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
    }

    private var summarySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    summaryMetricCard(
                        title: L10n.tr("activity.summary.download"),
                        value: byteRateFormatter.string(
                            for: throughputSnapshot.displayedThroughput.downloadBytesPerSecond
                        )
                    )

                    summaryMetricCard(
                        title: L10n.tr("activity.summary.upload"),
                        value: byteRateFormatter.string(
                            for: throughputSnapshot.displayedThroughput.uploadBytesPerSecond
                        )
                    )
                }

                HStack(spacing: 12) {
                    summaryMetricCard(
                        title: L10n.tr("activity.summary.interface"),
                        value: throughputSnapshot.monitoredInterfaceName
                            ?? L10n.tr("common.placeholder")
                    )

                    summaryMetricCard(
                        title: L10n.tr("activity.summary.activeProcesses"),
                        value: "\(processSnapshot.activeProcessCount)"
                    )
                }

                if let lastUpdatedAt = throughputSnapshot.lastUpdatedAt {
                    Text(
                        L10n.tr(
                            "activity.summary.lastUpdated",
                            SpeedTestFormatter.historyTimestampString(date: lastUpdatedAt)
                        )
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("activity.summary.sectionTitle"))
        }
    }

    private var processSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                processAnalysisControlRow

                if let errorMessage = processSnapshot.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let processActionFeedback {
                    Text(processActionFeedback.message)
                        .font(.system(size: 12))
                        .foregroundStyle(
                            processActionFeedback.isError
                                ? Color(nsColor: .systemRed)
                                : Color(nsColor: .systemGreen)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }

                if processTrafficStore.isMonitoring {
                    processControls

                    if processSnapshot.processes.isEmpty {
                        emptyProcessState
                    } else if displayedProcesses.isEmpty {
                        emptyFilteredState
                    } else {
                        processResultsSummary

                        ForEach(displayedProcesses) { process in
                            processRow(process)
                        }
                    }
                } else {
                    analysisInactiveState
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("activity.process.sectionTitle"))
        }
    }

    private var processAnalysisControlRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(processSnapshot.statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text(
                    processTrafficStore.isMonitoring
                        ? L10n.tr("activity.process.analysis.runningHint")
                        : L10n.tr("activity.process.analysis.idleHint")
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(action: toggleAnalysis) {
                Label(
                    processTrafficStore.isMonitoring
                        ? L10n.tr("activity.process.analysis.stop")
                        : L10n.tr("activity.process.analysis.start"),
                    systemImage: processTrafficStore.isMonitoring
                        ? "stop.circle"
                        : "play.circle"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var alertSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if alertStore.recentAnomalies.isEmpty {
                    Text(L10n.tr("activity.alert.empty"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(alertStore.recentAnomalies) { anomaly in
                        alertRow(anomaly)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("activity.alert.sectionTitle"))
        }
    }

    private var timelineSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if activityTimelineStore.recentEvents.isEmpty {
                    Text(L10n.tr("activity.timeline.empty"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activityTimelineStore.recentEvents) { event in
                        timelineRow(event)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("activity.timeline.sectionTitle"))
        }
    }

    private var processControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(
                L10n.tr("activity.process.controls.filter"),
                selection: $filterOption
            ) {
                ForEach(ProcessFilterOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .center, spacing: 10) {
                TextField(
                    L10n.tr("activity.process.search.placeholder"),
                    text: $searchQuery
                )
                .textFieldStyle(.roundedBorder)

                Picker(
                    L10n.tr("activity.process.controls.sort"),
                    selection: $sortOption
                ) {
                    ForEach(ProcessSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }
        }
    }

    private var processResultsSummary: some View {
        Text(
            L10n.tr(
                "activity.process.results",
                displayedProcesses.count,
                filteredProcesses.count
            )
        )
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private var emptyProcessState: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("activity.process.emptyTitle"))
                    .font(.system(size: 13, weight: .medium))

                Text(L10n.tr("activity.process.emptyDescription"))
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

    private var emptyFilteredState: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("activity.process.emptyFilteredTitle"))
                    .font(.system(size: 13, weight: .medium))

                Text(L10n.tr("activity.process.emptyFilteredDescription"))
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

    private var analysisInactiveState: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("activity.process.analysis.inactiveTitle"))
                    .font(.system(size: 13, weight: .medium))

                Text(L10n.tr("activity.process.analysis.inactiveDescription"))
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

    private func processRow(_ process: ProcessTrafficProcessRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.processName)
                        .font(.system(size: 13, weight: .medium))

                    processIdentityLine(for: process)
                }

                Spacer(minLength: 12)

                Button {
                    terminationCandidate = process
                } label: {
                    Label(
                        L10n.tr("activity.process.actions.button"),
                        systemImage: "power"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                processMetricBadge(
                    title: L10n.tr("activity.process.metric.pid"),
                    value: "\(process.pid)"
                )
                processMetricBadge(
                    title: L10n.tr("activity.process.metric.download"),
                    value: byteRateFormatter.string(for: process.downloadBytesPerSecond)
                )
                processMetricBadge(
                    title: L10n.tr("activity.process.metric.upload"),
                    value: byteRateFormatter.string(for: process.uploadBytesPerSecond)
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

    private var terminationDialogPresented: Binding<Bool> {
        Binding(
            get: { terminationCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    terminationCandidate = nil
                }
            }
        )
    }

    private var terminationDialogTitle: String {
        if let process = terminationCandidate {
            return L10n.tr(
                "activity.process.actions.dialog.title",
                process.processName
            )
        }

        return L10n.tr("activity.process.actions.button")
    }

    private func summaryMetricCard(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func processMetricBadge(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
    }

    private func alertRow(_ anomaly: NetworkAnomaly) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(nsColor: anomaly.severity.tintColor))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(anomaly.headline)
                        .font(.system(size: 13, weight: .medium))

                    Text(anomaly.kind.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: anomaly.severity.tintColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(nsColor: anomaly.severity.tintColor).opacity(0.12))
                        )
                }

                Text(anomaly.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(SpeedTestFormatter.historyTimestampString(date: anomaly.occurredAt))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func timelineRow(_ event: NetworkActivityTimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.severity.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: event.severity.tintColor))
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.headline)
                    .font(.system(size: 13, weight: .medium))

                Text(event.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(SpeedTestFormatter.historyTimestampString(date: event.occurredAt))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func matchesFilter(_ process: ProcessTrafficProcessRecord) -> Bool {
        switch filterOption {
        case .all:
            return true
        case .background:
            guard let bundleIdentifier = process.bundleIdentifier else {
                return false
            }
            let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?
                .bundleIdentifier
            return bundleIdentifier != frontmostBundleIdentifier
                && bundleIdentifier != Bundle.main.bundleIdentifier
        case .alerted:
            return isAlertedProcess(process)
        }
    }

    private func matchesSearch(_ process: ProcessTrafficProcessRecord) -> Bool {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        let loweredQuery = trimmedQuery.localizedLowercase
        if process.processName.localizedLowercase.contains(loweredQuery) {
            return true
        }

        if let bundleIdentifier = process.bundleIdentifier,
           bundleIdentifier.localizedLowercase.contains(loweredQuery) {
            return true
        }

        return false
    }

    private func sortComparator(
        _ lhs: ProcessTrafficProcessRecord,
        _ rhs: ProcessTrafficProcessRecord
    ) -> Bool {
        switch sortOption {
        case .total:
            if lhs.totalBytesPerSecond != rhs.totalBytesPerSecond {
                return lhs.totalBytesPerSecond > rhs.totalBytesPerSecond
            }
        case .download:
            if lhs.downloadBytesPerSecond != rhs.downloadBytesPerSecond {
                return lhs.downloadBytesPerSecond > rhs.downloadBytesPerSecond
            }
        case .upload:
            if lhs.uploadBytesPerSecond != rhs.uploadBytesPerSecond {
                return lhs.uploadBytesPerSecond > rhs.uploadBytesPerSecond
            }
        }

        if lhs.totalBytesPerSecond != rhs.totalBytesPerSecond {
            return lhs.totalBytesPerSecond > rhs.totalBytesPerSecond
        }

        if lhs.processName != rhs.processName {
            return lhs.processName.localizedStandardCompare(rhs.processName)
                == .orderedAscending
        }

        return lhs.pid < rhs.pid
    }

    private func isAlertedProcess(_ process: ProcessTrafficProcessRecord) -> Bool {
        alertStore.recentAnomalies.contains { anomaly in
            if let bundleIdentifier = process.bundleIdentifier,
               let anomalyBundleIdentifier = anomaly.bundleIdentifier {
                return bundleIdentifier == anomalyBundleIdentifier
            }

            return anomaly.processName == process.processName
        }
    }

    private func processIdentityLine(for process: ProcessTrafficProcessRecord) -> some View {
        let bundleIdentifier = process.bundleIdentifier ?? L10n.tr("common.placeholder")
        let pidLine = L10n.tr("activity.process.identity.pid", process.pid)
        let detailLine = [
            bundleIdentifier,
            pidLine,
        ].joined(separator: L10n.tr("common.detailSeparator"))

        return Text(detailLine)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func performProcessAction(
        _ mode: ProcessTerminationMode,
        for process: ProcessTrafficProcessRecord
    ) {
        terminationCandidate = nil

        do {
            let result = try processTerminationService.terminate(process, mode: mode)
            let message: String

            switch result.mode {
            case .graceful:
                message = L10n.tr(
                    "activity.process.action.success.terminate",
                    process.processName,
                    process.pid
                )
            case .force:
                message = L10n.tr(
                    "activity.process.action.success.forceQuit",
                    process.processName,
                    process.pid
                )
            }

            processActionFeedback = ProcessActionFeedback(
                message: message,
                isError: false
            )
        } catch {
            let reason = error.localizedDescription
            processActionFeedback = ProcessActionFeedback(
                message: L10n.tr(
                    "activity.process.action.failure",
                    process.processName,
                    reason
                ),
                isError: true
            )
        }
    }

    private func toggleAnalysis() {
        processActionFeedback = nil

        if processTrafficStore.isMonitoring {
            processTrafficStore.deactivateMonitoring()
        } else {
            processTrafficStore.activateMonitoring()
        }
    }
}
