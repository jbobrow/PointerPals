using Microsoft.Win32;
using System.Windows;

namespace PointerPals.Config;

/// <summary>
/// Configuration settings for PointerPals
/// Mirrors the macOS Swift configuration for consistency
/// </summary>
public static class PointerPalsConfig
{
    // Registry key for storing settings
    private const string RegistryKeyPath = @"SOFTWARE\PointerPals";

    #region Network Configuration

    /// <summary>
    /// Default WebSocket server URL
    /// </summary>
    public const string DefaultServerURL = "wss://pointerpals-server.jonbobrow.com";

    /// <summary>
    /// Get the server URL (custom if set, otherwise default)
    /// </summary>
    public static string ServerURL
    {
        get
        {
            var customUrl = GetSetting<string>("ServerURL");
            return !string.IsNullOrEmpty(customUrl) ? customUrl : DefaultServerURL;
        }
        set => SetSetting("ServerURL", value);
    }

    /// <summary>
    /// Get the custom server URL if set, null otherwise
    /// </summary>
    public static string? CustomServerURL => GetSetting<string>("ServerURL");

    #endregion

    #region Cursor Publishing

    /// <summary>
    /// Frames per second for cursor position updates (20-60 recommended)
    /// </summary>
    public const double PublishingFPS = 30.0;

    /// <summary>
    /// Publishing interval in milliseconds
    /// </summary>
    public static double PublishingIntervalMs => 1000.0 / PublishingFPS;

    /// <summary>
    /// Only publish cursor updates when position changes
    /// </summary>
    public const bool OnlyPublishOnChange = true;

    #endregion

    #region Cursor Display

    /// <summary>
    /// Base size of the cursor overlay
    /// </summary>
    public static Size CursorSize => new(14, 24);

    /// <summary>
    /// Default cursor scale (0.75 = 75% of natural size)
    /// </summary>
    public const double DefaultCursorScale = 0.75;

    /// <summary>
    /// Opacity of active subscribed cursors (0.0 to 1.0)
    /// </summary>
    public const double ActiveCursorOpacity = 1.0;

    /// <summary>
    /// Duration of fade-in animation (seconds)
    /// </summary>
    public const double FadeInDuration = 0.3;

    /// <summary>
    /// Duration of fade-out animation (seconds)
    /// </summary>
    public const double FadeOutDuration = 1.0;

    /// <summary>
    /// Duration of cursor position animation (seconds)
    /// </summary>
    public const double CursorAnimationDuration = 0.1;

    #endregion

    #region Inactivity

    /// <summary>
    /// Time in seconds before inactive cursors fade out
    /// </summary>
    public const double InactivityTimeout = 5.0;

    #endregion

    #region User Interface

    /// <summary>
    /// Show subscription count in system tray tooltip
    /// </summary>
    public const bool ShowSubscriptionCount = true;

    /// <summary>
    /// Maximum username length (characters)
    /// </summary>
    public const int MaxUsernameLength = 32;

    #endregion

    #region Advanced

    /// <summary>
    /// Enable debug logging
    /// </summary>
    public const bool DebugLogging = false;

    /// <summary>
    /// Reconnection interval (seconds) if connection lost
    /// </summary>
    public const double ReconnectionInterval = 2.0;

    /// <summary>
    /// Connection health check interval (seconds)
    /// </summary>
    public const double ConnectionCheckInterval = 5.0;

    /// <summary>
    /// Maximum number of simultaneous subscriptions (0 = unlimited)
    /// </summary>
    public const int MaxSubscriptions = 0;

    /// <summary>
    /// Clamp cursor coordinates to screen bounds
    /// </summary>
    public const bool ClampCoordinates = true;

    #endregion

    #region User Preferences (Persisted)

    public static string UserId
    {
        get
        {
            var id = GetSetting<string>("UserId");
            if (string.IsNullOrEmpty(id))
            {
                id = $"user_{Guid.NewGuid().ToString()[..8]}";
                UserId = id;
            }
            return id;
        }
        set => SetSetting("UserId", value);
    }

    public static string Username
    {
        get => GetSetting<string>("Username") ?? "User";
        set => SetSetting("Username", value);
    }

    public static bool ShowUsernames
    {
        get => GetSetting<bool>("ShowUsernames");
        set => SetSetting("ShowUsernames", value);
    }

    public static double CursorScale
    {
        get
        {
            var scale = GetSetting<double>("CursorScale");
            return scale > 0 ? scale : DefaultCursorScale;
        }
        set => SetSetting("CursorScale", value);
    }

    public static bool LaunchOnStartup
    {
        get => GetSetting<bool>("LaunchOnStartup");
        set
        {
            SetSetting("LaunchOnStartup", value);
            SetStartupRegistry(value);
        }
    }

    public static bool HasLaunchedBefore
    {
        get => GetSetting<bool>("HasLaunchedBefore");
        set => SetSetting("HasLaunchedBefore", value);
    }

    public static List<string> Subscriptions
    {
        get
        {
            var json = GetSetting<string>("Subscriptions");
            if (string.IsNullOrEmpty(json)) return new List<string>();
            try
            {
                return System.Text.Json.JsonSerializer.Deserialize<List<string>>(json) ?? new List<string>();
            }
            catch
            {
                return new List<string>();
            }
        }
        set
        {
            var json = System.Text.Json.JsonSerializer.Serialize(value);
            SetSetting("Subscriptions", json);
        }
    }

    public static Dictionary<string, bool> SubscriptionStates
    {
        get
        {
            var json = GetSetting<string>("SubscriptionStates");
            if (string.IsNullOrEmpty(json)) return new Dictionary<string, bool>();
            try
            {
                return System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, bool>>(json) ?? new Dictionary<string, bool>();
            }
            catch
            {
                return new Dictionary<string, bool>();
            }
        }
        set
        {
            var json = System.Text.Json.JsonSerializer.Serialize(value);
            SetSetting("SubscriptionStates", json);
        }
    }

    public static Dictionary<string, string> SubscriptionUsernames
    {
        get
        {
            var json = GetSetting<string>("SubscriptionUsernames");
            if (string.IsNullOrEmpty(json)) return new Dictionary<string, string>();
            try
            {
                return System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(json) ?? new Dictionary<string, string>();
            }
            catch
            {
                return new Dictionary<string, string>();
            }
        }
        set
        {
            var json = System.Text.Json.JsonSerializer.Serialize(value);
            SetSetting("SubscriptionUsernames", json);
        }
    }

    #endregion

    #region Helper Methods

    /// <summary>
    /// Validate that a server URL is properly formatted for WebSocket
    /// </summary>
    public static bool IsValidServerURL(string urlString)
    {
        if (string.IsNullOrEmpty(urlString)) return false;
        if (!Uri.TryCreate(urlString, UriKind.Absolute, out var uri)) return false;
        return uri.Scheme == "ws" || uri.Scheme == "wss";
    }

    private static T? GetSetting<T>(string name)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RegistryKeyPath);
            var value = key?.GetValue(name);
            if (value == null) return default;

            if (typeof(T) == typeof(bool))
            {
                return (T)(object)(Convert.ToInt32(value) == 1);
            }
            if (typeof(T) == typeof(double))
            {
                return (T)(object)Convert.ToDouble(value);
            }
            return (T)value;
        }
        catch
        {
            return default;
        }
    }

    private static void SetSetting<T>(string name, T value)
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(RegistryKeyPath);
            if (value is bool b)
            {
                key?.SetValue(name, b ? 1 : 0, RegistryValueKind.DWord);
            }
            else if (value is double d)
            {
                key?.SetValue(name, d.ToString(), RegistryValueKind.String);
            }
            else
            {
                key?.SetValue(name, value?.ToString() ?? "", RegistryValueKind.String);
            }
        }
        catch
        {
            // Ignore registry errors
        }
    }

    private static void SetStartupRegistry(bool enable)
    {
        try
        {
            const string runKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
            using var key = Registry.CurrentUser.OpenSubKey(runKey, true);
            if (key == null) return;

            if (enable)
            {
                var exePath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName;
                if (!string.IsNullOrEmpty(exePath))
                {
                    key.SetValue("PointerPals", $"\"{exePath}\"");
                }
            }
            else
            {
                key.DeleteValue("PointerPals", false);
            }
        }
        catch
        {
            // Ignore startup registry errors
        }
    }

    #endregion
}
