using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using PointerPals.Config;
using PointerPals.Managers;

namespace PointerPals.Views;

public partial class WelcomeWindow : Window
{
    private readonly NetworkManager _networkManager;
    private int _currentStep = 1;
    private const int TotalSteps = 4;

    /// <summary>
    /// The first pal ID entered by the user (if any)
    /// </summary>
    public string? FirstPalId { get; private set; }

    public WelcomeWindow(NetworkManager networkManager)
    {
        InitializeComponent();

        _networkManager = networkManager;

        // Initialize with current values
        UsernameTextBox.Text = networkManager.CurrentUsername;
        PointerIdText.Text = networkManager.CurrentUserId;
    }

    private void UsernameTextBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        if (UsernameHint != null)
        {
            var remaining = PointerPalsConfig.MaxUsernameLength - UsernameTextBox.Text.Length;
            UsernameHint.Text = $"{remaining} characters remaining";
        }
    }

    private void CopyId_Click(object sender, RoutedEventArgs e)
    {
        Clipboard.SetText(_networkManager.CurrentUserId);

        CopyIdButton.Content = "Copied!";

        var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.5) };
        timer.Tick += (_, _) =>
        {
            CopyIdButton.Content = "Copy to Clipboard";
            timer.Stop();
        };
        timer.Start();
    }

    private void Back_Click(object sender, RoutedEventArgs e)
    {
        if (_currentStep > 1)
        {
            _currentStep--;
            UpdateStep();
        }
    }

    private void Next_Click(object sender, RoutedEventArgs e)
    {
        // Validate current step
        if (_currentStep == 2)
        {
            var username = UsernameTextBox.Text.Trim();
            if (string.IsNullOrEmpty(username))
            {
                MessageBox.Show("Please enter a username.", "Username Required", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
        }

        if (_currentStep < TotalSteps)
        {
            // Save data when leaving step 2
            if (_currentStep == 2)
            {
                _networkManager.CurrentUsername = UsernameTextBox.Text.Trim();
            }

            _currentStep++;
            UpdateStep();
        }
        else
        {
            // Complete setup
            CompleteSetup();
        }
    }

    private void UpdateStep()
    {
        // Hide all panels
        Step1Panel.Visibility = Visibility.Collapsed;
        Step2Panel.Visibility = Visibility.Collapsed;
        Step3Panel.Visibility = Visibility.Collapsed;
        Step4Panel.Visibility = Visibility.Collapsed;

        // Reset all dots
        var inactiveColor = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#E0E0E0")!);
        var activeColor = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#007AFF")!);

        Step1Dot.Fill = inactiveColor;
        Step2Dot.Fill = inactiveColor;
        Step3Dot.Fill = inactiveColor;
        Step4Dot.Fill = inactiveColor;

        // Show current panel and highlight dot
        switch (_currentStep)
        {
            case 1:
                Step1Panel.Visibility = Visibility.Visible;
                Step1Dot.Fill = activeColor;
                NextButton.Content = "Get Started";
                BackButton.Visibility = Visibility.Collapsed;
                break;

            case 2:
                Step2Panel.Visibility = Visibility.Visible;
                Step2Dot.Fill = activeColor;
                NextButton.Content = "Continue";
                BackButton.Visibility = Visibility.Visible;
                UsernameTextBox.Focus();
                break;

            case 3:
                Step3Panel.Visibility = Visibility.Visible;
                Step3Dot.Fill = activeColor;
                NextButton.Content = "Continue";
                BackButton.Visibility = Visibility.Visible;
                break;

            case 4:
                Step4Panel.Visibility = Visibility.Visible;
                Step4Dot.Fill = activeColor;
                NextButton.Content = "Finish";
                BackButton.Visibility = Visibility.Visible;
                FirstPalIdTextBox.Focus();
                break;
        }
    }

    private void CompleteSetup()
    {
        // Save launch on startup preference
        PointerPalsConfig.LaunchOnStartup = LaunchOnStartupCheckBox.IsChecked == true;

        // Store the first pal ID if entered
        var palId = FirstPalIdTextBox.Text.Trim();
        if (!string.IsNullOrEmpty(palId))
        {
            FirstPalId = palId;
        }

        Close();
    }
}
