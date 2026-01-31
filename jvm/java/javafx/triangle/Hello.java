import javafx.application.Application;
import javafx.scene.Scene;
import javafx.scene.layout.Pane;
import javafx.scene.paint.Color;
import javafx.scene.shape.Polygon;
import javafx.stage.Stage;

public class Hello extends Application {

    @Override
    public void start(Stage primaryStage) {
        Pane pane = new Pane();

        Polygon triangle = new Polygon(300.0, 100.0, 500.0, 400.0, 100.0, 400.0);
        triangle.setFill(Color.BLUE);
        triangle.setStroke(Color.BLACK);

        pane.getChildren().add(triangle);

        Scene scene = new Scene(pane, 640, 480);

        primaryStage.setTitle("Hello, World!");
        primaryStage.setScene(scene);
        primaryStage.show();
    }

    public static void main(String[] args) {
        launch(args);
    }
}
