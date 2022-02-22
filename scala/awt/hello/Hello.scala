import java.awt._
import java.awt.event._

object Hello {
    def main(args: Array[String]) = {
        var frame = new HelloFrame( "Hello, World" )
        frame.setVisible(true)
    }
}

class HelloFrame( title: String ) extends Frame {
    setTitle( title )
    addWindowListener(new HelloWindowAdapter())
    setSize(640, 480)

    setLayout(new FlowLayout(FlowLayout.LEFT))

    var label = new Label("Hello, AWT(Scala) World!")
    add(label)
}

class HelloWindowAdapter extends WindowAdapter {
    override def windowClosing( e: WindowEvent ) = {
        System.exit(0)
    }
}
