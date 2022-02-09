use Win32::GUI();

$main = Win32::GUI::Window->new(
    -text => "Hello, World" );

$label = $main->AddLabel( 
    -text => "Hello, Win32 GUI(Perl) World!" );

$main->Resize(640, 480);
$main->Show();

Win32::GUI::Dialog();
