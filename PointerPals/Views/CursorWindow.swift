import Cocoa
import SwiftUI

class CursorWindow: NSWindow {
    private let cursorImageView: NSImageView
    private let usernameLabel: NSTextField
    private let userId: String
    private var currentUsername: String?

    init(userId: String, cursorScale: CGFloat = PointerPalsConfig.defaultCursorScale) {
        self.userId = userId

        // Get the system arrow cursor image and use its natural size
        let cursorImage = NSCursor.arrow.image
        let naturalCursorSize = cursorImage.size

        // Scale cursor to desired size (0.5 = half size, 0.75 = 75% size, etc.)
        let scaledCursorSize = CGSize(
            width: naturalCursorSize.width * cursorScale,
            height: naturalCursorSize.height * cursorScale
        )

        // Create cursor image view
        cursorImageView = NSImageView(frame: NSRect(origin: .zero, size: scaledCursorSize))
        cursorImageView.image = cursorImage

        // Create username label
        usernameLabel = NSTextField(labelWithString: "")
        usernameLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        usernameLabel.backgroundColor = NSColor.black
        usernameLabel.isBordered = false
        usernameLabel.isEditable = false
        usernameLabel.alignment = .center
        usernameLabel.wantsLayer = true
        usernameLabel.layer?.cornerRadius = 4
        usernameLabel.layer?.masksToBounds = true

        // Calculate window size to accommodate cursor and label
        let labelHeight: CGFloat = 11
        let windowWidth = max(scaledCursorSize.width, 100)
        let windowHeight = scaledCursorSize.height + labelHeight
        let windowSize = CGSize(width: windowWidth, height: windowHeight)

        // Initialize window with calculated size
        super.init(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = PointerPalsConfig.ignoreMouseEvents
        self.level = PointerPalsConfig.cursorWindowLevel

        if PointerPalsConfig.appearOnAllSpaces {
            self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        } else {
            self.collectionBehavior = [.stationary, .ignoresCycle]
        }

        // Position cursor above the username label
        cursorImageView.frame.origin = CGPoint(x: 0, y: 0)

        // Position username label at the bottom
        usernameLabel.frame = NSRect(x: 0, y: 0, width: windowWidth, height: labelHeight)

        // Add subviews to window
        if let contentView = self.contentView {
            contentView.addSubview(cursorImageView)
            contentView.addSubview(usernameLabel)
        }

        // Start hidden (will fade in on first update)
        self.alphaValue = 0.0

        // Show the window
        self.orderFrontRegardless()

        if PointerPalsConfig.debugLogging {
            print("Created cursor window for \(userId)")
        }
    }
    
    func updateUsername(_ username: String?) {
        if let username = username, !username.isEmpty {
            currentUsername = username

            // Create attributed string with outline
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.black,
                .strokeColor: NSColor.white,
                .strokeWidth: -3.0  // Negative for fill + stroke, positive for stroke only
            ]

            usernameLabel.attributedStringValue = NSAttributedString(string: username, attributes: attributes)
            usernameLabel.isHidden = false
        } else {
            usernameLabel.isHidden = true
        }
    }

    func setUsernameVisibility(_ visible: Bool) {
        if visible {
            // Show username if we have one
            if let username = currentUsername, !username.isEmpty {
                // Create attributed string with outline
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: NSColor.black,
                    .strokeColor: NSColor.white,
                    .strokeWidth: -3.0  // Negative for fill + stroke
                ]

                usernameLabel.attributedStringValue = NSAttributedString(string: username, attributes: attributes)
                usernameLabel.isHidden = false
            }
        } else {
            // Always hide username
            usernameLabel.isHidden = true
        }
    }

    func updatePosition(x: Double, y: Double) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Convert normalized coordinates to screen coordinates
        let screenX = x * screenFrame.width
        let screenY = y * screenFrame.height

        // Offset the window position to account for cursor's position within the window
        // The cursor is positioned at labelHeight (18) from the bottom of the window
        // This allows the cursor to reach all the way to the bottom of the screen
        let labelHeight: CGFloat = 18
        let targetOrigin = CGPoint(x: screenX, y: screenY - labelHeight)

        // Set position immediately first
        self.setFrameOrigin(targetOrigin)

        // Then optionally animate for smoothness
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = PointerPalsConfig.cursorAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrameOrigin(targetOrigin)
        })
    }
    
    func fadeIn() {
        guard self.alphaValue < PointerPalsConfig.activeCursorOpacity else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = PointerPalsConfig.fadeInDuration
            self.animator().alphaValue = PointerPalsConfig.activeCursorOpacity
        })
    }
    
    func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = PointerPalsConfig.fadeOutDuration
            self.animator().alphaValue = 0.0
        })
    }
    
    // Create a custom cursor image if system image is unavailable
    static func createCursorImage(size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw a simple arrow cursor shape
        let path = NSBezierPath()
        path.move(to: CGPoint(x: size.width * 0.0, y: size.height * 1.0))
        path.line(to: CGPoint(x: size.width * 0.0, y: size.height * 0.2))
        path.line(to: CGPoint(x: size.width * 0.3, y: size.height * 0.35))
        path.line(to: CGPoint(x: size.width * 0.55, y: size.height * 0.0))
        path.line(to: CGPoint(x: size.width * 0.78, y: size.height * 0.05))
        path.line(to: CGPoint(x: size.width * 0.55, y: size.height * 0.4))
        path.line(to: CGPoint(x: size.width * 0.9, y: size.height * 0.45))
        path.close()
        
        // Fill with white
        NSColor.black.setFill()
        path.fill()
        
        // Stroke with black
        NSColor.white.setStroke()
        path.lineWidth = 1
        path.stroke()
        
        image.unlockFocus()
        
        return image
    }
}

// MARK: - SwiftUI Preview Support

/// SwiftUI wrapper for previewing CursorWindow content
struct CursorWindowPreview: NSViewRepresentable {
    let showUsername: Bool
    let username: String

    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.3).cgColor

        // Get the system arrow cursor image and scale it
        let cursorImage = NSCursor.arrow.image
        let naturalCursorSize = cursorImage.size
        let cursorScale: CGFloat = 0.5
        let scaledCursorSize = CGSize(
            width: naturalCursorSize.width * cursorScale,
            height: naturalCursorSize.height * cursorScale
        )

        // Create cursor image view
        let cursorImageView = NSImageView(frame: NSRect(origin: .zero, size: scaledCursorSize))
        cursorImageView.image = cursorImage

        // Create username label
        let usernameLabel = NSTextField(labelWithString: "")
        usernameLabel.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        usernameLabel.isBordered = false
        usernameLabel.isEditable = false
        usernameLabel.alignment = .center
        usernameLabel.wantsLayer = true
        usernameLabel.layer?.cornerRadius = 4
        usernameLabel.layer?.masksToBounds = true

        // Create attributed string with outline
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.black,
            .strokeColor: NSColor.white,
            .strokeWidth: -3.0  // Negative for fill + stroke
        ]
        usernameLabel.attributedStringValue = NSAttributedString(string: username, attributes: attributes)

        let labelHeight: CGFloat = 18
        let windowWidth = max(scaledCursorSize.width, 100)

        // Position cursor above the username label
        cursorImageView.frame.origin = CGPoint(x: 0, y: labelHeight)

        // Position username label at the bottom
        usernameLabel.frame = NSRect(x: 0, y: 0, width: windowWidth, height: labelHeight)
        usernameLabel.isHidden = !showUsername

        // Add subviews
        containerView.addSubview(cursorImageView)
        containerView.addSubview(usernameLabel)

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update if needed
    }
}

#if DEBUG
#Preview("Cursor with Username") {
    CursorWindowPreview(
        showUsername: true,
        username: "Alice"
    )
    .frame(width: 120, height: 60)
}

#Preview("Cursor without Username") {
    CursorWindowPreview(
        showUsername: false,
        username: "Alice"
    )
    .frame(width: 120, height: 60)
}

#Preview("Long Username") {
    CursorWindowPreview(
        showUsername: true,
        username: "SuperLongUsername"
    )
    .frame(width: 150, height: 70)
}

#Preview("Short Name") {
    CursorWindowPreview(
        showUsername: true,
        username: "Bob"
    )
    .frame(width: 100, height: 50)
}

#Preview("Multiple States") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            CursorWindowPreview(
                showUsername: true,
                username: "Alice"
            )
            .frame(width: 120, height: 60)

            CursorWindowPreview(
                showUsername: true,
                username: "Bob"
            )
            .frame(width: 120, height: 60)
        }

        HStack(spacing: 20) {
            CursorWindowPreview(
                showUsername: false,
                username: "Charlie"
            )
            .frame(width: 120, height: 60)

            CursorWindowPreview(
                showUsername: true,
                username: "Dave with long name"
            )
            .frame(width: 150, height: 60)
        }
    }
    .padding()
}
#endif
