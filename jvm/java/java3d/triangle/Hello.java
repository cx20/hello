import javax.media.j3d.*;
import javax.vecmath.*;
import com.sun.j3d.utils.universe.SimpleUniverse;
import com.sun.j3d.utils.geometry.ColorCube;
import java.awt.event.ComponentAdapter;
import java.awt.event.ComponentEvent;
import java.awt.*;
import javax.swing.JFrame;

public class Hello {

    public Hello() {
        JFrame frame = new JFrame("Hello, World!");
        frame.setSize(640, 480);
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

        Canvas3D canvas3D = new Canvas3D(SimpleUniverse.getPreferredConfiguration());
        frame.add(canvas3D);

        canvas3D.addComponentListener(new ComponentAdapter() {
            @Override
            public void componentResized(ComponentEvent e) {
                canvas3D.repaint();
            }
        });
        
        SimpleUniverse universe = new SimpleUniverse(canvas3D);

        BranchGroup scene = createSceneGraph();
        universe.getViewingPlatform().setNominalViewingTransform();
        universe.addBranchGraph(scene);

        frame.setVisible(true);
    }

    private BranchGroup createSceneGraph() {
        BranchGroup root = new BranchGroup();

        Point3f p1 = new Point3f(-0.5f, -0.5f, 0.0f);
        Point3f p2 = new Point3f(0.5f, -0.5f, 0.0f);
        Point3f p3 = new Point3f(0.0f, 0.5f, 0.0f);

        TriangleArray triangle = new TriangleArray(3, TriangleArray.COORDINATES | TriangleArray.COLOR_3);
        triangle.setCoordinate(0, p1);
        triangle.setCoordinate(1, p2);
        triangle.setCoordinate(2, p3);
        
        triangle.setColor(0, new Color3f(1.0f, 0.0f, 0.0f));
        triangle.setColor(1, new Color3f(0.0f, 1.0f, 0.0f));
        triangle.setColor(2, new Color3f(0.0f, 0.0f, 1.0f));

        root.addChild(new Shape3D(triangle));
        root.setCapability(BranchGroup.ALLOW_DETACH);

        return root;
    }

    public static void main(String[] args) {
        new Hello();
    }
}
