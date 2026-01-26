using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Threading;
using PointerPals.Config;
using PointerPals.Models;

namespace PointerPals.Managers;

/// <summary>
/// Publishes local cursor position to the network at configured intervals
/// </summary>
public class CursorPublisher : IDisposable
{
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int nIndex);

    private const int SM_CXSCREEN = 0;
    private const int SM_CYSCREEN = 1;

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    private readonly NetworkManager _networkManager;
    private DispatcherTimer? _timer;
    private Point? _lastPosition;
    private int _publishCount;
    private bool _isDisposed;

    public bool IsPublishing { get; private set; }

    public CursorPublisher(NetworkManager networkManager)
    {
        _networkManager = networkManager;
    }

    public void StartPublishing()
    {
        if (IsPublishing || _isDisposed) return;

        IsPublishing = true;

        _timer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(PointerPalsConfig.PublishingIntervalMs)
        };
        _timer.Tick += Timer_Tick;
        _timer.Start();

        Console.WriteLine($"Started publishing cursor position at {PointerPalsConfig.PublishingFPS} FPS");
    }

    public void StopPublishing()
    {
        _timer?.Stop();
        _timer = null;
        IsPublishing = false;
        Console.WriteLine("Stopped publishing cursor position");
    }

    private void Timer_Tick(object? sender, EventArgs e)
    {
        PublishCurrentPosition();
    }

    private void PublishCurrentPosition()
    {
        if (!GetCursorPos(out var point))
        {
            return;
        }

        var currentPosition = new Point(point.X, point.Y);

        // Only publish if position changed (if configured)
        if (PointerPalsConfig.OnlyPublishOnChange)
        {
            if (_lastPosition.HasValue && _lastPosition.Value == currentPosition)
            {
                return;
            }
        }

        // Get physical screen dimensions in pixels (matches GetCursorPos units)
        // Using GetSystemMetrics for primary screen - for multi-monitor would need more work
        var screenWidth = (double)GetSystemMetrics(SM_CXSCREEN);
        var screenHeight = (double)GetSystemMetrics(SM_CYSCREEN);

        // Normalize coordinates (0.0 to 1.0)
        var normalizedX = point.X / screenWidth;
        var normalizedY = 1.0 - (point.Y / screenHeight); // Flip Y axis (Windows Y is top-down)

        // Clamp coordinates if configured
        if (PointerPalsConfig.ClampCoordinates)
        {
            normalizedX = Math.Max(0.0, Math.Min(1.0, normalizedX));
            normalizedY = Math.Max(0.0, Math.Min(1.0, normalizedY));
        }

        var cursorData = new CursorData(
            _networkManager.CurrentUserId,
            _networkManager.CurrentUsername,
            normalizedX,
            normalizedY,
            DateTime.UtcNow
        );

        _ = _networkManager.PublishCursorPositionAsync(cursorData);
        _lastPosition = currentPosition;

        // Log every 30 publishes to avoid spam
        _publishCount++;
        if (_publishCount % 30 == 0)
        {
            Console.WriteLine($"Published {_publishCount} cursor positions (current: x={normalizedX:F2}, y={normalizedY:F2})");
        }
    }

    public void Dispose()
    {
        if (_isDisposed) return;
        _isDisposed = true;
        StopPublishing();
    }
}
