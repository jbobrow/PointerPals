using System.Windows.Threading;
using PointerPals.Config;
using PointerPals.Models;
using PointerPals.Views;

namespace PointerPals.Managers;

/// <summary>
/// Manages remote cursor windows and subscriptions
/// </summary>
public class CursorManager : IDisposable
{
    private readonly NetworkManager _networkManager;
    private readonly Dictionary<string, CursorOverlayWindow> _cursorWindows = new();
    private readonly Dictionary<string, DispatcherTimer> _inactivityTimers = new();
    private readonly Dispatcher _dispatcher;
    private bool _shouldShowUsernames;
    private double _cursorScale;
    private bool _isDisposed;

    // Persisted state
    private Dictionary<string, bool> _subscriptionStates;
    private Dictionary<string, string> _usernames;

    public event Action? SubscriptionsChanged;

    public IReadOnlyList<string> AllSubscriptions => _subscriptionStates.Keys.ToList();

    public int ActiveSubscriptionsCount => _subscriptionStates.Values.Count(v => v);

    public CursorManager(NetworkManager networkManager, double cursorScale = PointerPalsConfig.DefaultCursorScale)
    {
        _networkManager = networkManager;
        _cursorScale = cursorScale;
        _shouldShowUsernames = PointerPalsConfig.ShowUsernames;
        _dispatcher = Dispatcher.CurrentDispatcher;

        // Load persisted state
        _subscriptionStates = PointerPalsConfig.SubscriptionStates;
        _usernames = PointerPalsConfig.SubscriptionUsernames;

        // Subscribe to network events
        _networkManager.CursorUpdateReceived += OnCursorUpdateReceived;
        _networkManager.UsernameUpdateReceived += OnUsernameUpdateReceived;

        // Restore active subscriptions
        LoadSubscriptions();
    }

    private void LoadSubscriptions()
    {
        foreach (var (userId, isEnabled) in _subscriptionStates)
        {
            if (isEnabled)
            {
                EnableSubscription(userId);
            }
        }
    }

    private void SaveSubscriptions()
    {
        PointerPalsConfig.SubscriptionStates = _subscriptionStates;
        PointerPalsConfig.SubscriptionUsernames = _usernames;
    }

    public string? GetUsername(string userId)
    {
        return _usernames.TryGetValue(userId, out var username) ? username : null;
    }

    public bool IsSubscriptionEnabled(string userId)
    {
        return _subscriptionStates.TryGetValue(userId, out var isEnabled) && isEnabled;
    }

    public void Subscribe(string userId)
    {
        if (_subscriptionStates.ContainsKey(userId))
        {
            Console.WriteLine($"Subscription already exists for {userId}");
            return;
        }

        if (PointerPalsConfig.MaxSubscriptions > 0 && _subscriptionStates.Count >= PointerPalsConfig.MaxSubscriptions)
        {
            Console.WriteLine($"Maximum subscription limit reached ({PointerPalsConfig.MaxSubscriptions})");
            return;
        }

        _subscriptionStates[userId] = true;
        EnableSubscription(userId);
        SaveSubscriptions();
        SubscriptionsChanged?.Invoke();

        if (PointerPalsConfig.DebugLogging)
        {
            Console.WriteLine($"Subscribed to {userId}");
        }
    }

    public void ToggleSubscription(string userId)
    {
        if (!_subscriptionStates.TryGetValue(userId, out var isEnabled))
        {
            Console.WriteLine($"No subscription found for {userId}");
            return;
        }

        if (isEnabled)
        {
            DisableSubscription(userId);
        }
        else
        {
            EnableSubscription(userId);
        }

        _subscriptionStates[userId] = !isEnabled;
        SaveSubscriptions();
        SubscriptionsChanged?.Invoke();

        Console.WriteLine($"{(isEnabled ? "Disabled" : "Enabled")} subscription for {userId}");
    }

    public void DeleteSubscription(string userId)
    {
        if (_subscriptionStates.TryGetValue(userId, out var isEnabled) && isEnabled)
        {
            DisableSubscription(userId);
        }

        _subscriptionStates.Remove(userId);
        _usernames.Remove(userId);

        SaveSubscriptions();
        SubscriptionsChanged?.Invoke();

        Console.WriteLine($"Deleted subscription for {userId}");
    }

    private void EnableSubscription(string userId)
    {
        if (_cursorWindows.ContainsKey(userId))
        {
            return;
        }

        _dispatcher.Invoke(() =>
        {
            var window = new CursorOverlayWindow(userId, _cursorScale);
            window.Show();
            _cursorWindows[userId] = window;
        });

        _networkManager.SubscribeTo(userId);
    }

    private void DisableSubscription(string userId)
    {
        if (_cursorWindows.TryGetValue(userId, out var window))
        {
            _dispatcher.Invoke(() =>
            {
                window.Close();
            });
            _cursorWindows.Remove(userId);
        }

        if (_inactivityTimers.TryGetValue(userId, out var timer))
        {
            timer.Stop();
            _inactivityTimers.Remove(userId);
        }

        _networkManager.UnsubscribeFrom(userId);
    }

    public void SetUsernameVisibility(bool visible)
    {
        _shouldShowUsernames = visible;
        PointerPalsConfig.ShowUsernames = visible;

        foreach (var window in _cursorWindows.Values)
        {
            _dispatcher.Invoke(() =>
            {
                window.SetUsernameVisibility(visible);
            });
        }
    }

    public void SetCursorScale(double scale)
    {
        _cursorScale = scale;
        PointerPalsConfig.CursorScale = scale;

        // Recreate all windows with new scale
        var activeUserIds = _cursorWindows.Keys.ToList();
        foreach (var userId in activeUserIds)
        {
            DisableSubscription(userId);
            EnableSubscription(userId);
        }
    }

    private void OnCursorUpdateReceived(CursorData cursorData)
    {
        _dispatcher.Invoke(() =>
        {
            if (!_cursorWindows.TryGetValue(cursorData.UserId, out var window))
            {
                return;
            }

            // Update stored username if changed
            if (!string.IsNullOrEmpty(cursorData.Username))
            {
                var oldUsername = _usernames.GetValueOrDefault(cursorData.UserId);
                if (oldUsername != cursorData.Username)
                {
                    _usernames[cursorData.UserId] = cursorData.Username;
                    SaveSubscriptions();
                    SubscriptionsChanged?.Invoke();
                }
            }

            // Cancel existing inactivity timer
            if (_inactivityTimers.TryGetValue(cursorData.UserId, out var existingTimer))
            {
                existingTimer.Stop();
            }

            // Update username display
            if (_shouldShowUsernames)
            {
                window.UpdateUsername(cursorData.Username);
            }
            else
            {
                window.UpdateUsername(null);
            }

            // Fade in and update position
            window.FadeIn();
            window.UpdatePosition(cursorData.X, cursorData.Y);

            // Start new inactivity timer
            var timer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(PointerPalsConfig.InactivityTimeout)
            };
            timer.Tick += (_, _) =>
            {
                timer.Stop();
                if (_cursorWindows.TryGetValue(cursorData.UserId, out var w))
                {
                    w.FadeOut();
                }
                _inactivityTimers.Remove(cursorData.UserId);
            };
            timer.Start();
            _inactivityTimers[cursorData.UserId] = timer;
        });
    }

    private void OnUsernameUpdateReceived(string userId, string username)
    {
        _dispatcher.Invoke(() =>
        {
            _usernames[userId] = username;
            SaveSubscriptions();

            if (_shouldShowUsernames && _cursorWindows.TryGetValue(userId, out var window))
            {
                window.UpdateUsername(username);
            }

            SubscriptionsChanged?.Invoke();
        });
    }

    public void Dispose()
    {
        if (_isDisposed) return;
        _isDisposed = true;

        _networkManager.CursorUpdateReceived -= OnCursorUpdateReceived;
        _networkManager.UsernameUpdateReceived -= OnUsernameUpdateReceived;

        foreach (var timer in _inactivityTimers.Values)
        {
            timer.Stop();
        }
        _inactivityTimers.Clear();

        _dispatcher.Invoke(() =>
        {
            foreach (var window in _cursorWindows.Values)
            {
                window.Close();
            }
            _cursorWindows.Clear();
        });
    }
}
