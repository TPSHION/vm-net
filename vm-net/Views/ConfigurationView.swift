//
//  ConfigurationView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import SwiftUI

struct ConfigurationView: View {

    @ObservedObject var preferences: AppPreferences
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            launchSection
            displaySection
            coreFeaturesSection
            Spacer(minLength: 0)
            footerNote
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("vm-net")
                .font(.system(size: 26, weight: .semibold))

            Text("状态栏持续显示网速，这里只保留核心配置。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var launchSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: launchAtLoginBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("开机自动启动")
                            .font(.system(size: 13, weight: .medium))

                        Text("登录 macOS 后自动启动 vm-net，并保持状态栏监控。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if launchAtLoginManager.requiresApproval {
                    HStack(spacing: 10) {
                        Text("系统需要你在“登录项”里允许 vm-net。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Button("打开系统设置") {
                            launchAtLoginManager.openSystemSettings()
                        }
                        .controlSize(.small)
                    }
                } else if let lastErrorMessage = launchAtLoginManager.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text("启动")
        }
    }

    private var displaySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("状态栏显示模式")
                        .font(.system(size: 13, weight: .medium))

                    Spacer(minLength: 16)

                    Text(preferences.displayMode.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Picker("状态栏显示模式", selection: $preferences.displayMode) {
                    ForEach(ThroughputDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(preferences.displayMode.summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text("配置")
        }
    }

    private var coreFeaturesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                featureRow(
                    icon: "bolt.fill",
                    title: "状态栏持续显示网速",
                    detail: "打开应用后，状态栏会一直保留上下行速率展示。"
                )
                featureRow(
                    icon: "xmark.square",
                    title: "关闭窗口不会退出",
                    detail: "关闭主窗口后，网速监控仍会继续运行。"
                )
                featureRow(
                    icon: "menubar.rectangle",
                    title: "可从状态栏重新打开",
                    detail: "通过状态栏菜单里的“Open vm-net”返回主窗口。"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text("核心功能")
        }
    }

    private var footerNote: some View {
        Text("关闭窗口即可回到纯状态栏模式；如由登录项自动拉起，则默认不弹出主窗口。")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    private func featureRow(
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginManager.isEnabled },
            set: { launchAtLoginManager.setEnabled($0) }
        )
    }
}
