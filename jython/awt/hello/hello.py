from java.lang import System
from java.awt import Frame
from java.awt import Label
from java.awt import FlowLayout
from java.awt.event import WindowAdapter

class HelloFrame(Frame):
    def __init__(self):
        self.setTitle( "Hello, World!" )
        self.addWindowListener(HelloWindowAdapter())
        self.setSize( 640, 480 )

        self.setLayout( FlowLayout(FlowLayout.LEFT) )

        label = Label( "Hello, AWT(Jython) World!" )
        self.add( label )

class HelloWindowAdapter(WindowAdapter):
    def windowClosing(self, event):
        System.exit(0)

if __name__ == '__main__':
    frame = HelloFrame()
    frame.setVisible(True)
