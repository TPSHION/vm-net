//
//  BackgroundColorView.swift
//  vm-net
//
//  Created by chen on 2025/4/4.
//
import Cocoa

class BackgroundColorView: NSView {
    var backgroundColor: NSColor = .clear  // 默认背景颜色为透明

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 绘制背景颜色
        backgroundColor.setFill()
        dirtyRect.fill()
    }
}
