//
//  AppControlMenuFactory.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

enum AppControlMenuFactory {

    static func makeMenu(
        target: AnyObject,
        openSelector: Selector
    ) -> NSMenu {
        let menu = NSMenu()

        let openWindowItem = NSMenuItem(
            title: L10n.tr("menu.openWindow"),
            action: openSelector,
            keyEquivalent: ""
        )
        openWindowItem.target = target
        menu.addItem(openWindowItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.tr("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }
}
