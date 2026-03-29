#!/usr/bin/env swift
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let screenRect = NSScreen.main?.frame ?? .zero
        let windowRect = NSRect(
            x: (screenRect.width - 400) / 2,
            y: (screenRect.height - 300) / 2,
            width: 400,
            height: 300
        )

        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window?.title = "Hello, World!"
        window?.makeKeyAndOrderFront(nil)

        // Create label
        let label = NSTextField(frame: CGRect(x: 50, y: 125, width: 300, height: 50))
        label.stringValue = "Hello, World!"
        label.isEditable = false
        label.isSelectable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.font = NSFont.systemFont(ofSize: 24.0)
        label.textColor = .black

        window?.contentView?.addSubview(label)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Main entry point
autoreleasepool {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    NSApp.run()
}
