//
//  DesktopPetSettingsPageView.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit
import SwiftUI

struct DesktopPetSettingsPageView: View {

    @ObservedObject var preferences: AppPreferences
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerRow

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    previewSection
                    settingsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label("返回设置", systemImage: "chevron.left")
            }
            .buttonStyle(.link)

            Spacer(minLength: 0)

            Text(preferences.desktopPetAsset.displayName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
    }

    private var previewSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前预览")
                        .font(.system(size: 13, weight: .medium))

                    Text("这里展示的是当前启用的实际桌宠资源。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer(minLength: 0)

                    DesktopPetPreviewView(
                        asset: preferences.desktopPetAsset,
                        ambientInteractionEnabled: true
                    )
                    .frame(
                        width: preferences.desktopPetAsset.previewCanvasSize.width,
                        height: preferences.desktopPetAsset.previewCanvasSize.height
                    )

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )

                Text("预览区支持真实动画；当资源支持时，也可以在这里直接体验鼠标互动。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("预览")
        }
    }

    private var settingsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: desktopPetBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("启用桌面宠物")
                            .font(.system(size: 13, weight: .medium))

                        Text("打开后会跟随悬浮胶囊一起显示，并保持当前选中的宠物资源。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 4) {
                    Text("当前形象")
                        .font(.system(size: 13, weight: .medium))

                    Text(preferences.desktopPetAsset.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Text("当前版本仅保留这一套桌宠资源，后续新增资源时会继续在这里扩展。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if preferences.showDesktopPet && !preferences.showInFloatingBall {
                    Text("桌宠依附于悬浮胶囊显示；当前胶囊关闭，所以实际桌宠会先保持隐藏。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("配置")
        }
    }

    private var desktopPetBinding: Binding<Bool> {
        Binding(
            get: { preferences.showDesktopPet },
            set: { preferences.showDesktopPet = $0 }
        )
    }
}

private struct DesktopPetPreviewView: NSViewRepresentable {

    let asset: DesktopPetAsset
    let ambientInteractionEnabled: Bool

    func makeNSView(context: Context) -> DesktopPetPreviewHostView {
        let view = DesktopPetPreviewHostView(asset: asset)
        view.setAmbientInteractionEnabled(ambientInteractionEnabled)
        return view
    }

    func updateNSView(_ nsView: DesktopPetPreviewHostView, context: Context) {
        nsView.apply(asset: asset)
        nsView.setAmbientInteractionEnabled(ambientInteractionEnabled)
    }

    static func dismantleNSView(
        _ nsView: DesktopPetPreviewHostView,
        coordinator: ()
    ) {
        nsView.setAmbientInteractionEnabled(false)
    }
}

private final class DesktopPetPreviewHostView: NSView {

    private let contentView: DesktopPetContentView
    private var asset: DesktopPetAsset
    private var widthConstraint: NSLayoutConstraint
    private var heightConstraint: NSLayoutConstraint
    private var centerXConstraint: NSLayoutConstraint
    private var centerYConstraint: NSLayoutConstraint

    init(asset: DesktopPetAsset) {
        self.asset = asset
        self.contentView = DesktopPetContentView(
            frame: NSRect(origin: .zero, size: asset.layout.panelSize),
            asset: asset
        )
        self.widthConstraint = contentView.widthAnchor.constraint(
            equalToConstant: asset.layout.panelSize.width
        )
        self.heightConstraint = contentView.heightAnchor.constraint(
            equalToConstant: asset.layout.panelSize.height
        )
        self.centerXConstraint = contentView.centerXAnchor.constraint(
            equalTo: contentView.centerXAnchor
        )
        self.centerYConstraint = contentView.centerYAnchor.constraint(
            equalTo: contentView.centerYAnchor
        )

        super.init(frame: NSRect(origin: .zero, size: asset.previewCanvasSize))

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        centerXConstraint = contentView.centerXAnchor.constraint(
            equalTo: centerXAnchor,
            constant: asset.previewCenterOffset.x
        )
        centerYConstraint = contentView.centerYAnchor.constraint(
            equalTo: centerYAnchor,
            constant: asset.previewCenterOffset.y
        )

        NSLayoutConstraint.activate([
            centerXConstraint,
            centerYConstraint,
            widthConstraint,
            heightConstraint,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(asset: DesktopPetAsset) {
        self.asset = asset
        contentView.applyAsset(asset)
        widthConstraint.constant = asset.layout.panelSize.width
        heightConstraint.constant = asset.layout.panelSize.height
        centerXConstraint.constant = asset.previewCenterOffset.x
        centerYConstraint.constant = asset.previewCenterOffset.y
        frame.size = asset.previewCanvasSize
        invalidateIntrinsicContentSize()
    }

    func setAmbientInteractionEnabled(_ isEnabled: Bool) {
        contentView.setAmbientInteractionEnabled(isEnabled)
    }

    override var intrinsicContentSize: NSSize {
        asset.previewCanvasSize
    }
}
