//
//  NetworkActivityPageView.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import AppKit
import SwiftUI

struct NetworkActivityPageView: View {

    @ObservedObject var throughputStore: ThroughputStore
    @ObservedObject var processTrafficStore: ProcessTrafficStore
    let onBack: () -> Void

    private let byteRateFormatter = ByteRateFormatter()

    private var throughputSnapshot: NetworkMonitorSnapshot {
        throughputStore.snapshot
    }

    private var processSnapshot: ProcessTrafficSnapshot {
        processTrafficStore.snapshot
    }

    private var topProcesses: [ProcessTrafficProcessRecord] {
        processSnapshot.processes
            .sorted { $0.totalBytesPerSecond > $1.totalBytesPerSecond }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerRow

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    summarySection
                    processSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                Text(processSnapshot.statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if topProcesses.isEmpty {
                    emptyProcessState
                } else {
                    ForEach(topProcesses) { process in
                        processRow(process)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("activity.process.sectionTitle"))
        }
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

    private func processRow(_ process: ProcessTrafficProcessRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.processName)
                        .font(.system(size: 13, weight: .medium))

                    if let bundleIdentifier = process.bundleIdentifier {
                        Text(bundleIdentifier)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                Text("#\(process.activeConnectionCount)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                processMetricBadge(
                    title: L10n.tr("activity.process.metric.download"),
                    value: byteRateFormatter.string(for: process.downloadBytesPerSecond)
                )
                processMetricBadge(
                    title: L10n.tr("activity.process.metric.upload"),
                    value: byteRateFormatter.string(for: process.uploadBytesPerSecond)
                )
                processMetricBadge(
                    title: L10n.tr("activity.process.metric.connections"),
                    value: "\(process.activeConnectionCount)"
                )
            }

            if !process.remoteHostsTop.isEmpty {
                Text(
                    L10n.tr(
                        "activity.process.metric.hostsValue",
                        process.remoteHostsTop.joined(separator: L10n.tr("common.listSeparator"))
                    )
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
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
}
