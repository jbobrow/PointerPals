import Foundation
import AppKit

/// Configuration settings for PointerPals
/// Modify these values to customize app behavior
struct PointerPalsConfig {
    
    // MARK: - Network Configuration
    
    /// WebSocket server URL
    /// Change this to your deployed server URL for production
    /// Examples:
    /// - Local: "ws://localhost:8080"
    /// - LAN: "ws://192.168.1.100:8080"
    /// - Production: "wss://your-server.com"
    static let serverURL = "wss://pointerpals-163455294213.us-east4.run.app"
    
    // MARK: - Cursor Publishing
    
    /// Frames per second for cursor position updates
    /// Higher values = smoother but more network traffic
    /// Recommended: 20-60 FPS
    static let publishingFPS: Double = 30.0
    
    /// Only publish cursor updates when position changes
    /// Saves network bandwidth when cursor is stationary
    static let onlyPublishOnChange = true
    
    // MARK: - Cursor Display
    
    /// Size of the cursor overlay window
    static let cursorSize = CGSize(width: 20, height: 28)
    
    /// Opacity of active subscribed cursors (0.0 to 1.0)
    /// 1.0 = fully opaque, 0.0 = invisible
    static let activeCursorOpacity: Double = 0.7
    
    /// Duration of fade-in animation (seconds)
    static let fadeInDuration: Double = 0.3
    
    /// Duration of fade-out animation (seconds)
    static let fadeOutDuration: Double = 1.0
    
    /// Duration of cursor position animation (seconds)
    /// Lower = snappier, Higher = smoother
    static let cursorAnimationDuration: Double = 0.1
    
    // MARK: - Inactivity
    
    /// Time in seconds before inactive cursors fade out
    /// A cursor is considered inactive if no updates received
    static let inactivityTimeout: TimeInterval = 5.0
    
    // MARK: - Window Behavior
    
    /// Window level for cursor overlays
    /// .floating = above most windows
    /// .statusBar = above status bar
    /// .popUpMenu = above popup menus
    static let cursorWindowLevel: NSWindow.Level = .floating
    
    /// Whether cursors should appear on all spaces/desktops
    static let appearOnAllSpaces = true
    
    /// Whether cursors should ignore mouse events (non-interactive)
    /// Should always be true to avoid blocking clicks
    static let ignoreMouseEvents = true
    
    // MARK: - User Interface
    
    /// Menu bar icon when publishing
    static let publishingIcon = "📍"
    
    /// Menu bar icon when not publishing
    static let notPublishingIcon = "💤"
    
    /// Show subscription count in menu bar
    static let showSubscriptionCount = true
    
    // MARK: - Advanced
    
    /// Enable debug logging
    static let debugLogging = false
    
    /// Reconnection interval (seconds) if connection lost
    static let reconnectionInterval: TimeInterval = 2.0
    
    /// Connection health check interval (seconds)
    static let connectionCheckInterval: TimeInterval = 5.0
    
    /// Maximum number of simultaneous subscriptions
    /// Set to 0 for unlimited
    static let maxSubscriptions: Int = 0
    
    /// Clamp cursor coordinates to screen bounds
    /// Prevents cursors from appearing off-screen
    static let clampCoordinates = true
    
    // MARK: - Helper Methods
    
    /// Get publishing interval in seconds based on FPS
    static var publishingInterval: TimeInterval {
        return 1.0 / publishingFPS
    }
    
    /// Validate configuration values
    static func validate() {
        assert(publishingFPS > 0, "Publishing FPS must be greater than 0")
        assert(activeCursorOpacity >= 0.0 && activeCursorOpacity <= 1.0, "Opacity must be between 0.0 and 1.0")
        assert(inactivityTimeout > 0, "Inactivity timeout must be positive")
        assert(cursorSize.width > 0 && cursorSize.height > 0, "Cursor size must be positive")
    }
}

// MARK: - Presets

extension PointerPalsConfig {
    
    /// High performance preset values (for reference)
    /// To use: Manually update the static properties above with these values
    /// - Publishing FPS: 60.0
    /// - Cursor Animation Duration: 0.08
    /// - Fade In Duration: 0.2
    
    /// Battery saver preset values (for reference)
    /// To use: Manually update the static properties above with these values
    /// - Publishing FPS: 15.0
    /// - Cursor Animation Duration: 0.2
    /// - Fade Out Duration: 1.5
    
    /// Minimal preset values (for reference)
    /// To use: Manually update the static properties above with these values
    /// - Publishing FPS: 10.0
    /// - Only Publish On Change: true
    /// - Inactivity Timeout: 3.0
}

// MARK: - Cursor Style Presets

extension PointerPalsConfig {
    
    /// Available cursor style options
    enum CursorStyle {
        case standard      // Default macOS cursor
        case minimal       // Simple dot
        case bold          // Larger, more visible
        case neon          // Bright, glowing effect
        case custom(NSImage)
    }
    
    /// Current cursor style
    /// Modify CursorWindow.swift to implement custom styles
    static let cursorStyle: CursorStyle = .standard
}

// MARK: - Color Schemes

extension PointerPalsConfig {
    
    /// Color scheme for UI elements
    struct ColorScheme {
        let primary: NSColor
        let secondary: NSColor
        let accent: NSColor
        
        static let `default` = ColorScheme(
            primary: .controlAccentColor,
            secondary: .secondaryLabelColor,
            accent: .systemBlue
        )
        
        static let dark = ColorScheme(
            primary: .white,
            secondary: .gray,
            accent: .systemTeal
        )
        
        static let light = ColorScheme(
            primary: .black,
            secondary: .darkGray,
            accent: .systemBlue
        )
    }
    
    static let colorScheme: ColorScheme = .default
}

// MARK: - Usage Examples

/*
 
 Basic Usage:
 ------------
 
 1. Change server URL for production:
    static let serverURL = "wss://pointerpals.example.com"
 
 2. Adjust publishing rate:
    static let publishingFPS: Double = 60.0  // Smoother, more updates
    static let publishingFPS: Double = 15.0  // Fewer updates, saves bandwidth
 
 3. Change cursor appearance:
    static let activeCursorOpacity: Double = 0.9  // More visible
    static let cursorSize = CGSize(width: 24, height: 32)  // Larger
 
 4. Adjust fade behavior:
    static let inactivityTimeout: TimeInterval = 10.0  // Fade after 10 seconds
    static let fadeOutDuration: Double = 2.0  // Slower fade
 
 5. Enable debug logging:
    static let debugLogging = true
 
 Advanced:
 ---------
 
 1. Change window level:
    static let cursorWindowLevel: NSWindow.Level = .statusBar  // Above status bar
 
 2. Limit subscriptions:
    static let maxSubscriptions: Int = 10  // Max 10 simultaneous subscriptions
 
 3. Adjust reconnection:
    static let reconnectionInterval: TimeInterval = 5.0  // Wait 5s before retry
 
 */
