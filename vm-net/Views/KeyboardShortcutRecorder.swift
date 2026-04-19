//
//  KeyboardShortcutRecorder.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct KeyboardShortcutRecorder: View {

    @Binding var shortcut: KeyboardShortcut

    @State private var isRecording = false
    @State private var validationMessage: String?
    @State private var eventMonitor: Any?

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button {
                toggleRecording()
            } label: {
                Text(
                    isRecording
                        ? L10n.tr("settings.shortcuts.recorder.recording")
                        : shortcut.displayString
                )
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(minWidth: 118, alignment: .center)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
            return
        }

        validationMessage = nil
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { event in
            guard isRecording else { return event }
            return handle(event)
        }
    }

    private func stopRecording() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        isRecording = false
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return nil
        }

        let modifiers = event.modifierFlags.intersection(KeyboardShortcut.modifierMask)
        guard !KeyboardShortcut.isModifierOnlyKeyCode(event.keyCode) else {
            validationMessage = L10n.tr("settings.shortcuts.recorder.invalid")
            NSSound.beep()
            return nil
        }

        guard !modifiers.isEmpty else {
            validationMessage = L10n.tr("settings.shortcuts.recorder.invalid")
            NSSound.beep()
            return nil
        }

        shortcut = KeyboardShortcut(
            keyCode: event.keyCode,
            modifiers: modifiers
        )
        validationMessage = nil
        stopRecording()
        return nil
    }
}
