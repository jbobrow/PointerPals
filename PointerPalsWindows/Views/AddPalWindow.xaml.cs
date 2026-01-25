using System.Windows;

namespace PointerPals.Views;

public partial class AddPalWindow : Window
{
    public string PointerId => PointerIdTextBox.Text;

    public AddPalWindow()
    {
        InitializeComponent();
        PointerIdTextBox.Focus();
    }

    private void Add_Click(object sender, RoutedEventArgs e)
    {
        if (!string.IsNullOrWhiteSpace(PointerIdTextBox.Text))
        {
            DialogResult = true;
            Close();
        }
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}
