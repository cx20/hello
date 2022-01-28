import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
 
public class Hello extends JFrame {
    public static void main( String args [] ) {
        Hello frame = new Hello( "Hello, World" );
        frame.setVisible( true );
    }
 
    Hello( String title ) {
        super( title );
        setDefaultCloseOperation( JFrame.EXIT_ON_CLOSE );
        setLocationRelativeTo( null );
        setSize( 640, 480 );
 
        JLabel label = new JLabel( "Hello, Swing World!" );
        label.setVerticalAlignment(JLabel.TOP);
        add( label );
    }
}
