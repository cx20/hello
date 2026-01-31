require 'java'

java_import 'javax.swing.JFrame'
java_import 'javax.swing.JLabel'

class Hello < JFrame
  def initialize(title)
    self.setDefaultCloseOperation( JFrame::EXIT_ON_CLOSE )
    self.setSize( 640, 480 )

    @label = JLabel.new( "Hello, Swing(JRuby) World!" )
    @label.setVerticalAlignment(JLabel::TOP)
    self.add( @label )
  end
end

@frame = Hello.new( "Hello, World!" )
@frame.setVisible( true )
