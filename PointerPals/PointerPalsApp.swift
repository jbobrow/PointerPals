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
        }
    }

    private var cursorScale: CGFloat {
        didSet {
            UserDefaults.standard.set(cursorScale, forKey: "PointerPals_CursorScale")
            cursorManager?.setCursorScale(cursorScale)
        }
    }

    override init() {
        // Load username visibility preference (default: false/hidden)
        self.showUsernames = UserDefaults.standard.object(forKey: "PointerPals_ShowUsernames") as? Bool ?? false

        // Load cursor scale preference (default: 0.5)
        self.cursorScale = UserDefaults.standard.object(forKey: "PointerPals_CursorScale") as? CGFloat ?? PointerPalsConfig.defaultCursorScale

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize managers
        networkManager = NetworkManager()
        cursorPublisher = CursorPublisher(networkManager: networkManager)
        cursorManager = CursorManager(networkManager: networkManager, cursorScale: cursorScale)

        // Apply username visibility setting
        cursorManager.setUsernameVisibility(showUsernames)

        // Subscribe to subscription changes to update menu and status
        cursorManager.subscriptionsDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
                self?.updateMenu()
            }
            .store(in: &cancellables)

        // Setup menu bar
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard statusItem.button != nil else { return }

        // Set initial icon and title
        updateStatusItemTitle()
        updateMenu()
    }
    
    private func updateStatusItemTitle() {
        guard let button = statusItem.button else { return }

        let isPublishing = cursorPublisher.isPublishing
        let subCount = cursorManager.activeSubscriptionsCount

        // Determine which icon to use based on state
        let iconName: String
        if isPublishing {
            iconName = PointerPalsConfig.publishingIcon
        } else if subCount > 0 {
            iconName = PointerPalsConfig.activeSubscriptionsIcon
        } else {
            iconName = PointerPalsConfig.idleIcon
        }

        // Load SF Symbol icon
        if let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            button.image = icon
            button.imagePosition = .imageLeading

            if PointerPalsConfig.showSubscriptionCount {
                button.title = " \(subCount)"
            } else {
                button.title = ""
            }
        } else {
            // Fallback if SF Symbol not available
            button.image = nil
            button.title = isPublishing ? "📍" : (subCount > 0 ? "👀" : "💤")
            if PointerPalsConfig.showSubscriptionCount {
                button.title += " \(subCount)"
            }
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

        if cursorManager.allSubscriptions.isEmpty {
            let noSubs = NSMenuItem(title: "--None yet--", action: nil, keyEquivalent: "")
            noSubs.isEnabled = false
            menu.addItem(noSubs)
        } else {
            for userId in cursorManager.allSubscriptions {
                let isEnabled = cursorManager.isSubscriptionEnabled(userId)

                let subItem = NSMenuItem()
                subItem.action = #selector(toggleSubscription(_:))
                subItem.keyEquivalent = ""
                subItem.target = self
                subItem.representedObject = userId

                // Create attributed string with username and grey userId
                let username = cursorManager.getUsername(for: userId) ?? "User"
                let stateIcon = isEnabled ? "✓" : "○"
                let displayText = "  \(stateIcon) \(username) (\(userId))"

                let attributedTitle = NSMutableAttributedString(string: displayText)

                // Find the range of the userId (text within parentheses)
                if let openParen = displayText.firstIndex(of: "("),
                   let closeParen = displayText.firstIndex(of: ")") {
                    let userIdRange = NSRange(openParen..<displayText.index(after: closeParen), in: displayText)

                    // Style the userId in grey
                    attributedTitle.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: userIdRange)
                }

                // Dim disabled subscriptions
                if !isEnabled {
                    attributedTitle.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: 0, length: attributedTitle.length))
                }

                subItem.attributedTitle = attributedTitle

                // Add context menu with toggle and delete options
                let contextMenu = NSMenu()

                // Toggle option (Enable/Disable based on current state)
                let toggleTitle = isEnabled ? "Disable" : "Enable"
                let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleSubscription(_:)), keyEquivalent: "")
                toggleItem.target = self
                toggleItem.representedObject = userId
                contextMenu.addItem(toggleItem)

                // Delete option
                let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteSubscription(_:)), keyEquivalent: "")
                deleteItem.target = self
                deleteItem.representedObject = userId
                contextMenu.addItem(deleteItem)

                subItem.submenu = contextMenu

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

        // Defer menu update to avoid crash when updating menu while it's active
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusItemTitle()
            self?.updateMenu()
        }
    }

    @objc private func toggleUsernames() {
        showUsernames.toggle()
    }

    @objc private func toggleSubscription(_ sender: NSMenuItem) {
        if let userId = sender.representedObject as? String {
            cursorManager.toggleSubscription(userId)

            // Defer menu update to avoid crash when updating menu while it's active
            DispatchQueue.main.async { [weak self] in
                self?.updateStatusItemTitle()
                self?.updateMenu()
            }
        }
    }

    @objc private func deleteSubscription(_ sender: NSMenuItem) {
        if let userId = sender.representedObject as? String {
            cursorManager.deleteSubscription(userId)

            // Defer menu update to avoid crash when updating menu while it's active
            DispatchQueue.main.async { [weak self] in
                self?.updateStatusItemTitle()
                self?.updateMenu()
            }
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

                // Defer menu update for consistency
                DispatchQueue.main.async { [weak self] in
                    self?.updateStatusItemTitle()
                    self?.updateMenu()
                }
            }
        }
    }
    
    @objc private func showSettings() {
        let alert = NSAlert()
        alert.messageText = "Settings"
        alert.informativeText = "Configure PointerPals preferences and share your User ID."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Copy ID")
        alert.addButton(withTitle: "Close")

        // Create a container view (increased height for new controls)
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 210))

        var yPos: CGFloat = 190

        // Username section
        let usernameLabel = NSTextField(labelWithString: "Username:")
        usernameLabel.frame = NSRect(x: 0, y: yPos, width: 100, height: 17)
        usernameLabel.isBezeled = false
        usernameLabel.drawsBackground = false
        usernameLabel.isEditable = false
        usernameLabel.isSelectable = false

        yPos -= 26
        let usernameField = NSTextField(frame: NSRect(x: 0, y: yPos, width: 320, height: 24))
        usernameField.stringValue = networkManager.currentUsername
        usernameField.placeholderString = "Enter your username"

        // User ID section
        yPos -= 24
        let userIdLabel = NSTextField(labelWithString: "Your User ID:")
        userIdLabel.frame = NSRect(x: 0, y: yPos, width: 100, height: 17)
        userIdLabel.isBezeled = false
        userIdLabel.drawsBackground = false
        userIdLabel.isEditable = false
        userIdLabel.isSelectable = false

        yPos -= 26
        let userIdField = NSTextField(labelWithString: networkManager.currentUserId)
        userIdField.frame = NSRect(x: 0, y: yPos, width: 320, height: 24)
        userIdField.isBezeled = false
        userIdField.drawsBackground = false
        userIdField.isEditable = false
        userIdField.isSelectable = true
        userIdField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        userIdField.textColor = .secondaryLabelColor

        // Show Usernames checkbox
        yPos -= 28
        let usernamesCheckbox = NSButton(frame: NSRect(x: 0, y: yPos, width: 200, height: 18))
        usernamesCheckbox.setButtonType(.switch)
        usernamesCheckbox.title = "Show Usernames"
        usernamesCheckbox.state = showUsernames ? .on : .off

        // Cursor Size slider
        yPos -= 24
        let cursorSizeLabel = NSTextField(labelWithString: "Cursor Size:")
        cursorSizeLabel.frame = NSRect(x: 0, y: yPos, width: 100, height: 17)
        cursorSizeLabel.isBezeled = false
        cursorSizeLabel.drawsBackground = false
        cursorSizeLabel.isEditable = false
        cursorSizeLabel.isSelectable = false

        yPos -= 26
        let cursorSizeSlider = NSSlider(frame: NSRect(x: 0, y: yPos, width: 250, height: 24))
        cursorSizeSlider.minValue = 0.3  // 30% of natural size
        cursorSizeSlider.maxValue = 1.0  // 100% of natural size
        cursorSizeSlider.doubleValue = Double(cursorScale)
        cursorSizeSlider.isContinuous = true

        let sizeValueLabel = NSTextField(labelWithString: "\(Int(cursorScale * 100))%")
        sizeValueLabel.frame = NSRect(x: 260, y: yPos, width: 60, height: 24)
        sizeValueLabel.isBezeled = false
        sizeValueLabel.drawsBackground = false
        sizeValueLabel.isEditable = false
        sizeValueLabel.isSelectable = false
        sizeValueLabel.alignment = .right

        // Update label when slider changes
        cursorSizeSlider.target = self
        cursorSizeSlider.action = #selector(cursorSizeSliderChanged(_:))

        // Show Demo Cursor button
        yPos -= 32
        let demoCursorButton = NSButton(frame: NSRect(x: 0, y: yPos, width: 160, height: 28))
        demoCursorButton.title = demoCursorWindow == nil ? "Show Demo Cursor" : "Hide Demo Cursor"
        demoCursorButton.bezelStyle = .rounded
        demoCursorButton.target = self
        demoCursorButton.action = #selector(toggleDemoCursorFromSettings(_:))

        containerView.addSubview(usernameLabel)
        containerView.addSubview(usernameField)
        containerView.addSubview(userIdLabel)
        containerView.addSubview(userIdField)
        containerView.addSubview(usernamesCheckbox)
        containerView.addSubview(cursorSizeLabel)
        containerView.addSubview(cursorSizeSlider)
        containerView.addSubview(sizeValueLabel)
        containerView.addSubview(demoCursorButton)

        alert.accessoryView = containerView
        alert.window.initialFirstResponder = usernameField

        // Store slider and label references for updates
        alert.window.contentView?.viewWithTag(999)?.removeFromSuperview()
        sizeValueLabel.tag = 999

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Save username
            let newUsername = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newUsername.isEmpty {
                networkManager.currentUsername = newUsername
            }

            // Save show usernames preference
            showUsernames = usernamesCheckbox.state == .on

            // Save cursor scale
            cursorScale = CGFloat(cursorSizeSlider.doubleValue)
        } else if response == .alertSecondButtonReturn {
            // Copy ID
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(networkManager.currentUserId, forType: .string)
        }
    }

    @objc private func cursorSizeSliderChanged(_ sender: NSSlider) {
        // Update the value label
        if let window = sender.window,
           let containerView = window.contentView?.subviews.first(where: { $0 is NSView }),
           let sizeLabel = containerView.subviews.first(where: { $0.tag == 999 }) as? NSTextField {
            sizeLabel.stringValue = "\(Int(sender.doubleValue * 100))%"
        }
    }

    @objc private func toggleDemoCursorFromSettings(_ sender: NSButton) {
        toggleDemoCursor()
        // Update button title
        sender.title = demoCursorWindow == nil ? "Show Demo Cursor" : "Hide Demo Cursor"
    }
    
    @objc private func toggleDemoCursor() {
        if demoCursorWindow != nil {
            stopDemoCursor()
        } else {
            startDemoCursor()
        }

        // Defer menu update to avoid crash when updating menu while it's active
        DispatchQueue.main.async { [weak self] in
            self?.updateMenu()
        }
    }

    private func startDemoCursor() {
        // Create demo cursor window
        demoCursorWindow = CursorWindow(userId: "demo")
        demoCursorWindow?.updateUsername("Hello")

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

        // Clear reference so menu updates
        demoCursorWindow = nil

        // Hide the window - it will deallocate naturally when all animation
        // completion handlers release their references
        // DO NOT call close() - this causes crashes when animation handlers
        // try to access the window after it's been explicitly closed
        window.orderOut(nil)

        // Update menu to show "Show Demo Cursor" again
        updateMenu()

        // Window will be deallocated automatically when:
        // 1. All NSAnimationContext completion handlers finish
        // 2. All animator() proxy references are released
        // 3. No other strong references remain
    }

    private func stopDemoCursor() {
        // User manually stopped, clean up immediately
        demoTimer?.invalidate()
        demoTimer = nil

        if let window = demoCursorWindow {
            demoCursorWindow = nil

            // Hide window - let it deallocate naturally when animations finish
            window.orderOut(nil)
        }

        // Note: updateMenu() is called by toggleDemoCursor() which calls this method
    }

    @objc private func quit() {
        stopDemoCursor()
        NSApplication.shared.terminate(nil)
    }
}
