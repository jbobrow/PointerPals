using System.Drawing;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Hardcodet.Wpf.TaskbarNotification;
using PointerPals.Config;
using PointerPals.Managers;
using PointerPals.Views;

namespace PointerPals;

/// <summary>
/// Main application class - runs as a system tray application
/// </summary>
public partial class App : Application
{
    private TaskbarIcon? _taskbarIcon;
    private NetworkManager? _networkManager;
    private CursorPublisher? _cursorPublisher;
    private CursorManager? _cursorManager;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Initialize managers
        _networkManager = new NetworkManager();
        _cursorPublisher = new CursorPublisher(_networkManager);
        _cursorManager = new CursorManager(_networkManager, PointerPalsConfig.CursorScale);

        // Subscribe to changes
        _cursorManager.SubscriptionsChanged += UpdateContextMenu;

        // Create system tray icon
        CreateTaskbarIcon();

        // Start publishing cursor position
        _cursorPublisher.StartPublishing();

        // Check for first launch
        CheckFirstLaunch();
    }

    private void CreateTaskbarIcon()
    {
        _taskbarIcon = new TaskbarIcon
        {
            ToolTipText = GetTooltipText(),
            Icon = CreateTrayIcon(),
            ContextMenu = CreateContextMenu()
        };

        _taskbarIcon.TrayMouseDoubleClick += (_, _) => ShowSettings();
    }

    private Icon CreateTrayIcon()
    {
        // Create a simple cursor icon programmatically
        var bitmap = new Bitmap(16, 16);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.Clear(System.Drawing.Color.Transparent);

            // Draw a simple arrow cursor
            var points = new System.Drawing.Point[]
            {
                new(1, 1),
                new(1, 13),
                new(4, 10),
                new(7, 15),
                new(9, 14),
                new(6, 9),
                new(11, 9)
            };

            using var fillBrush = new SolidBrush(System.Drawing.Color.Black);
            using var outlinePen = new Pen(System.Drawing.Color.White, 1);

            g.FillPolygon(fillBrush, points);
            g.DrawPolygon(outlinePen, points);
        }

        return Icon.FromHandle(bitmap.GetHicon());
    }

    private string GetTooltipText()
    {
        var count = _cursorManager?.ActiveSubscriptionsCount ?? 0;
        return PointerPalsConfig.ShowSubscriptionCount
            ? $"PointerPals - {count} active"
            : "PointerPals";
    }

    private ContextMenu CreateContextMenu()
    {
        var menu = new ContextMenu();

        // Add a Pal
        var addItem = new MenuItem { Header = "Add a Pal..." };
        addItem.Click += (_, _) => ShowAddPalDialog();
        menu.Items.Add(addItem);

        menu.Items.Add(new Separator());

        // My PointerPals header
        var headerItem = new MenuItem { Header = "My PointerPals", IsEnabled = false };
        menu.Items.Add(headerItem);

        // Subscription list
        var subscriptions = _cursorManager?.AllSubscriptions ?? Array.Empty<string>();
        if (subscriptions.Count == 0)
        {
            var noSubs = new MenuItem { Header = "  --None yet--", IsEnabled = false };
            menu.Items.Add(noSubs);
        }
        else
        {
            foreach (var userId in subscriptions)
            {
                var isEnabled = _cursorManager!.IsSubscriptionEnabled(userId);
                var username = _cursorManager.GetUsername(userId) ?? "User";
                var stateIcon = isEnabled ? "✓" : "○";

                var subItem = new MenuItem
                {
                    Header = $"  {stateIcon} {username} ({userId})",
                    Tag = userId
                };

                // Create submenu for toggle/delete
                var toggleItem = new MenuItem
                {
                    Header = isEnabled ? "Disable" : "Enable",
                    Tag = userId
                };
                toggleItem.Click += ToggleSubscription_Click;

                var deleteItem = new MenuItem
                {
                    Header = "Delete",
                    Tag = userId
                };
                deleteItem.Click += DeleteSubscription_Click;

                subItem.Items.Add(toggleItem);
                subItem.Items.Add(deleteItem);

                // Also allow clicking the main item to toggle
                subItem.Click += ToggleSubscription_Click;

                menu.Items.Add(subItem);
            }
        }

        menu.Items.Add(new Separator());

        // Settings
        var settingsItem = new MenuItem { Header = "Settings..." };
        settingsItem.Click += (_, _) => ShowSettings();
        menu.Items.Add(settingsItem);

        menu.Items.Add(new Separator());

        // Quit
        var quitItem = new MenuItem { Header = "Quit PointerPals" };
        quitItem.Click += (_, _) => Quit();
        menu.Items.Add(quitItem);

        return menu;
    }

    private void UpdateContextMenu()
    {
        if (_taskbarIcon == null) return;

        Dispatcher.Invoke(() =>
        {
            _taskbarIcon.ContextMenu = CreateContextMenu();
            _taskbarIcon.ToolTipText = GetTooltipText();
        });
    }

    private void ToggleSubscription_Click(object sender, RoutedEventArgs e)
    {
        if (sender is MenuItem item && item.Tag is string userId)
        {
            _cursorManager?.ToggleSubscription(userId);
        }
    }

    private void DeleteSubscription_Click(object sender, RoutedEventArgs e)
    {
        if (sender is MenuItem item && item.Tag is string userId)
        {
            _cursorManager?.DeleteSubscription(userId);
        }
    }

    private void ShowAddPalDialog()
    {
        var dialog = new AddPalWindow();
        dialog.ShowDialog();

        if (dialog.DialogResult == true && !string.IsNullOrWhiteSpace(dialog.PointerId))
        {
            _cursorManager?.Subscribe(dialog.PointerId.Trim());
        }
    }

    private void ShowSettings()
    {
        var settingsWindow = new SettingsWindow(_networkManager!, _cursorManager!);
        settingsWindow.ShowDialog();
    }

    private void CheckFirstLaunch()
    {
        if (!PointerPalsConfig.HasLaunchedBefore)
        {
            PointerPalsConfig.HasLaunchedBefore = true;

            // Show welcome window
            Dispatcher.BeginInvoke(() =>
            {
                var welcomeWindow = new WelcomeWindow(_networkManager!);
                welcomeWindow.ShowDialog();
            }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
        }
    }

    private void Quit()
    {
        _cursorPublisher?.Dispose();
        _cursorManager?.Dispose();
        _networkManager?.Dispose();
        _taskbarIcon?.Dispose();

        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _cursorPublisher?.Dispose();
        _cursorManager?.Dispose();
        _networkManager?.Dispose();
        _taskbarIcon?.Dispose();

        base.OnExit(e);
    }
}
