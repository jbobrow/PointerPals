//
//  PointerPalsApp.swift
//  PointerPals
//
//  Created by Jonathan Bobrow on 1/14/26.
//

import SwiftUI
import Combine
import ServiceManagement

@main
struct PointerPalsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    private var statusItem: NSStatusItem!
    private var cursorPublisher: CursorPublisher!
    private var cursorManager: CursorManager!
    private var networkManager: NetworkManager!
    private var cancellables = Set<AnyCancellable>()
    private var demoCursorWindow: CursorWindow?
    private var demoTimer: Timer?
    private weak var demoButton: NSButton?  // Weak reference to demo button for updates
    private var originalUsername: String = ""  // Store original username for comparison
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

        // Auto-start publishing when app launches
        cursorPublisher.startPublishing()

        // Check for first launch and prompt for launch on startup
        checkFirstLaunch()
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

        let subCount = cursorManager.activeSubscriptionsCount

        // Always show publishing icon since app is always publishing
        let iconName = PointerPalsConfig.publishingIcon

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
            button.title = "📍"
            if PointerPalsConfig.showSubscriptionCount {
                button.title += " \(subCount)"
            }
        }
    }
    
    private func updateMenu() {
        let menu = NSMenu()

        // Add a Pal (moved to top)
        let addSubItem = NSMenuItem(
            title: "Add a Pal...",
            action: #selector(showAddSubscription),
            keyEquivalent: "a"
        )
        addSubItem.target = self
        menu.addItem(addSubItem)

        menu.addItem(NSMenuItem.separator())

        // My PointerPals section (renamed from Subscriptions)
        let subsHeader = NSMenuItem(title: "My PointerPals", action: nil, keyEquivalent: "")
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
        alert.messageText = "Add a Pal"
        alert.informativeText = "Enter your pal's Pal ID:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.placeholderString = "pal_8675309"
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
        alert.messageText = "Pointer Pals"
        alert.informativeText = ""
        alert.addButton(withTitle: "Done")

        // Create a container view with proper dimensions
        let containerHeight: CGFloat = 330
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: containerHeight))

        var yPos: CGFloat = containerHeight
        
        // Username section with inline save
        let usernameLabel = NSTextField(labelWithString: "Username:")
        usernameLabel.frame = NSRect(x: 20, y: yPos - 20, width: 80, height: 17)
        usernameLabel.isBezeled = false
        usernameLabel.drawsBackground = false
        usernameLabel.isEditable = false
        usernameLabel.isSelectable = false
        usernameLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)

        let usernameField = NSTextField(frame: NSRect(x: 20, y: yPos - 46, width: 250, height: 24))
        usernameField.stringValue = networkManager.currentUsername
        usernameField.placeholderString = "Enter your username"
        usernameField.font = NSFont.systemFont(ofSize: 13)
        usernameField.delegate = self

        // Store original username for comparison
        originalUsername = networkManager.currentUsername

        let saveUsernameButton = NSButton(frame: NSRect(x: 280, y: yPos - 46, width: 80, height: 24))
        saveUsernameButton.title = "Save"
        saveUsernameButton.bezelStyle = .rounded
        saveUsernameButton.target = self
        saveUsernameButton.action = #selector(saveUsernameFromSettings(_:))
        saveUsernameButton.isEnabled = false  // Disabled initially since username hasn't changed
        saveUsernameButton.tag = 997  // Tag for finding the button later

        yPos -= 76

        // Pal ID section
        let userIdLabel = NSTextField(labelWithString: "Your Pal ID:")
        userIdLabel.frame = NSRect(x: 20, y: yPos, width: 100, height: 17)
        userIdLabel.isBezeled = false
        userIdLabel.drawsBackground = false
        userIdLabel.isEditable = false
        userIdLabel.isSelectable = false
        userIdLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
                
        let userIdField = NSTextField(labelWithString: networkManager.currentUserId)
        userIdField.frame = NSRect(x: 110, y: yPos - 4, width: 220, height: 20)
        userIdField.isBezeled = false
        userIdField.drawsBackground = false
        userIdField.isEditable = false
        userIdField.isSelectable = true
        userIdField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        userIdField.textColor = .secondaryLabelColor
        userIdField.alignment = .left

        yPos -= 36
        let copyIdButton = NSButton(frame: NSRect(x: 20, y: yPos, width: 340, height: 32))
        copyIdButton.title = "Copy Pal ID to Share with Friends"
        copyIdButton.bezelStyle = .rounded
        if #available(macOS 11.0, *) {
            copyIdButton.hasDestructiveAction = false
        }
        copyIdButton.target = self
        copyIdButton.action = #selector(copyUserIdFromSettings)

        yPos -= 28

        // Visual separator
        let separator = NSBox(frame: NSRect(x: 20, y: yPos, width: 340, height: 1))
        separator.boxType = .separator

        yPos -= 30

        // Display Preferences header with inline Demo button
        let preferencesHeader = NSTextField(labelWithString: "Display Preferences")
        preferencesHeader.frame = NSRect(x: 20, y: yPos, width: 200, height: 17)
        preferencesHeader.isBezeled = false
        preferencesHeader.drawsBackground = false
        preferencesHeader.isEditable = false
        preferencesHeader.isSelectable = false
        preferencesHeader.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        // Demo button (inline, right-aligned)
        let demoCursorButton = NSButton(frame: NSRect(x: 290, y: yPos - 2, width: 70, height: 24))
        demoCursorButton.title = "Demo"
        demoCursorButton.bezelStyle = .rounded
        demoCursorButton.target = self
        demoCursorButton.action = #selector(toggleDemoCursorFromSettings(_:))

        // Store weak reference for updates when animation completes
        self.demoButton = demoCursorButton

        yPos -= 30

        // Show Usernames switch
        let usernamesCheckbox = NSButton(frame: NSRect(x: 20, y: yPos, width: 200, height: 18))
        usernamesCheckbox.setButtonType(.switch)
        usernamesCheckbox.title = "Show Usernames"
        usernamesCheckbox.state = showUsernames ? .on : .off
        usernamesCheckbox.target = self
        usernamesCheckbox.action = #selector(toggleUsernamesFromSettings(_:))
        usernamesCheckbox.font = NSFont.systemFont(ofSize: 13)

        yPos -= 34

        // Cursor Size slider
        let cursorSizeLabel = NSTextField(labelWithString: "Cursor Size:")
        cursorSizeLabel.frame = NSRect(x: 20, y: yPos, width: 80, height: 17)
        cursorSizeLabel.isBezeled = false
        cursorSizeLabel.drawsBackground = false
        cursorSizeLabel.isEditable = false
        cursorSizeLabel.isSelectable = false
        cursorSizeLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)

        yPos -= 26
        let cursorSizeSlider = NSSlider(frame: NSRect(x: 20, y: yPos, width: 280, height: 24))
        cursorSizeSlider.minValue = 0.5
        cursorSizeSlider.maxValue = 1.0
        cursorSizeSlider.doubleValue = Double(cursorScale)
        cursorSizeSlider.numberOfTickMarks = 5
        cursorSizeSlider.allowsTickMarkValuesOnly = true
        cursorSizeSlider.isContinuous = false
        cursorSizeSlider.target = self
        cursorSizeSlider.action = #selector(cursorSizeSliderChanged(_:))

        let sizeValueLabel = NSTextField(labelWithString: "\(Int(cursorScale * 100))%")
        sizeValueLabel.frame = NSRect(x: 310, y: yPos + 2, width: 50, height: 20)
        sizeValueLabel.isBezeled = false
        sizeValueLabel.drawsBackground = false
        sizeValueLabel.isEditable = false
        sizeValueLabel.isSelectable = false
        sizeValueLabel.alignment = .right
        sizeValueLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        sizeValueLabel.textColor = .secondaryLabelColor
        sizeValueLabel.tag = 999

        yPos -= 36

        // Launch on Startup checkbox
        let launchOnStartupCheckbox = NSButton(frame: NSRect(x: 20, y: yPos, width: 340, height: 18))
        launchOnStartupCheckbox.setButtonType(.switch)
        launchOnStartupCheckbox.title = "Launch PointerPals on Startup"
        launchOnStartupCheckbox.state = isLaunchOnStartupEnabled() ? .on : .off
        launchOnStartupCheckbox.target = self
        launchOnStartupCheckbox.action = #selector(toggleLaunchOnStartup(_:))
        launchOnStartupCheckbox.font = NSFont.systemFont(ofSize: 13)

        yPos -= 40

        // Custom Server button
        let customServerButton = NSButton(frame: NSRect(x: 20, y: yPos, width: 340, height: 28))
        customServerButton.title = "Configure Server..."
        customServerButton.bezelStyle = .rounded
        customServerButton.target = self
        customServerButton.action = #selector(showServerSettings)

        containerView.addSubview(usernameLabel)
        containerView.addSubview(usernameField)
        containerView.addSubview(saveUsernameButton)
        containerView.addSubview(userIdLabel)
        containerView.addSubview(userIdField)
        containerView.addSubview(copyIdButton)
        containerView.addSubview(separator)
        containerView.addSubview(preferencesHeader)
        containerView.addSubview(usernamesCheckbox)
        containerView.addSubview(cursorSizeLabel)
        containerView.addSubview(cursorSizeSlider)
        containerView.addSubview(sizeValueLabel)
        containerView.addSubview(demoCursorButton)
        containerView.addSubview(launchOnStartupCheckbox)
        containerView.addSubview(customServerButton)

        alert.accessoryView = containerView
        alert.window.initialFirstResponder = usernameField

        // Store reference for username field updates
        usernameField.tag = 998

        alert.runModal()

        // Check for unsaved changes after dialog closes
        let currentText = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasUnsavedChanges = !currentText.isEmpty && currentText != originalUsername

        if hasUnsavedChanges {
            // Show confirmation dialog for unsaved changes
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Unsaved Changes"

            // Create attributed text with the new username in bold
            let message = "Save username as "
            let usernameText = "\"\(currentText)\""
            let question = "?"

            let attributedString = NSMutableAttributedString()

            // Regular text
            attributedString.append(NSAttributedString(string: message, attributes: [
                .font: NSFont.systemFont(ofSize: 13)
            ]))

            // Bold username
            attributedString.append(NSAttributedString(string: usernameText, attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13)
            ]))

            // Regular text
            attributedString.append(NSAttributedString(string: question, attributes: [
                .font: NSFont.systemFont(ofSize: 13)
            ]))

            // Create a custom label for the message
            let messageLabel = NSTextField(labelWithAttributedString: attributedString)
            messageLabel.frame = NSRect(x: 0, y: 0, width: 260, height: 20)
            messageLabel.alignment = .left

            // Set as accessory view
            confirmAlert.accessoryView = messageLabel

            confirmAlert.addButton(withTitle: "Save")
            confirmAlert.addButton(withTitle: "Discard")
            confirmAlert.alertStyle = .warning

            let response = confirmAlert.runModal()
            if response == .alertFirstButtonReturn {
                // Save the username
                if currentText.count <= PointerPalsConfig.maxUsernameLength {
                    networkManager.currentUsername = currentText
                    originalUsername = currentText
                }
            }
            // If discard, do nothing
        }
    }

    @objc private func saveUsernameFromSettings(_ sender: NSButton) {
        // Find the username field in the same container view (superview of button)
        guard let containerView = sender.superview,
              let usernameField = containerView.subviews.first(where: { $0.tag == 998 }) as? NSTextField else {
            return
        }

        let newUsername = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate username: not empty and within length limit
        guard !newUsername.isEmpty,
              newUsername.count <= PointerPalsConfig.maxUsernameLength else {
            return
        }

        networkManager.currentUsername = newUsername

        // Update original username and disable save button after successful save
        originalUsername = newUsername
        sender.isEnabled = false
    }

    @objc private func showServerSettings() {
        let alert = NSAlert()
        alert.messageText = "Configure Custom Server"
        alert.informativeText = ""
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        // Create container view with better spacing
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 110))
        var yPos: CGFloat = 110

        // Server Address label
        let serverURLLabel = NSTextField(labelWithString: "Server Address:")
        serverURLLabel.frame = NSRect(x: 20, y: yPos - 20, width: 110, height: 17)
        serverURLLabel.isBezeled = false
        serverURLLabel.drawsBackground = false
        serverURLLabel.isEditable = false
        serverURLLabel.isSelectable = false
        serverURLLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)

        yPos -= 46

        // Server Address field
        let serverURLField = NSTextField(frame: NSRect(x: 20, y: yPos, width: 340, height: 24))
        serverURLField.stringValue = PointerPalsConfig.customServerURL ?? PointerPalsConfig.defaultServerURL
        serverURLField.placeholderString = PointerPalsConfig.defaultServerURL
        serverURLField.font = NSFont.systemFont(ofSize: 13)
        serverURLField.tag = 995

        yPos -= 36

        // Reset button (left-aligned with field)
        let resetButton = NSButton(frame: NSRect(x: 20, y: yPos, width: 160, height: 28))
        resetButton.title = "Reset to Default"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetServerURLInModal(_:))

        yPos -= 8

        // Info label (positioned below reset button with minimal spacing)
        let infoLabel = NSTextField(labelWithString: "Requires app restart to take effect")
        infoLabel.frame = NSRect(x: 20, y: yPos - 10, width: 340, height: 14)
        infoLabel.isBezeled = false
        infoLabel.drawsBackground = false
        infoLabel.isEditable = false
        infoLabel.isSelectable = false
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.alignment = .left

        containerView.addSubview(serverURLLabel)
        containerView.addSubview(serverURLField)
        containerView.addSubview(resetButton)
        containerView.addSubview(infoLabel)

        alert.accessoryView = containerView
        alert.window.initialFirstResponder = serverURLField

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Save button clicked
            let urlString = serverURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

            // Validate URL format
            guard PointerPalsConfig.isValidServerURL(urlString) else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Server URL"
                errorAlert.informativeText = "Please enter a valid WebSocket URL (ws:// or wss://)"
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
                return
            }

            // Save the custom URL
            PointerPalsConfig.setCustomServerURL(urlString)

            // Show success message
            let successAlert = NSAlert()
            successAlert.messageText = "Server Address Saved"
            successAlert.informativeText = "Please restart the app for the change to take effect."
            successAlert.alertStyle = .informational
            successAlert.addButton(withTitle: "OK")
            successAlert.runModal()
        }
        // If Cancel was clicked, do nothing
    }

    @objc private func resetServerURLInModal(_ sender: NSButton) {
        guard let containerView = sender.superview,
              let serverURLField = containerView.subviews.first(where: { $0.tag == 995 }) as? NSTextField else {
            return
        }

        // Reset field to default
        serverURLField.stringValue = PointerPalsConfig.defaultServerURL
    }


    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField.tag == 998 else { return }

        // Enforce maximum username length
        if textField.stringValue.count > PointerPalsConfig.maxUsernameLength {
            // Truncate to max length
            let truncated = String(textField.stringValue.prefix(PointerPalsConfig.maxUsernameLength))
            textField.stringValue = truncated

            // Provide audio feedback that limit was reached
            NSSound.beep()
        }

        // Find the save button in the same container view (superview of textField)
        guard let containerView = textField.superview,
              let saveButton = containerView.subviews.first(where: { $0.tag == 997 }) as? NSButton else {
            return
        }

        let currentText = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasChanged = currentText != originalUsername && !currentText.isEmpty
        saveButton.isEnabled = hasChanged
    }

    @objc private func copyUserIdFromSettings() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(networkManager.currentUserId, forType: .string)
    }

    @objc private func toggleUsernamesFromSettings(_ sender: NSButton) {
        showUsernames = sender.state == .on
    }

    @objc private func cursorSizeSliderChanged(_ sender: NSSlider) {
        let newScale = CGFloat(sender.doubleValue)
        cursorScale = newScale

        // Update the value label
        if let window = sender.window,
           let sizeLabel = window.contentView?.viewWithTag(999) as? NSTextField {
            sizeLabel.stringValue = "\(Int(newScale * 100))%"
        }
    }

    @objc private func toggleDemoCursorFromSettings(_ sender: NSButton) {
        toggleDemoCursor()
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
        // Create demo cursor window with current cursor scale
        demoCursorWindow = CursorWindow(userId: "demo", cursorScale: cursorScale)
        demoCursorWindow?.updateUsername("Hello")

        let duration: TimeInterval = 6.0 // Total animation duration in seconds
        let fps: Double = 60.0
        let totalFrames = Int(duration * fps)
        var currentFrame = 0
        var hasStartedFadeOut = false // Track if we've already started fading out

        // Get screen dimensions to calculate perfect circle
        guard let screen = NSScreen.main else { return }
        let screenWidth = screen.frame.width
        let screenHeight = screen.frame.height
        let aspectRatio = screenWidth / screenHeight

        // Set initial position
        demoCursorWindow?.updatePosition(x: 0.5, y: 0.3)

        // Start animation after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            self.demoCursorWindow?.fadeIn()

            // Create timer that works even during modal dialogs
            let timer = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak self] timer in
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
                // Use smaller radius in Y to account for aspect ratio and make perfect circle
                let radiusY = 0.2
                let radiusX = radiusY / aspectRatio
                let centerX = 0.5
                let centerY = 0.5

                // Calculate position on circle
                let x = centerX + (radiusX * cos(angle))
                let y = centerY + (radiusY * sin(angle))

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
                        self?.updateDemoButtonTitle()
                    }
                }
            }

            // Add timer to run loop with common mode so it works during modal dialogs
            RunLoop.current.add(timer, forMode: .common)
            self.demoTimer = timer
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

    private func updateDemoButtonTitle() {
        // Button now has static "Demo Cursor" title - no update needed
    }

    @objc private func quit() {
        stopDemoCursor()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Launch on Startup

    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "PointerPals_HasLaunchedBefore")

        if !hasLaunchedBefore {
            // Mark as launched
            UserDefaults.standard.set(true, forKey: "PointerPals_HasLaunchedBefore")

            // Show first launch prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showFirstLaunchPrompt()
            }
        }
    }

    private func showFirstLaunchPrompt() {
        // Step 1: Ask for username
        let usernameAlert = NSAlert()
        usernameAlert.messageText = "Welcome to PointerPals!"
        usernameAlert.informativeText = "Give your Personal Pointer a name to share with Pals:"
        usernameAlert.addButton(withTitle: "Continue")
        usernameAlert.addButton(withTitle: "Skip")
        usernameAlert.alertStyle = .informational

        let usernameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        usernameField.placeholderString = "Enter your name"
        usernameAlert.accessoryView = usernameField
        usernameAlert.window.initialFirstResponder = usernameField

        let response = usernameAlert.runModal()

        var username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if response == .alertFirstButtonReturn && !username.isEmpty {
            // Enforce max length
            if username.count > PointerPalsConfig.maxUsernameLength {
                username = String(username.prefix(PointerPalsConfig.maxUsernameLength))
            }
            networkManager.currentUsername = username
        } else {
            username = networkManager.currentUsername
        }

        // Step 2: Show welcome dialog with Pal ID
        showWelcomeDialog(username: username)

        // Step 3: Ask about launch on startup
        showLaunchOnStartupPrompt()
    }

    private func showWelcomeDialog(username: String) {
        let alert = NSAlert()
        alert.messageText = "Welcome \(username)!"
        alert.informativeText = "Here is your Pal ID to share with your PointerPals:"
        alert.addButton(withTitle: "Copy Pal ID")
        alert.addButton(withTitle: "Done")
        alert.alertStyle = .informational

        // Create container for Pal ID display
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 40))

        let palIdField = NSTextField(labelWithString: networkManager.currentUserId)
        palIdField.frame = NSRect(x: 0, y: 10, width: 300, height: 20)
        palIdField.isBezeled = true
        palIdField.drawsBackground = true
        palIdField.backgroundColor = .controlBackgroundColor
        palIdField.isEditable = false
        palIdField.isSelectable = true
        palIdField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        palIdField.alignment = .center

        containerView.addSubview(palIdField)
        alert.accessoryView = containerView

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(networkManager.currentUserId, forType: .string)

            // Show brief confirmation
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Pal ID Copied!"
            confirmAlert.informativeText = "Share it with your friends to connect."
            confirmAlert.addButton(withTitle: "OK")
            confirmAlert.alertStyle = .informational
            confirmAlert.runModal()
        }
    }

    private func showLaunchOnStartupPrompt() {
        let alert = NSAlert()
        alert.messageText = "One More Thing..."
        alert.informativeText = "Would you like PointerPals to launch automatically when you start your computer?"
        alert.addButton(withTitle: "Yes, Launch on Startup")
        alert.addButton(withTitle: "No Thanks")
        alert.alertStyle = .informational

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            setLaunchOnStartup(true)
        }
    }

    private func setLaunchOnStartup(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            // Use modern ServiceManagement framework
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                UserDefaults.standard.set(enabled, forKey: "PointerPals_LaunchOnStartup")
            } catch {
                print("Failed to \(enabled ? "register" : "unregister") launch at login: \(error.localizedDescription)")
            }
        } else {
            // Fallback for older macOS versions using deprecated SMLoginItemSetEnabled
            #if canImport(ServiceManagement)
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.jonathanbobrow.PointerPals"
            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled)
            if success {
                UserDefaults.standard.set(enabled, forKey: "PointerPals_LaunchOnStartup")
            }
            #endif
        }
    }

    private func isLaunchOnStartupEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            // Check actual registration status from ServiceManagement
            return SMAppService.mainApp.status == .enabled
        } else {
            // Fallback to stored preference for older macOS
            return UserDefaults.standard.bool(forKey: "PointerPals_LaunchOnStartup")
        }
    }

    @objc private func toggleLaunchOnStartup(_ sender: NSButton) {
        let enabled = sender.state == .on
        setLaunchOnStartup(enabled)
    }
}
