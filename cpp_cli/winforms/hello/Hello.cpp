#using <System.dll>
#using <System.Drawing.dll>
#using <System.Windows.Forms.dll>
 
using namespace System;
using namespace System::Drawing;
using namespace System::Windows::Forms;
 
public ref class HelloForm : public Form
{
public:
    HelloForm()
    {
        this->Size = System::Drawing::Size( 640, 480 );
        this->Text = "Hello, World!";
        Label^ label1 = gcnew Label();
        label1->Text = "Hello, Windows Forms(C++/CLI) World!";
        label1->Size = System::Drawing::Size( 320, 20 );
        this->Controls->Add( label1 );
    }
};
 
int main( array<System::String^>^ args )
{
   HelloForm^ form = gcnew HelloForm();
   Application::Run(form);
 
   return 0;
}
