//
//  ThroughputSparklineView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

final class ThroughputSparklineView: NSView {

    private var history: [NetworkThroughput] = []
    private var isActive = false

    override var intrinsicContentSize: NSSize {
        NSSize(width: 24, height: 14)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(history: [NetworkThroughput], isActive: Bool) {
        self.history = history
        self.isActive = isActive
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let plotRect = bounds.insetBy(dx: 1, dy: 1.5)
        drawBaseline(in: plotRect)

        guard history.count > 1 else { return }

        let maxValue = max(
            history.map(\.peakBytesPerSecond).max() ?? 0,
            1
        )
        drawLine(
            values: history.map(\.downloadBytesPerSecond),
            in: plotRect,
            maxValue: maxValue,
            color: NSColor.systemBlue.withAlphaComponent(isActive ? 0.95 : 0.55)
        )
        drawLine(
            values: history.map(\.uploadBytesPerSecond),
            in: plotRect,
            maxValue: maxValue,
            color: NSColor.systemOrange.withAlphaComponent(isActive ? 0.95 : 0.55)
        )
    }

    private func drawBaseline(in rect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        path.lineWidth = 1

        NSColor.secondaryLabelColor.withAlphaComponent(0.2).setStroke()
        path.stroke()
    }

    private func drawLine(
        values: [Double],
        in rect: NSRect,
        maxValue: Double,
        color: NSColor
    ) {
        guard values.count > 1 else { return }

        let path = NSBezierPath()
        let step = rect.width / CGFloat(max(values.count - 1, 1))

        for (index, value) in values.enumerated() {
            let ratio = CGFloat(min(max(value / maxValue, 0), 1))
            let point = NSPoint(
                x: rect.minX + CGFloat(index) * step,
                y: rect.minY + ratio * rect.height
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }

        path.lineWidth = 1.35
        path.lineJoinStyle = .round
        path.lineCapStyle = .round

        color.setStroke()
        path.stroke()
    }
}
