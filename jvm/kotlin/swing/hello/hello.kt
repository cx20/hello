import javax.swing.*

public class Hello(title: String) : JFrame() {
    init {
        setTitle(title)
        setSize(640, 480)

        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE)

        val label = JLabel("Hello, Swing(Kotlin) World!")
        label.setVerticalAlignment(JLabel.TOP);
        add(label)
    }
}

fun main(args: Array<String>) {
    var frame = Hello("Hello, World!")
    frame.setVisible(true)
}
