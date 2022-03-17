open System
open System.IO
open System.Windows
open System.Windows.Markup

[<STAThread>]
[<EntryPoint>]
let main argv =
    let stream = File.OpenRead("Hello.xaml")
    let window = XamlReader.Load(stream) :?> Window

    let application = new Application()
    application.Run(window) |> ignore

    0
