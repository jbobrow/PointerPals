using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using PointerPals.Config;
using PointerPals.Models;

namespace PointerPals.Managers;

/// <summary>
/// Manages WebSocket connection to the PointerPals server
/// </summary>
public class NetworkManager : IDisposable
{
    private ClientWebSocket? _webSocket;
    private CancellationTokenSource? _cancellationTokenSource;
    private readonly HashSet<string> _subscriptions = new();
    private System.Timers.Timer? _reconnectTimer;
    private System.Timers.Timer? _pingTimer;
    private DateTime _lastPongTime = DateTime.UtcNow;
    private bool _isConnected;
    private bool _isDisposed;

    public string CurrentUserId { get; }

    private string _currentUsername;
    public string CurrentUsername
    {
        get => _currentUsername;
        set
        {
            if (_currentUsername != value)
            {
                _currentUsername = value;
                PointerPalsConfig.Username = value;
                if (_isConnected)
                {
                    _ = UpdateUsernameOnServerAsync();
                }
            }
        }
    }

    public bool IsConnected => _isConnected;

    // Events
    public event Action<CursorData>? CursorUpdateReceived;
    public event Action<string, string>? UsernameUpdateReceived;
    public event Action<bool>? ConnectionStateChanged;

    public NetworkManager()
    {
        CurrentUserId = PointerPalsConfig.UserId;
        _currentUsername = PointerPalsConfig.Username;

        if (PointerPalsConfig.DebugLogging)
        {
            Console.WriteLine($"NetworkManager initialized with Pointer ID: {CurrentUserId}, Username: {_currentUsername}");
        }

        _ = ConnectAsync();
    }

    private async Task ConnectAsync()
    {
        if (_isDisposed) return;

        try
        {
            _cancellationTokenSource?.Cancel();
            _cancellationTokenSource = new CancellationTokenSource();

            _webSocket?.Dispose();
            _webSocket = new ClientWebSocket();

            // Configure keepalive to prevent NAT/firewall timeouts
            _webSocket.Options.KeepAliveInterval = TimeSpan.FromSeconds(PointerPalsConfig.PingInterval);

            var serverUrl = PointerPalsConfig.ServerURL;
            Console.WriteLine($"Connecting to WebSocket server at: {serverUrl}");

            await _webSocket.ConnectAsync(new Uri(serverUrl), _cancellationTokenSource.Token);

            _isConnected = true;
            ConnectionStateChanged?.Invoke(true);
            Console.WriteLine("WebSocket connected successfully");

            // Register with server
            await RegisterUserAsync();

            // Re-subscribe to existing subscriptions
            foreach (var userId in _subscriptions.ToList())
            {
                await SubscribeToAsync(userId);
            }

            // Start receiving messages
            _ = ReceiveMessagesAsync();

            // Start connection health check
            StartConnectionCheck();

            // Start ping keepalive timer
            StartPingTimer();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"WebSocket connection error: {ex.Message}");
            _isConnected = false;
            ConnectionStateChanged?.Invoke(false);
            ScheduleReconnect();
        }
    }

    private async Task RegisterUserAsync()
    {
        var message = new Dictionary<string, object>
        {
            ["action"] = "register",
            ["userId"] = CurrentUserId,
            ["username"] = _currentUsername
        };

        await SendMessageAsync(message);
    }

    private async Task UpdateUsernameOnServerAsync()
    {
        var message = new Dictionary<string, object>
        {
            ["action"] = "update_username",
            ["username"] = _currentUsername
        };

        await SendMessageAsync(message);
    }

    private async Task ReceiveMessagesAsync()
    {
        var buffer = new byte[4096];

        try
        {
            while (_webSocket?.State == WebSocketState.Open && !_cancellationTokenSource!.Token.IsCancellationRequested)
            {
                var result = await _webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), _cancellationTokenSource.Token);

                if (result.MessageType == WebSocketMessageType.Close)
                {
                    Console.WriteLine("WebSocket closed by server");
                    _isConnected = false;
                    ConnectionStateChanged?.Invoke(false);
                    ScheduleReconnect();
                    return;
                }

                if (result.MessageType == WebSocketMessageType.Text)
                {
                    var text = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    // Any received message indicates the connection is alive
                    _lastPongTime = DateTime.UtcNow;
                    HandleMessage(text);
                }
            }
        }
        catch (OperationCanceledException)
        {
            // Expected when cancellation is requested
        }
        catch (Exception ex)
        {
            Console.WriteLine($"WebSocket receive error: {ex.Message}");
            _isConnected = false;
            ConnectionStateChanged?.Invoke(false);
            ScheduleReconnect();
        }
    }

    private void HandleMessage(string text)
    {
        try
        {
            using var doc = JsonDocument.Parse(text);
            var root = doc.RootElement;

            if (!root.TryGetProperty("type", out var typeElement))
                return;

            var type = typeElement.GetString();

            switch (type)
            {
                case "registered":
                    Console.WriteLine("Successfully registered with server");
                    break;

                case "pong":
                    // Response to our application-level ping
                    if (PointerPalsConfig.DebugLogging)
                    {
                        Console.WriteLine("Pong received");
                    }
                    break;

                case "cursor_update":
                    if (root.TryGetProperty("cursorData", out var cursorDataElement))
                    {
                        var cursorData = ParseCursorData(cursorDataElement);
                        if (cursorData != null && _subscriptions.Contains(cursorData.UserId))
                        {
                            CursorUpdateReceived?.Invoke(cursorData);
                        }
                    }
                    break;

                case "subscribed":
                    if (root.TryGetProperty("targetUserId", out var subscribedUserId))
                    {
                        Console.WriteLine($"Successfully subscribed to {subscribedUserId.GetString()}");
                    }
                    break;

                case "unsubscribed":
                    if (root.TryGetProperty("targetUserId", out var unsubscribedUserId))
                    {
                        Console.WriteLine($"Successfully unsubscribed from {unsubscribedUserId.GetString()}");
                    }
                    break;

                case "username_update":
                    if (root.TryGetProperty("userId", out var updateUserId) &&
                        root.TryGetProperty("username", out var updateUsername))
                    {
                        var userId = updateUserId.GetString();
                        var username = updateUsername.GetString();
                        if (userId != null && username != null)
                        {
                            Console.WriteLine($"User {userId} changed username to: {username}");
                            UsernameUpdateReceived?.Invoke(userId, username);
                        }
                    }
                    break;

                case "username_updated":
                    if (root.TryGetProperty("username", out var confirmedUsername))
                    {
                        Console.WriteLine($"Username updated to: {confirmedUsername.GetString()}");
                    }
                    break;

                case "error":
                    if (root.TryGetProperty("message", out var errorMessage))
                    {
                        Console.WriteLine($"Server error: {errorMessage.GetString()}");
                    }
                    break;

                default:
                    Console.WriteLine($"Unknown message type: {type}");
                    break;
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error handling message: {ex.Message}");
        }
    }

    private CursorData? ParseCursorData(JsonElement element)
    {
        try
        {
            if (!element.TryGetProperty("userId", out var userIdElement) ||
                !element.TryGetProperty("x", out var xElement) ||
                !element.TryGetProperty("y", out var yElement))
            {
                return null;
            }

            var userId = userIdElement.GetString() ?? string.Empty;
            var x = xElement.GetDouble();
            var y = yElement.GetDouble();
            var username = element.TryGetProperty("username", out var usernameElement)
                ? usernameElement.GetString()
                : null;

            DateTime timestamp = DateTime.UtcNow;
            if (element.TryGetProperty("timestamp", out var timestampElement))
            {
                if (DateTime.TryParse(timestampElement.GetString(), out var parsed))
                {
                    timestamp = parsed;
                }
            }

            return new CursorData(userId, username, x, y, timestamp);
        }
        catch
        {
            return null;
        }
    }

    public async Task PublishCursorPositionAsync(CursorData cursorData)
    {
        if (!_isConnected) return;

        var message = new Dictionary<string, object>
        {
            ["action"] = "cursor_update",
            ["cursorData"] = new Dictionary<string, object>
            {
                ["userId"] = cursorData.UserId,
                ["username"] = cursorData.Username ?? string.Empty,
                ["x"] = cursorData.X,
                ["y"] = cursorData.Y,
                ["timestamp"] = cursorData.Timestamp.ToString("O")
            }
        };

        await SendMessageAsync(message);
    }

    public void SubscribeTo(string userId)
    {
        _subscriptions.Add(userId);
        _ = SubscribeToAsync(userId);
    }

    private async Task SubscribeToAsync(string userId)
    {
        if (!_isConnected)
        {
            Console.WriteLine("Not connected, subscription will be sent when connected");
            return;
        }

        var message = new Dictionary<string, object>
        {
            ["action"] = "subscribe",
            ["targetUserId"] = userId
        };

        await SendMessageAsync(message);
    }

    public void UnsubscribeFrom(string userId)
    {
        _subscriptions.Remove(userId);
        _ = UnsubscribeFromAsync(userId);
    }

    private async Task UnsubscribeFromAsync(string userId)
    {
        if (!_isConnected) return;

        var message = new Dictionary<string, object>
        {
            ["action"] = "unsubscribe",
            ["targetUserId"] = userId
        };

        await SendMessageAsync(message);
    }

    private async Task SendMessageAsync(Dictionary<string, object> message)
    {
        if (_webSocket?.State != WebSocketState.Open) return;

        try
        {
            var json = JsonSerializer.Serialize(message);
            var bytes = Encoding.UTF8.GetBytes(json);
            await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, _cancellationTokenSource!.Token);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"WebSocket send error: {ex.Message}");
        }
    }

    private void StartConnectionCheck()
    {
        _reconnectTimer?.Stop();
        _reconnectTimer = new System.Timers.Timer(PointerPalsConfig.ConnectionCheckInterval * 1000);
        _reconnectTimer.Elapsed += (_, _) =>
        {
            if (_isDisposed) return;

            if (!_isConnected)
            {
                _ = ConnectAsync();
                return;
            }

            // Check if pong timeout has been exceeded
            var timeSinceLastPong = (DateTime.UtcNow - _lastPongTime).TotalSeconds;
            if (timeSinceLastPong > PointerPalsConfig.PongTimeout + PointerPalsConfig.PingInterval)
            {
                Console.WriteLine($"Pong timeout exceeded ({timeSinceLastPong:F1}s since last activity), reconnecting...");
                _isConnected = false;
                ConnectionStateChanged?.Invoke(false);
                ScheduleReconnect();
            }
        };
        _reconnectTimer.Start();
    }

    private void StartPingTimer()
    {
        _pingTimer?.Stop();
        _lastPongTime = DateTime.UtcNow;

        _pingTimer = new System.Timers.Timer(PointerPalsConfig.PingInterval * 1000);
        _pingTimer.Elapsed += async (_, _) =>
        {
            await SendPingAsync();
        };
        _pingTimer.Start();
    }

    private async Task SendPingAsync()
    {
        if (!_isConnected || _webSocket?.State != WebSocketState.Open) return;

        try
        {
            // Send an application-level ping message
            // The server will echo this back, updating our lastPongTime
            var message = new Dictionary<string, object>
            {
                ["action"] = "ping"
            };

            await SendMessageAsync(message);

            if (PointerPalsConfig.DebugLogging)
            {
                Console.WriteLine("Ping sent");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Ping failed: {ex.Message}");
            _isConnected = false;
            ConnectionStateChanged?.Invoke(false);
            ScheduleReconnect();
        }
    }

    private void ScheduleReconnect()
    {
        if (_isDisposed) return;

        _pingTimer?.Stop();

        Console.WriteLine($"Scheduling reconnect in {PointerPalsConfig.ReconnectionInterval} seconds...");
        Task.Delay(TimeSpan.FromSeconds(PointerPalsConfig.ReconnectionInterval))
            .ContinueWith(_ => ConnectAsync());
    }

    public void Dispose()
    {
        if (_isDisposed) return;
        _isDisposed = true;

        _reconnectTimer?.Stop();
        _reconnectTimer?.Dispose();
        _pingTimer?.Stop();
        _pingTimer?.Dispose();
        _cancellationTokenSource?.Cancel();
        _webSocket?.Dispose();
    }
}
