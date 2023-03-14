import java.awt.Color;
import java.awt.Graphics;
import javax.swing.JFrame;
import javax.swing.JPanel;

public class Hello extends JPanel {

    public void paint(Graphics g) {
        super.paint(g);

        int[] xPoints = {300, 500, 100};
        int[] yPoints = {100, 400, 400};
        int nPoints = 3;

        g.setColor( Color.BLUE );
        g.fillPolygon(xPoints, yPoints, nPoints);
    }

    public static void main(String[] args) {
        JFrame frame = new JFrame("Hello, World!");
        frame.add(new Hello());
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setSize(640, 480);
        frame.setVisible(true);
    }
}
