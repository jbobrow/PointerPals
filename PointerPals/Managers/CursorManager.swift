import Cocoa
import Combine

class CursorManager {
    private let networkManager: NetworkManager
    private var cursorWindows: [String: CursorWindow] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var inactivityTimers: [String: Timer] = [:]
    private var shouldShowUsernames: Bool = false
    private var cursorScale: CGFloat = PointerPalsConfig.defaultCursorScale
    private var usernames: [String: String] = [:] // userId -> username mapping
    private var subscriptionStates: [String: Bool] = [:] // userId -> isEnabled

    // Notification when subscriptions or usernames change
    let subscriptionsDidChange = PassthroughSubject<Void, Never>()

    // UserDefaults keys for persistence
    private let subscriptionsKey = "PointerPals_Subscriptions"
    private let usernamesKey = "PointerPals_SubscriptionUsernames"
    private let subscriptionStatesKey = "PointerPals_SubscriptionStates"

    var allSubscriptions: [String] {
        Array(subscriptionStates.keys)
    }

    var activeSubscriptionsCount: Int {
        subscriptionStates.values.filter { $0 }.count
    }

    func getUsername(for userId: String) -> String? {
        return usernames[userId]
    }

    func isSubscriptionEnabled(_ userId: String) -> Bool {
        return subscriptionStates[userId] ?? false
    }
    
    init(networkManager: NetworkManager, cursorScale: CGFloat = PointerPalsConfig.defaultCursorScale) {
        self.networkManager = networkManager
        self.cursorScale = cursorScale
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
        let subscriptionList = Array(subscriptionStates.keys)
        UserDefaults.standard.set(subscriptionList, forKey: subscriptionsKey)
        UserDefaults.standard.set(usernames, forKey: usernamesKey)
        UserDefaults.standard.set(subscriptionStates, forKey: subscriptionStatesKey)
    }

    private func loadSubscriptions() {
        // Load saved usernames first
        if let savedUsernames = UserDefaults.standard.dictionary(forKey: usernamesKey) as? [String: String] {
            usernames = savedUsernames
        }

        // Load subscription states
        if let savedStates = UserDefaults.standard.dictionary(forKey: subscriptionStatesKey) as? [String: Bool] {
            subscriptionStates = savedStates
        }

        // Load and restore subscriptions (for backwards compatibility, if states not found)
        if subscriptionStates.isEmpty,
           let savedSubscriptions = UserDefaults.standard.array(forKey: subscriptionsKey) as? [String] {
            for userId in savedSubscriptions {
                subscriptionStates[userId] = true
            }
        }

        // Enable all subscriptions that are marked as enabled
        for (userId, isEnabled) in subscriptionStates where isEnabled {
            enableSubscription(userId: userId)
        }
    }
    
    func subscribe(to userId: String) {
        // Check if already exists
        if subscriptionStates[userId] != nil {
            print("Subscription already exists for \(userId)")
            return
        }

        // Check max subscriptions limit
        if PointerPalsConfig.maxSubscriptions > 0 &&
           subscriptionStates.count >= PointerPalsConfig.maxSubscriptions {
            print("Maximum subscription limit reached (\(PointerPalsConfig.maxSubscriptions))")
            return
        }

        // Add subscription in enabled state
        subscriptionStates[userId] = true
        enableSubscription(userId: userId)

        // Save subscriptions to persist across launches
        saveSubscriptions()

        // Notify that subscriptions changed
        subscriptionsDidChange.send()

        if PointerPalsConfig.debugLogging {
            print("Subscribed to \(userId)")
        }
    }

    func toggleSubscription(_ userId: String) {
        guard let isEnabled = subscriptionStates[userId] else {
            print("No subscription found for \(userId)")
            return
        }

        if isEnabled {
            disableSubscription(userId: userId)
        } else {
            enableSubscription(userId: userId)
        }

        subscriptionStates[userId] = !isEnabled
        saveSubscriptions()
        subscriptionsDidChange.send()

        print("\(isEnabled ? "Disabled" : "Enabled") subscription for \(userId)")
    }

    func deleteSubscription(_ userId: String) {
        // Disable first if enabled
        if subscriptionStates[userId] == true {
            disableSubscription(userId: userId)
        }

        // Remove from all collections
        subscriptionStates.removeValue(forKey: userId)
        usernames.removeValue(forKey: userId)

        // Save and notify
        saveSubscriptions()
        subscriptionsDidChange.send()

        print("Deleted subscription for \(userId)")
    }

    private func enableSubscription(userId: String) {
        guard cursorWindows[userId] == nil else {
            return
        }

        let window = CursorWindow(userId: userId, cursorScale: cursorScale)
        cursorWindows[userId] = window
        networkManager.subscribeTo(userId: userId)
    }

    private func disableSubscription(userId: String) {
        if let window = cursorWindows[userId] {
            // Hide window and let it deallocate naturally to avoid crashes
            // DO NOT call close() - causes crashes when animation handlers access the window
            window.orderOut(nil)
            cursorWindows.removeValue(forKey: userId)
        }

        inactivityTimers[userId]?.invalidate()
        inactivityTimers.removeValue(forKey: userId)

        networkManager.unsubscribeFrom(userId: userId)
    }

    func setUsernameVisibility(_ visible: Bool) {
        shouldShowUsernames = visible

        // Update all existing cursor windows
        for window in cursorWindows.values {
            window.setUsernameVisibility(visible)
        }
    }

    func setCursorScale(_ scale: CGFloat) {
        cursorScale = scale

        // Recreate all active cursor windows with new scale
        let activeUserIds = Array(cursorWindows.keys)
        for userId in activeUserIds {
            // Disable and re-enable to recreate window with new scale
            disableSubscription(userId: userId)
            enableSubscription(userId: userId)
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
