import java.awt.*;
import java.awt.event.*;
 
public class Hello extends Frame {
    public static void main(String [] args) {
        Hello frame = new Hello( "Hello, World" );
        frame.setVisible(true);
    }
 
    Hello( String title ) {
        super( title );
        addWindowListener(new HelloWindowAdapter());
        setSize(640, 480);
 
        setLayout(new FlowLayout(FlowLayout.LEFT));
 
        Label label = new Label("Hello, AWT World!");
        add(label);
    }
 
}
 
class HelloWindowAdapter extends WindowAdapter {
    public void windowClosing(WindowEvent e) {
        System.exit(0);
    }
}
