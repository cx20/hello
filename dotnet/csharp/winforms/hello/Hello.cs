using System;
using System.Drawing;
using System.Windows.Forms;
 
class HelloForm : Form
{
    public HelloForm()
    {
        this.Size = new Size( 640, 480 );
        this.Text = "Hello, World!";
 
        Label label1 = new Label();
        label1.Size = new Size( 320, 20 );
        label1.Text = "Hello, Windows Forms(C#) World!";
 
        this.Controls.Add( label1 );
    }
    [STAThread]
    static void Main()
    {
        HelloForm form = new HelloForm();
        Application.Run(form);
    }
}
