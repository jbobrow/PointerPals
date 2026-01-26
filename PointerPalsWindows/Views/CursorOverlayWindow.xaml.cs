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
    private const int SM_CXSCREEN = 0;
    private const int SM_CYSCREEN = 1;

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hwnd, int index);

    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll")]
    private static extern IntPtr GetDC(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

    [DllImport("gdi32.dll")]
    private static extern int GetDeviceCaps(IntPtr hdc, int nIndex);

    private const int LOGPIXELSX = 88;

    private readonly string _userId;
    private readonly double _cursorScale;
    private string? _currentUsername;
    private bool _showUsername = true;
    private readonly double _dpiScale;

    public CursorOverlayWindow(string userId, double cursorScale = PointerPalsConfig.DefaultCursorScale)
    {
        // Get DPI scale before InitializeComponent
        _dpiScale = GetDpiScale();

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

        // Make window click-through when loaded
        Loaded += OnLoaded;

        if (PointerPalsConfig.DebugLogging)
        {
            Console.WriteLine($"Created cursor window for {userId}, DPI scale: {_dpiScale}");
        }
    }

    private static double GetDpiScale()
    {
        var hdc = GetDC(IntPtr.Zero);
        if (hdc != IntPtr.Zero)
        {
            try
            {
                var dpi = GetDeviceCaps(hdc, LOGPIXELSX);
                return dpi / 96.0; // 96 DPI is the baseline (100%)
            }
            finally
            {
                ReleaseDC(IntPtr.Zero, hdc);
            }
        }
        return 1.0;
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
        // Get physical screen dimensions in pixels (matches publisher's normalization)
        var screenWidthPx = (double)GetSystemMetrics(SM_CXSCREEN);
        var screenHeightPx = (double)GetSystemMetrics(SM_CYSCREEN);

        // Convert normalized coordinates to physical pixel coordinates
        // Y is flipped because Windows Y is top-down, but normalized Y is bottom-up
        var pixelX = normalizedX * screenWidthPx;
        var pixelY = (1.0 - normalizedY) * screenHeightPx;

        // Convert physical pixels to WPF device-independent units (DIUs)
        // WPF Window.Left/Top use DIUs, not physical pixels
        var screenX = pixelX / _dpiScale;
        var screenY = pixelY / _dpiScale;

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
