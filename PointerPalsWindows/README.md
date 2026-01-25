# PointerPals for Windows

A Windows desktop application for real-time cursor sharing, mirroring all functionality of the macOS version.

## Features

- **Real-time Cursor Sharing**: Share your cursor position with friends at 30 FPS
- **System Tray App**: Runs quietly in the background with easy access via system tray
- **Remote Cursors**: See your pals' cursors as transparent overlays on your screen
- **Username Display**: Optional usernames shown above remote cursors
- **Subscription Management**: Add, toggle, and remove pals easily
- **Launch on Startup**: Optionally start with Windows
- **Custom Server Support**: Connect to your own PointerPals server

## Requirements

- Windows 10 or later
- .NET 8.0 Runtime

## Building

### Prerequisites

1. Install [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
2. (Optional) Install Visual Studio 2022 with .NET desktop development workload

### Build from Command Line

```bash
cd PointerPalsWindows
dotnet build -c Release
```

### Build with Visual Studio

1. Open `PointerPalsWindows.csproj` in Visual Studio 2022
2. Select Release configuration
3. Build > Build Solution

## Running

### From Build Output

```bash
dotnet run
```

Or run the executable directly from `bin/Release/net8.0-windows/PointerPals.exe`

### Publishing

To create a self-contained executable:

```bash
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

This creates a single executable in `bin/Release/net8.0-windows/win-x64/publish/`

## Usage

1. **System Tray**: The app runs in the system tray (notification area)
2. **Add a Pal**: Right-click the tray icon > "Add a Pal..." > Enter their Pointer ID
3. **Share Your ID**: Settings > Copy your Pointer ID to share with friends
4. **Manage Subscriptions**: Right-click tray icon to see and manage your pals
5. **Settings**: Configure username, cursor size, and other preferences

## Architecture

The Windows app mirrors the macOS Swift implementation:

| Component | Description |
|-----------|-------------|
| `NetworkManager` | WebSocket connection to server, message handling |
| `CursorPublisher` | Captures and publishes local cursor position |
| `CursorManager` | Manages remote cursor windows and subscriptions |
| `CursorOverlayWindow` | Transparent click-through window for each remote cursor |
| `App` | Main application with system tray integration |

## Configuration

Settings are stored in the Windows Registry under:
```
HKEY_CURRENT_USER\SOFTWARE\PointerPals
```

Available settings:
- `UserId`: Your unique Pointer ID
- `Username`: Display name shown to other users
- `ShowUsernames`: Whether to display usernames on cursors
- `CursorScale`: Size of remote cursors (0.5 - 1.0)
- `LaunchOnStartup`: Start with Windows
- `ServerURL`: Custom server address (optional)

## Troubleshooting

### Cursors not appearing
- Check your firewall settings allow outbound WebSocket connections
- Verify the server URL is correct (default: `wss://pointerpals-server.jonbobrow.com`)

### High CPU usage
- This is normal during active cursor movement
- CPU usage is minimal when cursors are stationary

### Connection issues
- The app automatically reconnects if disconnected
- Check your internet connection
- Try restarting the app

## License

Same license as the main PointerPals project.
