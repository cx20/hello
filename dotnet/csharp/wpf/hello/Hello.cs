using System;
using System.IO;
using System.Windows;
using System.Windows.Markup;

public class Hello {
	[STAThread]
	public static void Main() {
		Window window = null;
		using( FileStream fs = new FileStream("Hello.xaml", FileMode.Open) ){
			window = (Window)XamlReader.Load(fs);
		}
		window.Show();

		Application app = new Application();
		app.Run(window);
	}
}

