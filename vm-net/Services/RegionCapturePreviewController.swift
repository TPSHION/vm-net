//
//  RegionCapturePreviewController.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit

@MainActor
final class RegionCapturePreviewController: NSWindowController {

    private enum Layout {
        static let maxWidth: CGFloat = 240
        static let maxHeight: CGFloat = 160
        static let margin: CGFloat = 20
        static let autoDismissDelay: TimeInterval = 3.5
    }

    private let previewView = RegionCapturePreviewView()
    private var dismissWorkItem: DispatchWorkItem?

    init() {
        let panel = RegionCapturePreviewPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)
        configurePanel(panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(
        pngData: Data,
        pixelSize: NSSize,
        fileURL: URL?,
        on screen: NSScreen?
    ) {
        guard
            let image = NSImage(data: pngData),
            let window,
            let screen = screen ?? NSScreen.main
        else {
            return
        }

        let previewSize = fittedPreviewSize(for: pixelSize)
        let frame = NSRect(
            x: screen.visibleFrame.maxX - previewSize.width - Layout.margin,
            y: screen.visibleFrame.minY + Layout.margin,
            width: previewSize.width,
            height: previewSize.height
        )

        previewView.frame = NSRect(origin: .zero, size: previewSize)
        previewView.autoresizingMask = [.width, .height]
        previewView.update(image: image, fileURL: fileURL)

        window.setFrame(frame, display: false)
        window.contentView = previewView
        window.alphaValue = 1
        window.orderFrontRegardless()

        scheduleDismiss()
    }

    private func configurePanel(_ panel: RegionCapturePreviewPanel) {
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
    }

    private func fittedPreviewSize(for pixelSize: NSSize) -> NSSize {
        guard pixelSize.width > 0, pixelSize.height > 0 else {
            return NSSize(width: Layout.maxWidth, height: Layout.maxHeight)
        }

        let widthRatio = Layout.maxWidth / pixelSize.width
        let heightRatio = Layout.maxHeight / pixelSize.height
        let scale = min(widthRatio, heightRatio, 1)

        return NSSize(
            width: max(120, floor(pixelSize.width * scale)),
            height: max(90, floor(pixelSize.height * scale))
        )
    }

    private func scheduleDismiss() {
        dismissWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let window = self?.window else { return }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                window.animator().alphaValue = 0
            } completionHandler: {
                window.orderOut(nil)
            }
        }

        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Layout.autoDismissDelay,
            execute: workItem
        )
    }
}

private final class RegionCapturePreviewPanel: NSPanel {

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class RegionCapturePreviewView: NSView {

    private let visualEffectView = NSVisualEffectView()
    private let imageView = NSImageView()
    private var fileURL: URL?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true

        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.frame = bounds
        visualEffectView.autoresizingMask = [.width, .height]

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = bounds.insetBy(dx: 8, dy: 8)
        imageView.autoresizingMask = [.width, .height]

        addSubview(visualEffectView)
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(image: NSImage, fileURL: URL?) {
        imageView.image = image
        self.fileURL = fileURL
    }

    override func mouseDown(with event: NSEvent) {
        guard let fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}
