import Cocoa
import Combine

class CursorManager {
    private let networkManager: NetworkManager
    private var cursorWindows: [String: CursorWindow] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var inactivityTimers: [String: Timer] = [:]
    private var shouldShowUsernames: Bool = false
    private var usernames: [String: String] = [:] // userId -> username mapping

    // Notification when subscriptions or usernames change
    let subscriptionsDidChange = PassthroughSubject<Void, Never>()

    // UserDefaults keys for persistence
    private let subscriptionsKey = "PointerPals_Subscriptions"
    private let usernamesKey = "PointerPals_SubscriptionUsernames"

    var activeSubscriptions: [String] {
        Array(cursorWindows.keys)
    }

    func getUsername(for userId: String) -> String? {
        return usernames[userId]
    }
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
        setupSubscriptions()
        loadSubscriptions()
    }
    
    private func setupSubscriptions() {
        networkManager.cursorUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cursorData in
                self?.handleCursorUpdate(cursorData)
            }
            .store(in: &cancellables)

        networkManager.usernameUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (userId, username) in
                self?.handleUsernameUpdate(userId: userId, username: username)
            }
            .store(in: &cancellables)
    }

    private func saveSubscriptions() {
        let subscriptionList = Array(cursorWindows.keys)
        UserDefaults.standard.set(subscriptionList, forKey: subscriptionsKey)
        UserDefaults.standard.set(usernames, forKey: usernamesKey)
    }

    private func loadSubscriptions() {
        // Load saved usernames first
        if let savedUsernames = UserDefaults.standard.dictionary(forKey: usernamesKey) as? [String: String] {
            usernames = savedUsernames
        }

        // Load and restore subscriptions
        if let savedSubscriptions = UserDefaults.standard.array(forKey: subscriptionsKey) as? [String] {
            for userId in savedSubscriptions {
                subscribe(to: userId)
            }
        }
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

        // Save subscriptions to persist across launches
        saveSubscriptions()

        // Notify that subscriptions changed
        subscriptionsDidChange.send()

        if PointerPalsConfig.debugLogging {
            print("Subscribed to \(userId)")
        }
    }
    
    func unsubscribe(from userId: String) {
        if let window = cursorWindows[userId] {
            // Hide window and let it deallocate naturally to avoid crashes
            // DO NOT call close() - causes crashes when animation handlers access the window
            window.orderOut(nil)
            cursorWindows.removeValue(forKey: userId)
        }

        inactivityTimers[userId]?.invalidate()
        inactivityTimers.removeValue(forKey: userId)

        // Clean up stored username
        usernames.removeValue(forKey: userId)

        networkManager.unsubscribeFrom(userId: userId)

        // Save subscriptions to persist across launches
        saveSubscriptions()

        // Notify that subscriptions changed
        subscriptionsDidChange.send()

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

        // Update stored username if it has changed
        let usernameChanged: Bool
        if let newUsername = cursorData.username {
            let oldUsername = usernames[cursorData.userId]
            usernameChanged = oldUsername != newUsername
            usernames[cursorData.userId] = newUsername
        } else {
            usernameChanged = false
        }

        // Notify subscribers and persist if username changed
        if usernameChanged {
            saveSubscriptions()
            subscriptionsDidChange.send()
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

    private func handleUsernameUpdate(userId: String, username: String) {
        // Update stored username
        usernames[userId] = username

        // Persist the updated username
        saveSubscriptions()

        // Update the cursor window if usernames are visible
        if shouldShowUsernames, let window = cursorWindows[userId] {
            window.updateUsername(username)
        }

        // Notify that subscriptions changed (to update menu)
        subscriptionsDidChange.send()
    }
    
    deinit {
        for window in cursorWindows.values {
            // Hide window and let it deallocate naturally
            window.orderOut(nil)
        }
        for timer in inactivityTimers.values {
            timer.invalidate()
        }
    }
}
