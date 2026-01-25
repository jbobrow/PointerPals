//
//  WelcomeWindowController.swift
//  PointerPals
//
//  Created by Jonathan Bobrow on 1/24/26.
//

import Cocoa
import ServiceManagement

protocol WelcomeWindowDelegate: AnyObject {
    func welcomeWindowDidComplete(username: String, launchOnStartup: Bool)
}

class WelcomeWindowController: NSWindowController {

    // MARK: - Properties

    weak var delegate: WelcomeWindowDelegate?

    private var currentStep = 0
    private let totalSteps = 4

    private var enteredUsername = ""
    private var launchOnStartup = false
    private let pointerId: String

    // UI Elements
    private var stepIndicators: [NSView] = []
    private var contentContainer: NSView!
    private var backButton: NSButton!
    private var nextButton: NSButton!
    private var usernameField: NSTextField?

    // MARK: - Initialization

    init(pointerId: String, defaultUsername: String) {
        self.pointerId = pointerId
        self.enteredUsername = defaultUsername

        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to PointerPals"
        window.center()
        window.isMovableByWindowBackground = true

        super.init(window: window)

        setupUI()
        updateForCurrentStep()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        // Step indicators at the top
        let indicatorContainer = NSView(frame: NSRect(x: 0, y: 330, width: 480, height: 30))
        setupStepIndicators(in: indicatorContainer)
        contentView.addSubview(indicatorContainer)

        // Content container (main area)
        contentContainer = NSView(frame: NSRect(x: 40, y: 70, width: 400, height: 250))
        contentView.addSubview(contentContainer)

        // Navigation buttons at the bottom
        setupNavigationButtons(in: contentView)
    }

    private func setupStepIndicators(in container: NSView) {
        let dotSize: CGFloat = 8
        let dotSpacing: CGFloat = 16
        let totalWidth = CGFloat(totalSteps) * dotSize + CGFloat(totalSteps - 1) * dotSpacing
        let startX = (container.bounds.width - totalWidth) / 2

        for i in 0..<totalSteps {
            let dot = NSView(frame: NSRect(
                x: startX + CGFloat(i) * (dotSize + dotSpacing),
                y: (container.bounds.height - dotSize) / 2,
                width: dotSize,
                height: dotSize
            ))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = dotSize / 2
            dot.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            container.addSubview(dot)
            stepIndicators.append(dot)
        }
    }

    private func setupNavigationButtons(in contentView: NSView) {
        // Back button
        backButton = NSButton(title: "Back", target: self, action: #selector(backButtonClicked))
        backButton.bezelStyle = .rounded
        backButton.frame = NSRect(x: 40, y: 20, width: 80, height: 32)
        contentView.addSubview(backButton)

        // Next/Done button
        nextButton = NSButton(title: "Next", target: self, action: #selector(nextButtonClicked))
        nextButton.bezelStyle = .rounded
        nextButton.keyEquivalent = "\r"
        nextButton.frame = NSRect(x: 360, y: 20, width: 80, height: 32)
        contentView.addSubview(nextButton)
    }

    // MARK: - Step Management

    private func updateForCurrentStep() {
        // Update step indicators
        for (index, dot) in stepIndicators.enumerated() {
            if index == currentStep {
                dot.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            } else if index < currentStep {
                dot.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
            } else {
                dot.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            }
        }

        // Update buttons
        backButton.isHidden = currentStep == 0
        nextButton.title = currentStep == totalSteps - 1 ? "Get Started" : "Next"

        // Update content
        clearContentContainer()

        switch currentStep {
        case 0:
            showWelcomeStep()
        case 1:
            showPointerIdStep()
        case 2:
            showLaunchOnStartupStep()
        case 3:
            showReadyStep()
        default:
            break
        }
    }

    private func clearContentContainer() {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        usernameField = nil
    }

    // MARK: - Step Views

    private func showWelcomeStep() {
        // Icon/Emoji
        let iconLabel = NSTextField(labelWithString: "👋")
        iconLabel.font = NSFont.systemFont(ofSize: 48)
        iconLabel.alignment = .center
        iconLabel.frame = NSRect(x: 0, y: 180, width: 400, height: 60)
        contentContainer.addSubview(iconLabel)

        // Title
        let titleLabel = NSTextField(labelWithString: "Welcome to PointerPals!")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.frame = NSRect(x: 0, y: 140, width: 400, height: 32)
        contentContainer.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Share your cursor with friends and collaborate in real-time.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.isBezeled = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.isEditable = false
        subtitleLabel.frame = NSRect(x: 0, y: 110, width: 400, height: 24)
        contentContainer.addSubview(subtitleLabel)

        // Username label
        let usernameLabel = NSTextField(labelWithString: "Give your Pointer a name:")
        usernameLabel.font = NSFont.systemFont(ofSize: 13)
        usernameLabel.alignment = .center
        usernameLabel.isBezeled = false
        usernameLabel.drawsBackground = false
        usernameLabel.isEditable = false
        usernameLabel.frame = NSRect(x: 50, y: 65, width: 300, height: 20)
        contentContainer.addSubview(usernameLabel)

        // Username text field
        let field = NSTextField(frame: NSRect(x: 100, y: 30, width: 200, height: 28))
        field.placeholderString = "Enter your name"
        field.stringValue = enteredUsername
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 14)
        field.bezelStyle = .roundedBezel
        contentContainer.addSubview(field)
        usernameField = field

        // Make the text field first responder
        window?.makeFirstResponder(field)
    }

    private func showPointerIdStep() {
        // Icon
        let iconLabel = NSTextField(labelWithString: "🎫")
        iconLabel.font = NSFont.systemFont(ofSize: 48)
        iconLabel.alignment = .center
        iconLabel.frame = NSRect(x: 0, y: 180, width: 400, height: 60)
        contentContainer.addSubview(iconLabel)

        // Title
        let displayName = enteredUsername.isEmpty ? "User" : enteredUsername
        let titleLabel = NSTextField(labelWithString: "Welcome, \(displayName)!")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.frame = NSRect(x: 0, y: 140, width: 400, height: 32)
        contentContainer.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Here's your Pointer ID to share with your Pals:")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.isBezeled = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.isEditable = false
        subtitleLabel.frame = NSRect(x: 0, y: 110, width: 400, height: 24)
        contentContainer.addSubview(subtitleLabel)

        // Pointer ID display
        let idField = NSTextField(labelWithString: pointerId)
        idField.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        idField.alignment = .center
        idField.isBezeled = true
        idField.drawsBackground = true
        idField.backgroundColor = .controlBackgroundColor
        idField.isEditable = false
        idField.isSelectable = true
        idField.frame = NSRect(x: 50, y: 55, width: 300, height: 28)
        contentContainer.addSubview(idField)

        // Copy button
        let copyButton = NSButton(title: "Copy Pointer ID", target: self, action: #selector(copyPointerId))
        copyButton.bezelStyle = .rounded
        copyButton.frame = NSRect(x: 140, y: 15, width: 120, height: 32)
        contentContainer.addSubview(copyButton)
    }

    private func showLaunchOnStartupStep() {
        // Icon
        let iconLabel = NSTextField(labelWithString: "🚀")
        iconLabel.font = NSFont.systemFont(ofSize: 48)
        iconLabel.alignment = .center
        iconLabel.frame = NSRect(x: 0, y: 180, width: 400, height: 60)
        contentContainer.addSubview(iconLabel)

        // Title
        let titleLabel = NSTextField(labelWithString: "Launch on Startup?")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.frame = NSRect(x: 0, y: 140, width: 400, height: 32)
        contentContainer.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Would you like PointerPals to launch\nautomatically when you start your computer?")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.isBezeled = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.isEditable = false
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.frame = NSRect(x: 0, y: 90, width: 400, height: 44)
        contentContainer.addSubview(subtitleLabel)

        // Checkbox
        let checkbox = NSButton(checkboxWithTitle: "Yes, launch PointerPals on startup", target: self, action: #selector(launchOnStartupToggled(_:)))
        checkbox.state = launchOnStartup ? .on : .off
        checkbox.font = NSFont.systemFont(ofSize: 14)
        checkbox.frame = NSRect(x: 100, y: 45, width: 250, height: 24)
        contentContainer.addSubview(checkbox)
    }

    private func showReadyStep() {
        // SF Symbol icon
        let iconSize: CGFloat = 48
        let iconImageView = NSImageView(frame: NSRect(x: (400 - iconSize) / 2, y: 185, width: iconSize, height: iconSize))
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.contentTintColor = .labelColor  // White in dark mode, black in light mode

        if let symbolImage = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "Cursor with motion lines") {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
            iconImageView.image = symbolImage.withSymbolConfiguration(config)

            // Add "draw" effect animation (appears layer by layer)
            if #available(macOS 14.0, *) {
                iconImageView.addSymbolEffect(.appear.byLayer)
            }
        }
        contentContainer.addSubview(iconImageView)

        // Title
        let titleLabel = NSTextField(labelWithString: "You're All Set!")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.frame = NSRect(x: 0, y: 140, width: 400, height: 32)
        contentContainer.addSubview(titleLabel)

        // Instructions
        let instructionsLabel = NSTextField(labelWithString: "PointerPals lives in your menu bar.\nClick the icon to add Pals and manage settings.")
        instructionsLabel.font = NSFont.systemFont(ofSize: 14)
        instructionsLabel.textColor = .secondaryLabelColor
        instructionsLabel.alignment = .center
        instructionsLabel.isBezeled = false
        instructionsLabel.drawsBackground = false
        instructionsLabel.isEditable = false
        instructionsLabel.maximumNumberOfLines = 3
        instructionsLabel.frame = NSRect(x: 0, y: 80, width: 400, height: 54)
        contentContainer.addSubview(instructionsLabel)

        // Menu bar hint with arrow
        let hintLabel = NSTextField(labelWithString: "Look for the pointer icon in your menu bar ↗")
        hintLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .center
        hintLabel.isBezeled = false
        hintLabel.drawsBackground = false
        hintLabel.isEditable = false
        hintLabel.frame = NSRect(x: 0, y: 35, width: 400, height: 20)
        contentContainer.addSubview(hintLabel)
    }

    // MARK: - Actions

    @objc private func backButtonClicked() {
        if currentStep > 0 {
            // Save username before going back from step 1
            if currentStep == 1, let field = usernameField {
                saveUsername(from: field)
            }
            currentStep -= 1
            updateForCurrentStep()
        }
    }

    @objc private func nextButtonClicked() {
        // Save data from current step
        if currentStep == 0, let field = usernameField {
            saveUsername(from: field)
        }

        if currentStep < totalSteps - 1 {
            currentStep += 1
            updateForCurrentStep()
        } else {
            // Complete the setup
            completeSetup()
        }
    }

    private func saveUsername(from field: NSTextField) {
        var username = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.count > PointerPalsConfig.maxUsernameLength {
            username = String(username.prefix(PointerPalsConfig.maxUsernameLength))
        }
        enteredUsername = username
    }

    @objc private func copyPointerId() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pointerId, forType: .string)

        // Show brief visual feedback
        if let button = contentContainer.subviews.compactMap({ $0 as? NSButton }).first(where: { $0.title == "Copy Pointer ID" }) {
            let originalTitle = button.title
            button.title = "Copied!"
            button.isEnabled = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                button.title = originalTitle
                button.isEnabled = true
            }
        }
    }

    @objc private func launchOnStartupToggled(_ sender: NSButton) {
        launchOnStartup = sender.state == .on
    }

    private func completeSetup() {
        let finalUsername = enteredUsername.isEmpty ? "User" : enteredUsername
        delegate?.welcomeWindowDidComplete(username: finalUsername, launchOnStartup: launchOnStartup)
        close()
    }

    // MARK: - Public Methods

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
