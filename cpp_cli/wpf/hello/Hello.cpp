#using <WPF/PresentationCore.dll>
#using <WPF/PresentationFramework.dll>
#using <WPF/WindowsBase.dll>
#using <System.xaml.dll>
#using <System.xml.dll>

using namespace System;
using namespace System::IO;
using namespace System::Windows;
using namespace System::Windows::Markup;

[STAThreadAttribute]
int main(array<System::String ^> ^args)
{
     FileStream^ fs = gcnew FileStream("Hello.xaml", FileMode::Open);
     Window^ window = (Window^)(XamlReader::Load(fs));
     window->Show();
     Application^ app = gcnew Application();
     app->Run(window);
     return 0;
}

