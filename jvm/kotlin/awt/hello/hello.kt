import java.awt.*
import java.awt.event.*;

public class Hello(title: String) : Frame() {
    init {
        setTitle(title)
        addWindowListener(HelloWindowAdapter())
        setSize(640, 480)

        layout = FlowLayout(FlowLayout.LEFT)

        val label = Label("Hello, AWT(Kotlin) World!")
        add(label)
    }
}

internal class HelloWindowAdapter : WindowAdapter() {
    override fun windowClosing(e: WindowEvent) {
        System.exit(0)
    }
}

fun main(args: Array<String>) {
    var frame = Hello("Hello, World!")
    frame.setVisible(true)
}
