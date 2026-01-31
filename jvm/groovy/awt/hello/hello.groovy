import java.awt.*
import java.awt.event.*

class Hello extends Frame {
     static void main(args) {
        def frame = new Hello( "Hello, World" )
        frame.setVisible(true)
    }

    Hello( title ) {
        super( title );
        addWindowListener(new HelloWindowAdapter())
        setSize(640, 480)

        setLayout(new FlowLayout(FlowLayout.LEFT))

        def label = new Label("Hello, AWT(Groovy) World!")
        add(label)
    }
}

class HelloWindowAdapter extends WindowAdapter {
    void windowClosing(WindowEvent e) {
        System.exit(0)
    }
}
