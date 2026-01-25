using System.Text.Json.Serialization;

namespace PointerPals.Models;

/// <summary>
/// Represents cursor position data transmitted between clients via WebSocket
/// </summary>
public class CursorData
{
    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;

    [JsonPropertyName("username")]
    public string? Username { get; set; }

    [JsonPropertyName("x")]
    public double X { get; set; }

    [JsonPropertyName("y")]
    public double Y { get; set; }

    [JsonPropertyName("timestamp")]
    public DateTime Timestamp { get; set; }

    public CursorData() { }

    public CursorData(string userId, string? username, double x, double y, DateTime timestamp)
    {
        UserId = userId;
        Username = username;
        // Clamp coordinates to 0.0-1.0 range
        X = Math.Max(0.0, Math.Min(1.0, x));
        Y = Math.Max(0.0, Math.Min(1.0, y));
        Timestamp = timestamp;
    }
}
