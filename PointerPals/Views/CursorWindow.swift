import Cocoa

class CursorWindow: NSWindow {
    private let cursorImageView: NSImageView
    private let usernameLabel: NSTextField
    private let userId: String
    private var currentUsername: String?

    init(userId: String) {
        self.userId = userId

        // Create cursor image view
        cursorImageView = NSImageView(frame: NSRect(origin: .zero, size: PointerPalsConfig.cursorSize))
        cursorImageView.image = NSImage(named: NSImage.Name("NSCursor"))

        // If system cursor image is not available, create a custom one
        if cursorImageView.image == nil {
            cursorImageView.image = CursorWindow.createCursorImage(size: PointerPalsConfig.cursorSize)
        }

        // Create username label
        usernameLabel = NSTextField(labelWithString: "")
        usernameLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        usernameLabel.textColor = .white
        usernameLabel.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        usernameLabel.isBordered = false
        usernameLabel.isEditable = false
        usernameLabel.alignment = .center
        usernameLabel.wantsLayer = true
        usernameLabel.layer?.cornerRadius = 4
        usernameLabel.layer?.masksToBounds = true

        // Calculate window size to accommodate cursor and label
        let windowWidth = max(PointerPalsConfig.cursorSize.width, 100)
        let windowHeight = PointerPalsConfig.cursorSize.height + 20
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

        // Position cursor at top of window
        cursorImageView.frame.origin = CGPoint(x: 0, y: 20)

        // Position username label below cursor
        usernameLabel.frame = NSRect(x: 0, y: 0, width: windowWidth, height: 18)

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
            usernameLabel.stringValue = username
            usernameLabel.isHidden = false
        } else {
            usernameLabel.isHidden = true
        }
    }

    func setUsernameVisibility(_ visible: Bool) {
        if visible {
            // Show username if we have one
            if let username = currentUsername, !username.isEmpty {
                usernameLabel.stringValue = username
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

        let targetOrigin = CGPoint(x: screenX, y: screenY)

        // Animate to new position
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
    private static func createCursorImage(size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw a simple arrow cursor shape
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 0, y: size.height))
        path.line(to: CGPoint(x: 0, y: 0))
        path.line(to: CGPoint(x: size.width * 0.4, y: size.height * 0.6))
        path.line(to: CGPoint(x: size.width * 0.6, y: size.height * 0.5))
        path.line(to: CGPoint(x: size.width, y: size.height))
        path.line(to: CGPoint(x: size.width * 0.55, y: size.height * 0.65))
        path.line(to: CGPoint(x: size.width * 0.35, y: size.height * 0.75))
        path.close()
        
        // Fill with white
        NSColor.white.setFill()
        path.fill()
        
        // Stroke with black
        NSColor.black.setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        image.unlockFocus()
        
        return image
    }
}
