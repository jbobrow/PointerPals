using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using PointerPals.Config;

namespace PointerPals.Views;

/// <summary>
/// Overlay window that displays a remote user's cursor
/// </summary>
public partial class CursorOverlayWindow : Window
{
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    private const int GWL_EXSTYLE = -20;

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hwnd, int index);

    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);

    private readonly string _userId;
    private readonly double _cursorScale;
    private string? _currentUsername;
    private bool _showUsername = true;

    public CursorOverlayWindow(string userId, double cursorScale = PointerPalsConfig.DefaultCursorScale)
    {
        InitializeComponent();

        _userId = userId;
        _cursorScale = cursorScale;

        // Apply cursor scale
        CursorScaleTransform.ScaleX = _cursorScale;
        CursorScaleTransform.ScaleY = _cursorScale;

        // Update canvas size based on scale
        CursorCanvas.Width = 24 * _cursorScale;
        CursorCanvas.Height = 36 * _cursorScale;

        // Start invisible (will fade in on first update)
        Opacity = 0;

        // Make window click-through
        Loaded += OnLoaded;

        if (PointerPalsConfig.DebugLogging)
        {
            Console.WriteLine($"Created cursor window for {userId}");
        }
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        // Make window click-through and hide from taskbar/alt-tab
        var hwnd = new WindowInteropHelper(this).Handle;
        var extendedStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, extendedStyle | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW);
    }

    public void UpdateUsername(string? username)
    {
        _currentUsername = username;

        if (!string.IsNullOrEmpty(username) && _showUsername)
        {
            UsernameText.Text = username;
            UsernameBorder.Visibility = Visibility.Visible;
        }
        else
        {
            UsernameBorder.Visibility = Visibility.Collapsed;
        }
    }

    public void SetUsernameVisibility(bool visible)
    {
        _showUsername = visible;

        if (visible && !string.IsNullOrEmpty(_currentUsername))
        {
            UsernameText.Text = _currentUsername;
            UsernameBorder.Visibility = Visibility.Visible;
        }
        else
        {
            UsernameBorder.Visibility = Visibility.Collapsed;
        }
    }

    public void UpdatePosition(double normalizedX, double normalizedY)
    {
        // Get virtual screen bounds (supports multi-monitor)
        var screenLeft = SystemParameters.VirtualScreenLeft;
        var screenTop = SystemParameters.VirtualScreenTop;
        var screenWidth = SystemParameters.VirtualScreenWidth;
        var screenHeight = SystemParameters.VirtualScreenHeight;

        // Convert normalized coordinates to screen coordinates
        // Y is flipped because Windows Y is top-down, but normalized Y is bottom-up
        var screenX = screenLeft + (normalizedX * screenWidth);
        var screenY = screenTop + ((1.0 - normalizedY) * screenHeight);

        // Apply position with animation
        var duration = TimeSpan.FromSeconds(PointerPalsConfig.CursorAnimationDuration);

        var leftAnimation = new DoubleAnimation(screenX, duration)
        {
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
        };

        var topAnimation = new DoubleAnimation(screenY, duration)
        {
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
        };

        BeginAnimation(LeftProperty, leftAnimation);
        BeginAnimation(TopProperty, topAnimation);
    }

    public void FadeIn()
    {
        if (Opacity >= PointerPalsConfig.ActiveCursorOpacity) return;

        var animation = new DoubleAnimation(
            PointerPalsConfig.ActiveCursorOpacity,
            TimeSpan.FromSeconds(PointerPalsConfig.FadeInDuration))
        {
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
        };

        BeginAnimation(OpacityProperty, animation);
    }

    public void FadeOut()
    {
        var animation = new DoubleAnimation(
            0,
            TimeSpan.FromSeconds(PointerPalsConfig.FadeOutDuration))
        {
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseIn }
        };

        BeginAnimation(OpacityProperty, animation);
    }
}
