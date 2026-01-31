import java.awt.*
import java.awt.event.*
import javax.swing.*
 
class Hello extends JFrame {
    static void main( args ) {
        def frame = new Hello( "Hello, World" )
        frame.setVisible( true )
    }
 
    Hello( String title ) {
        super( title )
        setDefaultCloseOperation( JFrame.EXIT_ON_CLOSE )
        setLocationRelativeTo( null )
        setSize( 640, 480 )
 
        def label = new JLabel( "Hello, Swing(Groovy) World!" )
        label.setVerticalAlignment(JLabel.TOP)
        add( label )
    }
}
