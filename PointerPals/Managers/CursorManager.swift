import Cocoa
import Combine

class CursorManager {
    private let networkManager: NetworkManager
    private var cursorWindows: [String: CursorWindow] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var inactivityTimers: [String: Timer] = [:]
    private var shouldShowUsernames: Bool = false

    var activeSubscriptions: [String] {
        Array(cursorWindows.keys)
    }
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        networkManager.cursorUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cursorData in
                self?.handleCursorUpdate(cursorData)
            }
            .store(in: &cancellables)
    }
    
    func subscribe(to userId: String) {
        guard cursorWindows[userId] == nil else {
            print("Already subscribed to \(userId)")
            return
        }
        
        // Check max subscriptions limit
        if PointerPalsConfig.maxSubscriptions > 0 &&
           cursorWindows.count >= PointerPalsConfig.maxSubscriptions {
            print("Maximum subscription limit reached (\(PointerPalsConfig.maxSubscriptions))")
            return
        }
        
        let window = CursorWindow(userId: userId)
        cursorWindows[userId] = window
        networkManager.subscribeTo(userId: userId)
        
        if PointerPalsConfig.debugLogging {
            print("Subscribed to \(userId)")
        }
    }
    
    func unsubscribe(from userId: String) {
        if let window = cursorWindows[userId] {
            window.close()
            cursorWindows.removeValue(forKey: userId)
        }

        inactivityTimers[userId]?.invalidate()
        inactivityTimers.removeValue(forKey: userId)

        networkManager.unsubscribeFrom(userId: userId)

        print("Unsubscribed from \(userId)")
    }

    func setUsernameVisibility(_ visible: Bool) {
        shouldShowUsernames = visible

        // Update all existing cursor windows
        for window in cursorWindows.values {
            window.setUsernameVisibility(visible)
        }
    }
    
    private func handleCursorUpdate(_ cursorData: CursorData) {
        guard let window = cursorWindows[cursorData.userId] else {
            return
        }

        // Cancel existing inactivity timer
        inactivityTimers[cursorData.userId]?.invalidate()

        // Update username if available and visibility is enabled
        if shouldShowUsernames {
            window.updateUsername(cursorData.username)
        } else {
            window.updateUsername(nil)
        }

        // Fade in if needed and update position
        window.fadeIn()
        window.updatePosition(x: cursorData.x, y: cursorData.y)

        // Start new inactivity timer
        let timer = Timer.scheduledTimer(
            withTimeInterval: PointerPalsConfig.inactivityTimeout,
            repeats: false
        ) { [weak self, weak window] _ in
            window?.fadeOut()
            self?.inactivityTimers[cursorData.userId]?.invalidate()
            self?.inactivityTimers.removeValue(forKey: cursorData.userId)
        }

        inactivityTimers[cursorData.userId] = timer
    }
    
    deinit {
        for window in cursorWindows.values {
            window.close()
        }
        for timer in inactivityTimers.values {
            timer.invalidate()
        }
    }
}
