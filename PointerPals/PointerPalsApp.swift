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
    private var showUsernames: Bool {
        didSet {
            UserDefaults.standard.set(showUsernames, forKey: "PointerPals_ShowUsernames")
            cursorManager?.setUsernameVisibility(showUsernames)
            updateMenu()
        }
    }
    
    override init() {
        // Load username visibility preference (default: false/hidden)
        self.showUsernames = UserDefaults.standard.object(forKey: "PointerPals_ShowUsernames") as? Bool ?? false
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize managers
        networkManager = NetworkManager()
        cursorPublisher = CursorPublisher(networkManager: networkManager)
        cursorManager = CursorManager(networkManager: networkManager)

        // Apply username visibility setting
        cursorManager.setUsernameVisibility(showUsernames)

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

        // Show/Hide usernames toggle
        let usernamesItem = NSMenuItem(
            title: showUsernames ? "Hide Usernames" : "Show Usernames",
            action: #selector(toggleUsernames),
            keyEquivalent: "u"
        )
        usernamesItem.target = self
        menu.addItem(usernamesItem)

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

    @objc private func toggleUsernames() {
        showUsernames.toggle()
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
        alert.informativeText = "Share your User ID with others so they can subscribe to your cursor."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Copy ID")
        alert.addButton(withTitle: "Close")

        // Create a container view
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 100))

        // Username section
        let usernameLabel = NSTextField(labelWithString: "Username:")
        usernameLabel.frame = NSRect(x: 0, y: 76, width: 100, height: 17)
        usernameLabel.isBezeled = false
        usernameLabel.drawsBackground = false
        usernameLabel.isEditable = false
        usernameLabel.isSelectable = false

        let usernameField = NSTextField(frame: NSRect(x: 0, y: 50, width: 320, height: 24))
        usernameField.stringValue = networkManager.currentUsername
        usernameField.placeholderString = "Enter your username"

        // User ID section
        let userIdLabel = NSTextField(labelWithString: "Your User ID:")
        userIdLabel.frame = NSRect(x: 0, y: 26, width: 100, height: 17)
        userIdLabel.isBezeled = false
        userIdLabel.drawsBackground = false
        userIdLabel.isEditable = false
        userIdLabel.isSelectable = false

        let userIdField = NSTextField(labelWithString: networkManager.currentUserId)
        userIdField.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        userIdField.isBezeled = false
        userIdField.drawsBackground = false
        userIdField.isEditable = false
        userIdField.isSelectable = true
        userIdField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        userIdField.textColor = .secondaryLabelColor

        containerView.addSubview(usernameLabel)
        containerView.addSubview(usernameField)
        containerView.addSubview(userIdLabel)
        containerView.addSubview(userIdField)

        alert.accessoryView = containerView
        alert.window.initialFirstResponder = usernameField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Save username
            let newUsername = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newUsername.isEmpty {
                networkManager.currentUsername = newUsername
            }
        } else if response == .alertSecondButtonReturn {
            // Copy ID
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
