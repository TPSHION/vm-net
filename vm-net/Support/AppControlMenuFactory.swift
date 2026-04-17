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
        openWindowSelector: Selector,
        openActivitySelector: Selector
    ) -> NSMenu {
        let menu = NSMenu()
        populateMenu(
            menu,
            target: target,
            openWindowSelector: openWindowSelector,
            openActivitySelector: openActivitySelector
        )
        return menu
    }

    static func populateMenu(
        _ menu: NSMenu,
        target: AnyObject,
        openWindowSelector: Selector,
        openActivitySelector: Selector
    ) {
        menu.removeAllItems()

        let openWindowItem = NSMenuItem(
            title: L10n.tr("menu.openWindow"),
            action: openWindowSelector,
            keyEquivalent: ""
        )
        openWindowItem.target = target
        menu.addItem(openWindowItem)

        let openActivityItem = NSMenuItem(
            title: L10n.tr("menu.openActivity"),
            action: openActivitySelector,
            keyEquivalent: ""
        )
        openActivityItem.target = target
        menu.addItem(openActivityItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.tr("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)
    }
}
