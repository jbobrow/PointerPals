//
//  PointerPalsApp.swift
//  PointerPals
//
//  Created by Jonathan Bobrow on 1/14/26.
//

import SwiftUI

@main
struct PointerPalsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var cursorPublisher: CursorPublisher!
    private var cursorManager: CursorManager!
    private var networkManager: NetworkManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize managers
        networkManager = NetworkManager()
        cursorPublisher = CursorPublisher(networkManager: networkManager)
        cursorManager = CursorManager(networkManager: networkManager)
        
        // Setup menu bar
        setupMenuBar()
        
        // Request accessibility permissions if needed
        requestAccessibilityPermissions()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard statusItem.button != nil else { return }
        statusItem.button?.title = "..."
        
        updateMenu()
    }
    
    private func updateStatusItemTitle() {
        guard let button = statusItem.button else { return }
        
        let isPublishing = cursorPublisher.isPublishing
        let subCount = cursorManager.activeSubscriptions.count
        
        let icon = isPublishing ? PointerPalsConfig.publishingIcon : PointerPalsConfig.notPublishingIcon
        
        if PointerPalsConfig.showSubscriptionCount {
            button.title = "\(icon) \(subCount)"
        } else {
            button.title = icon
        }
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        // Publishing status
        let publishItem = NSMenuItem(
            title: cursorPublisher.isPublishing ? "Stop Publishing" : "Start Publishing",
            action: #selector(togglePublishing),
            keyEquivalent: "p"
        )
        publishItem.target = self
        menu.addItem(publishItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Subscriptions section
        let subsHeader = NSMenuItem(title: "Subscriptions", action: nil, keyEquivalent: "")
        subsHeader.isEnabled = false
        menu.addItem(subsHeader)
        
        if cursorManager.activeSubscriptions.isEmpty {
            let noSubs = NSMenuItem(title: "  No active subscriptions", action: nil, keyEquivalent: "")
            noSubs.isEnabled = false
            menu.addItem(noSubs)
        } else {
            for userId in cursorManager.activeSubscriptions {
                let subItem = NSMenuItem(
                    title: "  👤 \(userId)",
                    action: #selector(unsubscribe(_:)),
                    keyEquivalent: ""
                )
                subItem.target = self
                subItem.representedObject = userId
                menu.addItem(subItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add subscription
        let addSubItem = NSMenuItem(
            title: "Add Subscription...",
            action: #selector(showAddSubscription),
            keyEquivalent: "a"
        )
        addSubItem.target = self
        menu.addItem(addSubItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit PointerPals",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func togglePublishing() {
        if cursorPublisher.isPublishing {
            cursorPublisher.stopPublishing()
        } else {
            cursorPublisher.startPublishing()
        }
        updateStatusItemTitle()
        updateMenu()
    }
    
    @objc private func unsubscribe(_ sender: NSMenuItem) {
        if let userId = sender.representedObject as? String {
            cursorManager.unsubscribe(from: userId)
            updateStatusItemTitle()
            updateMenu()
        }
    }
    
    @objc private func showAddSubscription() {
        let alert = NSAlert()
        alert.messageText = "Add Subscription"
        alert.informativeText = "Enter the User ID to subscribe to:"
        alert.addButton(withTitle: "Subscribe")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.placeholderString = "user@example.com"
        alert.accessoryView = inputField
        
        alert.window.initialFirstResponder = inputField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let userId = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !userId.isEmpty {
                cursorManager.subscribe(to: userId)
                updateStatusItemTitle()
                updateMenu()
            }
        }
    }
    
    @objc private func showSettings() {
        let alert = NSAlert()
        alert.messageText = "Settings"
        alert.informativeText = "Your User ID: \(networkManager.currentUserId)\n\nShare this ID with others so they can subscribe to your cursor."
        alert.addButton(withTitle: "Copy ID")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(networkManager.currentUserId, forType: .string)
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    private func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrusted()  // ✅ Call without args
        if !accessibilityEnabled {
            AXIsProcessTrustedWithOptions(options as CFDictionary)  // ✅ Use the WITH options version
        }    }
}
