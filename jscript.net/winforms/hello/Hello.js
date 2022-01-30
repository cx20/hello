import System;
import System.Drawing;
import System.Windows.Forms;
import Accessibility;
 
main();
 
class HelloForm extends Form
{
    function HelloForm()
    {
        this.Size = new System.Drawing.Size( 640, 480 );
        this.Text = "Hello, World!";
        var label1 = new Label;
        label1.Size = new System.Drawing.Size( 320, 20 );
        label1.Text = "Hello, Windows Forms(JScript.NET) World!";
        this.Controls.Add( label1 );
    }
}
 
function main() {
    var form = new HelloForm;
    Application.Run(form);
}
