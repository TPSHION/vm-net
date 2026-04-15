//
//  ConfigurationView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import SwiftUI

struct ConfigurationView: View {

    @ObservedObject var preferences: AppPreferences
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    let onFloatingBallToggle: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            launchSection
            presentationSection
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

            Text("默认常驻状态栏，也可以额外打开桌面悬浮胶囊。")
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

    private var presentationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("状态栏")
                        .font(.system(size: 13, weight: .medium))

                    Text("状态栏会保持常驻，持续显示上下行速率。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: floatingBallBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("悬浮胶囊")
                            .font(.system(size: 13, weight: .medium))

                        Text("在桌面常驻一个小胶囊，同时显示上传和下载。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("点击右侧颜色按钮即可修改外观。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    colorPickerRow(
                        title: "背景颜色",
                        selection: floatingBallBackgroundColorBinding
                    )

                    colorPickerRow(
                        title: "文字颜色",
                        selection: floatingBallTextColorBinding
                    )

                    colorPreviewCard

                    labeledSlider(
                        title: "背景透明度",
                        value: $preferences.floatingBallBackgroundTransparency,
                        range: 0...0.6,
                        description: backgroundTransparencySummary
                    )

                    HStack {
                        Text("颜色修改会立即作用到悬浮胶囊。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 12)

                        Button("恢复默认外观") {
                            preferences.resetFloatingBallAppearance()
                        }
                        .controlSize(.small)
                    }
                }

                Divider()

                HStack(alignment: .firstTextBaseline) {
                    Text("速率显示模式")
                        .font(.system(size: 13, weight: .medium))

                    Spacer(minLength: 16)

                    Text(preferences.displayMode.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Picker("速率显示模式", selection: $preferences.displayMode) {
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
            Text("展示")
        }
    }

    private var coreFeaturesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                featureRow(
                    icon: "capsule.portrait",
                    title: "悬浮胶囊支持桌面常驻",
                    detail: "开启后会记住位置，下次启动自动恢复。"
                )
                featureRow(
                    icon: "xmark.square",
                    title: "关闭窗口不会退出",
                    detail: "关闭主窗口后，网速监控仍会继续运行。"
                )
                featureRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "状态栏和胶囊共用同一份数据",
                    detail: "只保留一条采样链路，避免重复监控。"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text("核心功能")
        }
    }

    private var footerNote: some View {
        Text("登录项自动拉起时不会弹出主窗口；可从状态栏菜单或悬浮胶囊重新打开。")
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

    private func labeledSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 16)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range)
        }
    }

    private var backgroundTransparencySummary: String {
        "\(Int(round(preferences.floatingBallBackgroundTransparency * 100)))%"
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginManager.isEnabled },
            set: { launchAtLoginManager.setEnabled($0) }
        )
    }

    private var floatingBallBinding: Binding<Bool> {
        Binding(
            get: { preferences.showInFloatingBall },
            set: { newValue in
                preferences.showInFloatingBall = newValue
                onFloatingBallToggle(newValue)
            }
        )
    }

    private var floatingBallBackgroundColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: preferences.floatingBallBackgroundColor) },
            set: { preferences.floatingBallBackgroundColor = NSColor($0) }
        )
    }

    private var floatingBallTextColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: preferences.floatingBallTextColor) },
            set: { preferences.floatingBallTextColor = NSColor($0) }
        )
    }

    private var colorPreviewCard: some View {
        let fillOpacity = max(0.4, 1 - preferences.floatingBallBackgroundTransparency)

        return VStack(alignment: .leading, spacing: 8) {
            Text("当前效果")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack {
                Spacer(minLength: 0)

                VStack(
                    alignment: .leading,
                    spacing: FloatingBallContentView.contentRowSpacing
                ) {
                    previewRow(symbol: "↑", value: "49K/s")
                    previewRow(symbol: "↓", value: "1.9K/s")
                }
                .padding(.horizontal, FloatingBallContentView.contentHorizontalPadding)
                .padding(.vertical, FloatingBallContentView.contentVerticalPadding)
                .frame(
                    width: FloatingBallContentView.capsuleSize.width,
                    height: FloatingBallContentView.capsuleSize.height,
                    alignment: .leading
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: FloatingBallContentView.capsuleCornerRadius,
                        style: .continuous
                    )
                        .fill(
                            Color(nsColor: preferences.floatingBallBackgroundColor)
                                .opacity(fillOpacity)
                        )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: FloatingBallContentView.capsuleCornerRadius,
                        style: .continuous
                    )
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func previewRow(symbol: String, value: String) -> some View {
        HStack(spacing: FloatingBallContentView.contentItemSpacing) {
            Text(symbol)
                .font(.system(size: FloatingBallContentView.symbolFontSize, weight: .bold))

            Text(value)
                .font(
                    .system(
                        size: FloatingBallContentView.valueFontSize,
                        weight: .semibold,
                        design: .monospaced
                    )
                )
        }
        .foregroundStyle(Color(nsColor: preferences.floatingBallTextColor))
    }

    private func colorPickerRow(
        title: String,
        selection: Binding<Color>
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 12)

            ColorPicker("", selection: selection, supportsOpacity: false)
                .labelsHidden()
        }
    }
}
