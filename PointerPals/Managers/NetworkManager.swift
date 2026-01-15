import Foundation
import Combine

class NetworkManager {
    let currentUserId: String
    var currentUsername: String {
        didSet {
            UserDefaults.standard.set(currentUsername, forKey: "PointerPals_Username")
        }
    }
    private let cursorUpdateSubject = PassthroughSubject<CursorData, Never>()
    private var subscriptions: Set<String> = []

    // WebSocket configuration
    private var webSocketTask: URLSessionWebSocketTask?
    private let serverURL: String
    private var isConnected = false
    private var reconnectTimer: Timer?
    
    var cursorUpdatePublisher: AnyPublisher<CursorData, Never> {
        cursorUpdateSubject.eraseToAnyPublisher()
    }
    
    init(serverURL: String = PointerPalsConfig.serverURL) {
        self.serverURL = serverURL

        // Generate a unique user ID (in production, this might come from auth)
        if let savedUserId = UserDefaults.standard.string(forKey: "PointerPals_UserId") {
            self.currentUserId = savedUserId
        } else {
            self.currentUserId = "user_\(UUID().uuidString.prefix(8))"
            UserDefaults.standard.set(self.currentUserId, forKey: "PointerPals_UserId")
        }

        // Load or create username
        if let savedUsername = UserDefaults.standard.string(forKey: "PointerPals_Username"), !savedUsername.isEmpty {
            self.currentUsername = savedUsername
        } else {
            self.currentUsername = "User"
            UserDefaults.standard.set(self.currentUsername, forKey: "PointerPals_Username")
        }

        if PointerPalsConfig.debugLogging {
            print("Network Manager initialized with User ID: \(currentUserId), Username: \(currentUsername)")
        }

        // Establish WebSocket connection
        connectToServer()
    }
    
    private func connectToServer() {
        guard let url = URL(string: serverURL) else {
            print("Invalid server URL: \(serverURL)")
            return
        }
        
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        
        if PointerPalsConfig.debugLogging {
            print("Connecting to WebSocket server at \(serverURL)")
        }
        
        // Register with server
        registerUser()
        
        // Start receiving messages
        receiveMessage()
        
        // Monitor connection health
        scheduleConnectionCheck()
    }
    
    private func registerUser() {
        let registerMessage: [String: Any] = [
            "action": "register",
            "userId": currentUserId,
            "username": currentUsername
        ]

        sendMessage(registerMessage)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.isConnected = false
                self.attemptReconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "registered":
            isConnected = true
            print("Successfully registered with server")
            
            // Re-subscribe to any existing subscriptions
            for userId in subscriptions {
                subscribeTo(userId: userId)
            }
            
        case "cursor_update":
            if let cursorDataDict = json["cursorData"] as? [String: Any],
               let cursorData = parseCursorData(from: cursorDataDict) {
                handleIncomingCursorUpdate(cursorData)
            }
            
        case "subscribed":
            if let targetUserId = json["targetUserId"] as? String {
                print("Successfully subscribed to \(targetUserId)")
            }
            
        case "unsubscribed":
            if let targetUserId = json["targetUserId"] as? String {
                print("Successfully unsubscribed from \(targetUserId)")
            }
            
        case "error":
            if let message = json["message"] as? String {
                print("Server error: \(message)")
            }
            
        default:
            print("Unknown message type: \(type)")
        }
    }
    
    private func parseCursorData(from dict: [String: Any]) -> CursorData? {
        guard let userId = dict["userId"] as? String,
              let x = dict["x"] as? Double,
              let y = dict["y"] as? Double else {
            return nil
        }

        let username = dict["username"] as? String

        let timestamp: Date
        if let timestampString = dict["timestamp"] as? String,
           let date = ISO8601DateFormatter().date(from: timestampString) {
            timestamp = date
        } else {
            timestamp = Date()
        }

        return CursorData(userId: userId, username: username, x: x, y: y, timestamp: timestamp)
    }
    
    func publishCursorPosition(_ cursorData: CursorData) {
        guard isConnected else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let cursorDataJSON = try? encoder.encode(cursorData),
              let cursorDataDict = try? JSONSerialization.jsonObject(with: cursorDataJSON) as? [String: Any] else {
            return
        }
        
        let message: [String: Any] = [
            "action": "cursor_update",
            "cursorData": cursorDataDict
        ]
        
        sendMessage(message)
    }
    
    func subscribeTo(userId: String) {
        subscriptions.insert(userId)
        
        guard isConnected else {
            print("Not connected to server, subscription will be sent when connected")
            return
        }
        
        let message: [String: Any] = [
            "action": "subscribe",
            "targetUserId": userId
        ]
        
        sendMessage(message)
    }
    
    func unsubscribeFrom(userId: String) {
        subscriptions.remove(userId)
        
        guard isConnected else { return }
        
        let message: [String: Any] = [
            "action": "unsubscribe",
            "targetUserId": userId
        ]
        
        sendMessage(message)
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
        
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    private func handleIncomingCursorUpdate(_ cursorData: CursorData) {
        // Only process updates from users we're subscribed to
        guard subscriptions.contains(cursorData.userId) else { return }
        
        DispatchQueue.main.async {
            self.cursorUpdateSubject.send(cursorData)
        }
    }
    
    private func scheduleConnectionCheck() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(
            withTimeInterval: PointerPalsConfig.connectionCheckInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkConnection()
        }
    }
    
    private func checkConnection() {
        if !isConnected {
            attemptReconnect()
        }
    }
    
    private func attemptReconnect() {
        if PointerPalsConfig.debugLogging {
            print("Attempting to reconnect...")
        }
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + PointerPalsConfig.reconnectionInterval) { [weak self] in
            self?.connectToServer()
        }
    }
    
    deinit {
        reconnectTimer?.invalidate()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    // MARK: - WebSocket Integration Examples
    
    /*
    Example using URLSessionWebSocketTask:
    
    private var webSocketTask: URLSessionWebSocketTask?
    
    private func connectToServer() {
        let url = URL(string: "wss://your-server.com/cursor-stream")!
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let cursorData = try? JSONDecoder().decode(CursorData.self, from: data) {
                        self?.handleIncomingCursorUpdate(cursorData)
                    }
                case .data(let data):
                    if let cursorData = try? JSONDecoder().decode(CursorData.self, from: data) {
                        self?.handleIncomingCursorUpdate(cursorData)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage()
            case .failure(let error):
                print("WebSocket error: \(error)")
            }
        }
    }
    
    func publishCursorPosition(_ cursorData: CursorData) {
        guard let data = try? JSONEncoder().encode(cursorData),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    */
    
    /*
    Example using Starscream (third-party library):
    
    import Starscream
    
    private var socket: WebSocket?
    
    private func connectToServer() {
        var request = URLRequest(url: URL(string: "wss://your-server.com/cursor-stream")!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }
    
    extension NetworkManager: WebSocketDelegate {
        func didReceive(event: WebSocketEvent, client: WebSocket) {
            switch event {
            case .text(let string):
                if let data = string.data(using: .utf8),
                   let cursorData = try? JSONDecoder().decode(CursorData.self, from: data) {
                    handleIncomingCursorUpdate(cursorData)
                }
            case .connected:
                print("WebSocket connected")
            case .disconnected(let reason, let code):
                print("WebSocket disconnected: \(reason) with code: \(code)")
            case .error(let error):
                print("WebSocket error: \(error?.localizedDescription ?? "Unknown error")")
            default:
                break
            }
        }
    }
    */
}
