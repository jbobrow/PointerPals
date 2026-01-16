import Cocoa
import Combine

class CursorPublisher {
    private let networkManager: NetworkManager
    private var timer: Timer?
    private var lastPosition: CGPoint?
    private(set) var isPublishing = false
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func startPublishing() {
        guard !isPublishing else { return }
        isPublishing = true

        // Publish cursor position at configured FPS
        timer = Timer.scheduledTimer(
            withTimeInterval: PointerPalsConfig.publishingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.publishCurrentPosition()
        }

        print("✅ Started publishing cursor position at \(PointerPalsConfig.publishingFPS) FPS")
    }
    
    func stopPublishing() {
        timer?.invalidate()
        timer = nil
        isPublishing = false
        print("Stopped publishing cursor position")
    }
    
    private var publishCount = 0

    private func publishCurrentPosition() {
        let mouseLocation = NSEvent.mouseLocation

        // Only publish if position changed (if configured)
        if PointerPalsConfig.onlyPublishOnChange {
            if let last = lastPosition, last == mouseLocation {
                return
            }
        }

        guard let screen = NSScreen.main else {
            print("⚠️ No screen detected")
            return
        }
        let screenFrame = screen.frame

        // Normalize coordinates (0.0 to 1.0)
        var normalizedX = mouseLocation.x / screenFrame.width
        var normalizedY = mouseLocation.y / screenFrame.height

        // Clamp coordinates if configured
        if PointerPalsConfig.clampCoordinates {
            normalizedX = max(0.0, min(1.0, normalizedX))
            normalizedY = max(0.0, min(1.0, normalizedY))
        }

        let cursorData = CursorData(
            userId: networkManager.currentUserId,
            username: networkManager.currentUsername,
            x: normalizedX,
            y: normalizedY,
            timestamp: Date()
        )

        networkManager.publishCursorPosition(cursorData)
        lastPosition = mouseLocation

        // Log every 30 publishes to avoid spam
        publishCount += 1
        if publishCount % 30 == 0 {
            print("📍 Published \(publishCount) cursor positions (current: x=\(String(format: "%.2f", normalizedX)), y=\(String(format: "%.2f", normalizedY)))")
        }
    }
    
    deinit {
        stopPublishing()
    }
}
