from java.lang import System
from javax.swing import JFrame
from javax.swing import JLabel
 
class HelloFrame(JFrame):
    def __init__(self):
        self.setTitle( "Hello, World!" )
        self.setDefaultCloseOperation( JFrame.EXIT_ON_CLOSE )
        self.setSize( 640, 480 )
 
        label = JLabel( "Hello, Swing(Jython) World!" )
        label.setVerticalAlignment( JLabel.TOP )
        self.add( label )
 
if __name__ == '__main__':
    frame = HelloFrame()
    frame.setVisible(True)
