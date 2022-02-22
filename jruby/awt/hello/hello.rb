require "java"

java_import java.lang.System
java_import java.awt.Frame
java_import java.awt.Label
java_import java.awt.FlowLayout
java_import java.awt.event.WindowAdapter

class Hello < Frame
  def initialize(title)
    self.addWindowListener(HelloWindowAdapter.new)
    self.setSize(640, 480)

    self.setLayout(FlowLayout.new(FlowLayout::LEFT))

    @label = Label.new('Hello, AWT(JRuby) World!')
    self.add(@label)
  end
end

class HelloWindowAdapter < WindowAdapter
  def windowClosing(e)
    System.exit(0)
  end
end

@frame = Hello.new('Hello, World!')
@frame.setVisible(true)
