import java.awt._
import java.awt.event._
import javax.swing._
 
object Hello {
    def main( args: Array[String] ) = {
        var frame = new HelloFrame( "Hello, World" )
        frame.setVisible( true )
    }
}
 
class HelloFrame( title: String ) extends JFrame {
    setTitle( title )
    setDefaultCloseOperation( JFrame.EXIT_ON_CLOSE )
    setLocationRelativeTo( null )
    setSize( 640, 480 )
 
    var label = new JLabel( "Hello, Swing World!" )
    label.setVerticalAlignment(SwingConstants.TOP)
    add( label )
}
