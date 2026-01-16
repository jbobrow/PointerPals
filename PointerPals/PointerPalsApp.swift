//
//  PointerPalsApp.swift
//  PointerPals
//
//  Created by Jonathan Bobrow on 1/14/26.
//

import SwiftUI
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    private var demoCursorWindow: CursorWindow?
    private var demoTimer: Timer?
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

        // Subscribe to subscription changes to update menu
        cursorManager.subscriptionsDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)

        // Setup menu bar
        setupMenuBar()
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

        // Demo cursor
        let demoItem = NSMenuItem(
            title: demoCursorWindow == nil ? "Show Demo Cursor" : "Hide Demo Cursor",
            action: #selector(toggleDemoCursor),
            keyEquivalent: "d"
        )
        demoItem.target = self
        menu.addItem(demoItem)

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
                let subItem = NSMenuItem()
                subItem.action = #selector(unsubscribe(_:))
                subItem.keyEquivalent = ""
                subItem.target = self
                subItem.representedObject = userId

                // Create attributed string with username and grey userId
                let username = cursorManager.getUsername(for: userId) ?? "User"
                let displayText = "  👤 \(username) (\(userId))"

                let attributedTitle = NSMutableAttributedString(string: displayText)

                // Find the range of the userId (text within parentheses)
                if let openParen = displayText.firstIndex(of: "("),
                   let closeParen = displayText.firstIndex(of: ")") {
                    let userIdRange = NSRange(openParen..<displayText.index(after: closeParen), in: displayText)

                    // Style the userId in grey
                    attributedTitle.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: userIdRange)
                }

                subItem.attributedTitle = attributedTitle
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
        inputField.placeholderString = "user_8675309"
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
    
    @objc private func toggleDemoCursor() {
        if demoCursorWindow != nil {
            stopDemoCursor()
        } else {
            startDemoCursor()
        }
        updateMenu()
    }

    private func startDemoCursor() {
        // Create demo cursor window
        demoCursorWindow = CursorWindow(userId: "demo")
        demoCursorWindow?.updateUsername("Hello from PointerPals!")

        let duration: TimeInterval = 6.0 // Total animation duration in seconds
        let fps: Double = 60.0
        let totalFrames = Int(duration * fps)
        var currentFrame = 0
        var hasStartedFadeOut = false // Track if we've already started fading out

        // Set initial position
        demoCursorWindow?.updatePosition(x: 0.5, y: 0.3)

        // Start animation after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            self.demoCursorWindow?.fadeIn()

            self.demoTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] timer in
                guard let self = self, self.demoCursorWindow != nil else {
                    timer.invalidate()
                    return
                }

                currentFrame += 1
                let progress = Double(currentFrame) / Double(totalFrames)

                // Ease-in-out function: smoothstep
                let eased = progress * progress * (3.0 - 2.0 * progress)

                // Calculate angle (0 = 12 o'clock, goes clockwise)
                let startAngle = -Double.pi / 2
                let angle = startAngle + (eased * 2.0 * Double.pi)

                // Circle parameters (centered on screen)
                let radius = 0.2
                let centerX = 0.5
                let centerY = 0.5

                // Calculate position on circle
                let x = centerX + (radius * cos(angle))
                let y = centerY + (radius * sin(angle))

                // Update cursor position
                self.demoCursorWindow?.updatePosition(x: x, y: y)

                // Fade out in the last 10% of animation (only once)
                if progress > 0.9 && !hasStartedFadeOut {
                    hasStartedFadeOut = true
                    self.demoCursorWindow?.fadeOut()
                }

                // Stop when complete
                if currentFrame >= totalFrames {
                    timer.invalidate()
                    self.demoTimer = nil

                    // Cleanup after fade out completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.cleanupDemoCursor()
                    }
                }
            }
        }
    }

    private func cleanupDemoCursor() {
        guard let window = demoCursorWindow else { return }

        // Clear reference immediately
        demoCursorWindow = nil

        // CRITICAL: Thoroughly clean up all animations and views
        // Remove all window-level animations
        window.animations = [:]

        // Remove all layer animations from window and content view
        window.layer?.removeAllAnimations()
        window.contentView?.layer?.removeAllAnimations()
        window.contentView?.subviews.forEach { subview in
            subview.layer?.removeAllAnimations()
            subview.animations = [:]
        }

        // Hide window immediately (no animation)
        window.alphaValue = 0.0
        window.orderOut(nil)

        // Close after a longer delay to ensure all animation completion handlers have run
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            window.close()
            self?.updateMenu()
        }
    }

    private func stopDemoCursor() {
        // User manually stopped, clean up immediately
        demoTimer?.invalidate()
        demoTimer = nil

        if let window = demoCursorWindow {
            demoCursorWindow = nil

            // Thoroughly remove all animations
            window.animations = [:]
            window.layer?.removeAllAnimations()
            window.contentView?.layer?.removeAllAnimations()
            window.contentView?.subviews.forEach { subview in
                subview.layer?.removeAllAnimations()
                subview.animations = [:]
            }

            // Hide window immediately
            window.alphaValue = 0.0
            window.orderOut(nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                window.close()
            }
        }

        updateMenu()
    }

    @objc private func quit() {
        stopDemoCursor()
        NSApplication.shared.terminate(nil)
    }
}
