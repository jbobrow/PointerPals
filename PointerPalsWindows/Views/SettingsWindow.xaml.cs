using System.Windows;
using System.Windows.Threading;
using PointerPals.Config;
using PointerPals.Managers;

namespace PointerPals.Views;

public partial class SettingsWindow : Window
{
    private readonly NetworkManager _networkManager;
    private readonly CursorManager _cursorManager;
    private readonly string _originalUsername;
    private CursorOverlayWindow? _demoCursor;
    private DispatcherTimer? _demoTimer;
    private DispatcherTimer? _copyFeedbackTimer;
    private int _demoFrame;
    private const int TotalDemoFrames = 360; // 6 seconds at 60fps
    private bool _isInitialized;
    private bool _isClosed;

    public SettingsWindow(NetworkManager networkManager, CursorManager cursorManager)
    {
        InitializeComponent();

        _networkManager = networkManager;
        _cursorManager = cursorManager;
        _originalUsername = networkManager.CurrentUsername;

        // Initialize controls (events will be ignored until _isInitialized is true)
        UsernameTextBox.Text = networkManager.CurrentUsername;
        PointerIdTextBox.Text = networkManager.CurrentUserId;
        ShowUsernamesCheckBox.IsChecked = PointerPalsConfig.ShowUsernames;
        CursorSizeSlider.Value = PointerPalsConfig.CursorScale;
        CursorSizeLabel.Text = $"{(int)(PointerPalsConfig.CursorScale * 100)}%";
        LaunchOnStartupCheckBox.IsChecked = PointerPalsConfig.LaunchOnStartup;

        // Done initializing - events can now take effect
        _isInitialized = true;
    }

    private void UsernameTextBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        if (!_isInitialized) return;
        var currentText = UsernameTextBox.Text.Trim();
        var hasChanged = !string.IsNullOrEmpty(currentText) && currentText != _originalUsername;
        SaveUsernameButton.IsEnabled = hasChanged;
    }

    private void SaveUsername_Click(object sender, RoutedEventArgs e)
    {
        var newUsername = UsernameTextBox.Text.Trim();
        if (!string.IsNullOrEmpty(newUsername) && newUsername.Length <= PointerPalsConfig.MaxUsernameLength)
        {
            _networkManager.CurrentUsername = newUsername;
            SaveUsernameButton.IsEnabled = false;
        }
    }

    private void CopyId_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Clipboard.SetText(_networkManager.CurrentUserId);

            // Show feedback
            CopyIdButton.Content = "Copied!";

            // Stop any existing timer
            _copyFeedbackTimer?.Stop();

            // Create new timer to restore button text
            _copyFeedbackTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.5) };
            _copyFeedbackTimer.Tick += (_, _) =>
            {
                _copyFeedbackTimer.Stop();
                if (!_isClosed)
                {
                    CopyIdButton.Content = "Copy Pointer ID to Share with Pals";
                }
            };
            _copyFeedbackTimer.Start();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed to copy to clipboard: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    private void ShowUsernames_Changed(object sender, RoutedEventArgs e)
    {
        if (!_isInitialized) return;
        _cursorManager.SetUsernameVisibility(ShowUsernamesCheckBox.IsChecked == true);
    }

    private void CursorSizeSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (CursorSizeLabel != null)
        {
            CursorSizeLabel.Text = $"{(int)(e.NewValue * 100)}%";
            if (_isInitialized)
            {
                _cursorManager?.SetCursorScale(e.NewValue);
            }
        }
    }

    private void LaunchOnStartup_Changed(object sender, RoutedEventArgs e)
    {
        if (!_isInitialized) return;
        PointerPalsConfig.LaunchOnStartup = LaunchOnStartupCheckBox.IsChecked == true;
    }

    private void Demo_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (_demoCursor != null)
            {
                StopDemo();
            }
            else
            {
                StartDemo();
            }
        }
        catch (Exception ex)
        {
            StopDemo();
            MessageBox.Show($"Demo error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    private void StartDemo()
    {
        try
        {
            _demoCursor = new CursorOverlayWindow("demo", PointerPalsConfig.CursorScale);
            _demoCursor.UpdateUsername("Demo");
            _demoCursor.Show();

            // Set initial position (center of screen)
            _demoCursor.UpdatePosition(0.5, 0.5);

            // Start animation
            _demoFrame = 0;
            _demoTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(1000.0 / 60) };
            _demoTimer.Tick += DemoTimer_Tick;
            _demoTimer.Start();

            // Fade in
            _demoCursor.FadeIn();

            DemoButton.Content = "Stop";
        }
        catch (Exception)
        {
            StopDemo();
            throw;
        }
    }

    private void DemoTimer_Tick(object? sender, EventArgs e)
    {
        try
        {
            if (_demoCursor == null || _isClosed)
            {
                StopDemo();
                return;
            }

            _demoFrame++;
            var progress = (double)_demoFrame / TotalDemoFrames;

            // Eased progress for smooth start/stop
            var eased = progress * progress * (3.0 - 2.0 * progress);

            // Calculate angle (start at top, go clockwise)
            var startAngle = -Math.PI / 2;
            var angle = startAngle + (eased * 2.0 * Math.PI);

            // Circle parameters
            var radiusX = 0.15;
            var radiusY = 0.15;
            var centerX = 0.5;
            var centerY = 0.5;

            // Calculate position
            var x = centerX + (radiusX * Math.Cos(angle));
            var y = centerY + (radiusY * Math.Sin(angle));

            _demoCursor.UpdatePosition(x, y);

            // Fade out in the last 10%
            if (progress > 0.9 && _demoFrame == (int)(TotalDemoFrames * 0.9))
            {
                _demoCursor.FadeOut();
            }

            // Complete
            if (_demoFrame >= TotalDemoFrames)
            {
                StopDemo();
            }
        }
        catch (Exception)
        {
            StopDemo();
        }
    }

    private void StopDemo()
    {
        _demoTimer?.Stop();
        _demoTimer = null;

        try
        {
            _demoCursor?.Close();
        }
        catch { }
        _demoCursor = null;

        if (!_isClosed)
        {
            DemoButton.Content = "Demo";
        }
    }

    private void ConfigureServer_Click(object sender, RoutedEventArgs e)
    {
        var serverWindow = new ServerSettingsWindow();
        serverWindow.Owner = this;
        serverWindow.ShowDialog();
    }

    private void Done_Click(object sender, RoutedEventArgs e)
    {
        // Check for unsaved username changes
        var currentText = UsernameTextBox.Text.Trim();
        if (!string.IsNullOrEmpty(currentText) && currentText != _networkManager.CurrentUsername)
        {
            var result = MessageBox.Show(
                $"Save username as \"{currentText}\"?",
                "Unsaved Changes",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (result == MessageBoxResult.Yes)
            {
                _networkManager.CurrentUsername = currentText;
            }
        }

        StopDemo();
        Close();
    }

    protected override void OnClosed(EventArgs e)
    {
        _isClosed = true;
        _copyFeedbackTimer?.Stop();
        StopDemo();
        base.OnClosed(e);
    }
}
