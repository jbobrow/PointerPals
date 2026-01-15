# PointerPals 🖱️

A macOS application that allows you to share your cursor position with others and see their cursors on your screen in real-time.

## Features

- **Cursor Publishing**: Share your normalized cursor position in real-time
- **Usernames**: Set your username and see others' names displayed with their cursors
- **Cursor Subscriptions**: Subscribe to others' cursors and see them as transparent overlay windows
- **Auto-fade**: Subscribed cursors fade out after 5 seconds of inactivity
- **Menu Bar App**: Lightweight menu bar integration showing publishing status and subscription count
- **Always On Top**: Subscribed cursors appear above all windows but don't block interactions
- **WebSocket Server**: Fully functional server included with Google Cloud deployment guide

## Project Structure

```
PointerPals/
├── PointerPalsApp.swift          # Main app and menu bar UI
├── CursorPublisher.swift         # Publishes local cursor position
├── CursorManager.swift           # Manages subscribed cursor windows
├── CursorWindow.swift            # Overlay window for remote cursors
├── NetworkManager.swift          # Networking layer (needs implementation)
├── Models/
│   └── CursorData.swift          # Cursor position data model
├── Info.plist                    # App configuration
└── README.md                     # This file
```

## Building the App

### Prerequisites

- macOS 12.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later

### Setup Instructions

1. **Create an Xcode Project**:
   ```bash
   # Open Xcode
   # File > New > Project
   # Choose "App" under macOS
   # Product Name: PointerPals
   # Interface: SwiftUI
   # Language: Swift
   ```

2. **Add the Source Files**:
   - Copy all `.swift` files to your project
   - Maintain the folder structure (create a `Models` group)
   - Replace the default `Info.plist` with the provided one

3. **Configure Build Settings**:
   - Set minimum deployment target to macOS 12.0
   - Bundle identifier: `com.yourname.PointerPals`

4. **Build and Run**:
   - Press Cmd+R or Product > Run
   - Grant accessibility permissions when prompted

## WebSocket Server

A complete WebSocket server is included in the `Server/` directory with full support for:
- User registration with usernames
- Publish/Subscribe pattern for cursor updates
- Automatic cleanup of stale connections
- Real-time broadcasting with low latency

**📘 [See Server Documentation](./Server/README.md)**

**☁️ [Google Cloud Hosting Guide](./Server/GOOGLE_CLOUD_HOSTING.md)** - Deploy to Cloud Run, Compute Engine, or GKE

### Quick Start (Local Server)

```bash
cd Server
npm install
npm start
```

The server will run on `ws://localhost:8080`

## Alternative Network Backends

If you prefer not to use the included WebSocket server, here are alternative options:

### Option 1: WebSocket Server (Recommended)

Create a simple WebSocket server that broadcasts cursor positions:

**Server Requirements**:
- Accept WebSocket connections
- Handle publish/subscribe patterns
- Broadcast cursor updates to subscribers only

**Example Node.js Server** (using `ws` library):

```javascript
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

const clients = new Map(); // userId -> WebSocket
const subscriptions = new Map(); // userId -> Set<subscriberUserId>

wss.on('connection', (ws) => {
  let currentUserId = null;

  ws.on('message', (message) => {
    const data = JSON.parse(message);

    switch (data.action) {
      case 'register':
        currentUserId = data.userId;
        clients.set(currentUserId, ws);
        subscriptions.set(currentUserId, new Set());
        break;

      case 'subscribe':
        if (!subscriptions.has(currentUserId)) {
          subscriptions.set(currentUserId, new Set());
        }
        subscriptions.get(currentUserId).add(data.targetUserId);
        break;

      case 'unsubscribe':
        subscriptions.get(currentUserId)?.delete(data.targetUserId);
        break;

      case 'cursor_update':
        // Broadcast to all subscribers
        for (const [userId, subs] of subscriptions.entries()) {
          if (subs.has(currentUserId)) {
            const client = clients.get(userId);
            if (client && client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(data.cursorData));
            }
          }
        }
        break;
    }
  });

  ws.on('close', () => {
    if (currentUserId) {
      clients.delete(currentUserId);
      subscriptions.delete(currentUserId);
    }
  });
});
```

**Update NetworkManager.swift**:

Uncomment the WebSocket implementation in `NetworkManager.swift` and update the URL:

```swift
private func connectToServer() {
    let url = URL(string: "wss://your-server.com/cursor-stream")!
    webSocketTask = URLSession.shared.webSocketTask(with: url)
    webSocketTask?.resume()
    
    // Register with server
    let registerMessage = [
        "action": "register",
        "userId": currentUserId
    ]
    if let data = try? JSONSerialization.data(withJSONObject: registerMessage),
       let jsonString = String(data: data, encoding: .utf8) {
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message, completionHandler: nil)
    }
    
    receiveMessage()
}
```

### Option 2: Firebase Realtime Database

1. Add Firebase SDK via Swift Package Manager
2. Set up Firebase Realtime Database
3. Structure: `/cursors/{userId}/{x, y, timestamp}`
4. Use Firebase listeners for real-time updates

### Option 3: Supabase Realtime

1. Add Supabase Swift SDK
2. Create a `cursor_positions` table
3. Use Supabase Realtime subscriptions

### Option 4: Peer-to-Peer (Advanced)

Use Network.framework for local network discovery and P2P connections (no server needed, but more complex).

## Usage

### First Launch

1. The app will request accessibility permissions - this is required to read cursor position
2. Go to System Preferences > Privacy & Security > Accessibility
3. Enable PointerPals

### Publishing Your Cursor

1. Click the PointerPals icon in the menu bar (shows 💤 when not publishing)
2. Select "Start Publishing"
3. Icon changes to 📍 to indicate active publishing
4. Your cursor position is now being shared at 30 FPS

### Subscribing to Others

1. Get someone's User ID (they can find it in Settings)
2. Click the PointerPals menu bar icon
3. Select "Add Subscription..."
4. Enter their User ID
5. Their cursor will appear as a transparent overlay when they move

### Managing Subscriptions

- Active subscriptions are shown in the menu bar icon count (e.g., "📍 3" means publishing with 3 active subscriptions)
- View subscription list in the dropdown menu
- Click any subscription to unsubscribe
- Subscribed cursors fade out after 5 seconds of inactivity

### Setting Your Username

1. Click PointerPals menu bar icon
2. Select "Settings..."
3. Enter your desired username
4. Click "Save"

Your username will be displayed above your cursor when others subscribe to you.

### Finding Your User ID

1. Click PointerPals menu bar icon
2. Select "Settings..."
3. Copy your User ID to share with others

## Customization

### Adjust Fade Timeout

In `CursorManager.swift`, modify:
```swift
let inactivityTimeout: TimeInterval = 5.0 // Change to desired seconds
```

### Adjust Publishing Rate

In `CursorPublisher.swift`, modify:
```swift
timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) // Change 30.0 to desired FPS
```

### Adjust Cursor Opacity

In `CursorWindow.swift`, modify:
```swift
self.animator().alphaValue = 0.7 // Change to desired opacity (0.0 to 1.0)
```

### Cursor Size

In `CursorWindow.swift`, modify:
```swift
private let cursorSize: CGSize = CGSize(width: 20, height: 28)
```

## Security Considerations

⚠️ **Important**: This app shares your exact cursor position. Consider:

1. **Privacy**: Your cursor movements are broadcast to subscribers
2. **Authentication**: Implement proper user authentication in production
3. **Authorization**: Verify subscription permissions server-side
4. **Encryption**: Use WSS (WebSocket Secure) in production
5. **Rate Limiting**: Implement server-side rate limiting

## Troubleshooting

### Cursor not publishing
- Check accessibility permissions in System Preferences
- Ensure you clicked "Start Publishing" in the menu

### Not seeing subscribed cursors
- Verify the network connection is working
- Check that the subscribed user is actively publishing
- Ensure User IDs are entered correctly

### Cursors appearing in wrong position
- This could indicate different screen resolutions/aspect ratios
- The current implementation uses normalized coordinates (0-1 range)
- Consider implementing screen resolution awareness if needed

## Future Enhancements

- [x] Cursor labels showing user names
- [x] WebSocket server implementation
- [x] Cloud hosting documentation
- [ ] Custom cursor colors/styles for each user
- [ ] Drawing mode (leave a trail)
- [ ] Presence indicators
- [ ] Multi-monitor support
- [ ] Cursor history replay
- [ ] Screen resolution synchronization
- [ ] Encrypted connections (WSS support included in server)
- [ ] User authentication
- [ ] Group subscriptions/rooms

## License

This project is provided as-is for educational purposes.

## Contributing

Feel free to fork and improve! Key areas that need work:
- Complete network implementation
- Better cursor graphics
- Performance optimization
- Multi-monitor support
- Security hardening

---

Made with ❤️ for remote collaboration
