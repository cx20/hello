open System
open System.Drawing
open System.Windows.Forms

type HelloForm() as this =
    inherit Form()

    do
        this.Size <- new Size( 640, 480 )
        this.Text <- "Hello, World!"
        let label1 = new Label()
        label1.Size <- new Size( 320, 20 )
        label1.Text <- "Hello, Windows Forms(F#) World!"
        do this.Controls.Add(label1)

let form = new HelloForm()
do Application.Run(form)
