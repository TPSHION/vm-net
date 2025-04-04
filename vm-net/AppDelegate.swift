//
//  AppDelegate.swift
//  vm-net
//
//  Created by chen on 2025/4/4.
//
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: 85
        )

        // 定义菜单项
        let menu = NSMenu()
        let editMenuItem = NSMenuItem()
        editMenuItem.title = "Quit"
        editMenuItem.action = #selector(NSApplication.terminate(_:))
        editMenuItem.keyEquivalent = "q"
        menu.addItem(editMenuItem)
        self.statusItem.menu = menu

        // 定义按钮图标
        if let button = self.statusItem.button {
            let subHeight = NSStatusBar.system.thickness / 2
            print("subHeight:", subHeight)
            let uploadLabel = NSTextField(labelWithString: "0KB/s ↑")
            let downloadLabel = NSTextField(labelWithString: "0KB/s ↓")

            // 配置上传标签
            uploadLabel.frame = NSRect(
                x: 20,
                y: subHeight,
                width: 65,
                height: subHeight
            )
            uploadLabel.font = NSFont.systemFont(ofSize: 9)
            uploadLabel.textColor = NSColor.labelColor
            uploadLabel.alignment = .right

            // 配置下载标签
            downloadLabel.frame = NSRect(
                x: 20,
                y: 0,
                width: 65,
                height: subHeight
            )
            downloadLabel.font = NSFont.systemFont(ofSize: 9)
            downloadLabel.textColor = NSColor.labelColor
            downloadLabel.alignment = .right

            let customView = BackgroundColorView(
                frame: NSRect(
                    x: 0,
                    y: 0,
                    width: 85,
                    height: NSStatusBar.system.thickness
                )
            )
            if let image = NSImage(
                systemSymbolName: "teddybear.fill",
                accessibilityDescription: "Network Speed"
            ) {
                let iconImageView = NSImageView(image: image)
                iconImageView.frame = NSRect(
                    x: 0,
                    y: 0,
                    width: 20,
                    height: NSStatusBar.system.thickness
                )
                customView.addSubview(iconImageView)
            }

            // 添加到自定义视图
            customView.addSubview(uploadLabel)
            customView.addSubview(downloadLabel)

            button.addSubview(customView)

            let monitor = NetworkMonitor()
            monitor.updateHandler = { (sentSpeed, receivedSpeed) in
                uploadLabel.stringValue = sentSpeed
                downloadLabel.stringValue = receivedSpeed
            }
        }
    }
}
