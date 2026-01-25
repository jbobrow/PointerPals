using System.Windows;
using PointerPals.Config;

namespace PointerPals.Views;

public partial class ServerSettingsWindow : Window
{
    public ServerSettingsWindow()
    {
        InitializeComponent();

        // Load current server URL
        ServerUrlTextBox.Text = PointerPalsConfig.CustomServerURL ?? PointerPalsConfig.DefaultServerURL;
    }

    private void ResetToDefault_Click(object sender, RoutedEventArgs e)
    {
        ServerUrlTextBox.Text = PointerPalsConfig.DefaultServerURL;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var url = ServerUrlTextBox.Text.Trim();

        if (!PointerPalsConfig.IsValidServerURL(url))
        {
            MessageBox.Show(
                "Please enter a valid WebSocket URL (ws:// or wss://)",
                "Invalid Server URL",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            return;
        }

        PointerPalsConfig.ServerURL = url;

        MessageBox.Show(
            "Server address saved. Please restart the app for the change to take effect.",
            "Server Address Saved",
            MessageBoxButton.OK,
            MessageBoxImage.Information);

        DialogResult = true;
        Close();
    }
}
