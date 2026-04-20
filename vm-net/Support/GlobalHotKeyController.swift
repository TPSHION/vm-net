//
//  GlobalHotKeyController.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit
import Carbon.HIToolbox

final class GlobalHotKeyController {

    private static let signature = OSType(0x564D4E54) // VMNT
    private static let hotKeyIdentifier: UInt32 = 1
    private static var eventHandlerRef: EventHandlerRef?
    private static weak var activeController: GlobalHotKeyController?

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?

    init() {
        Self.installHandlerIfNeeded()
        Self.activeController = self
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    @discardableResult
    func updateShortcut(_ shortcut: KeyboardShortcut) -> OSStatus {
        unregister()

        guard shortcut.isValid else {
            return OSStatus(paramErr)
        }

        guard let dispatcher = GetEventDispatcherTarget() else {
            return OSStatus(eventInternalErr)
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.hotKeyIdentifier
        )

        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifierFlags,
            hotKeyID,
            dispatcher,
            0,
            &hotKeyRef
        )

        return status
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func handleHotKey(_ hotKeyID: EventHotKeyID) {
        guard
            hotKeyID.signature == Self.signature,
            hotKeyID.id == Self.hotKeyIdentifier
        else {
            return
        }

        DispatchQueue.main.async { [onPress] in
            onPress?()
        }
    }

    private static func installHandlerIfNeeded() {
        guard
            eventHandlerRef == nil,
            let dispatcher = GetEventDispatcherTarget()
        else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            dispatcher,
            { _, event, _ in
                guard let event else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return status }
                GlobalHotKeyController.activeController?.handleHotKey(hotKeyID)
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }
}
