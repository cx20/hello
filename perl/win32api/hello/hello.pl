use strict;
use Win32::API;
 
my $msgbox= Win32::API->new("user32", "MessageBoxA", "NPPN", "N");
   $msgbox->Call( 0, "Hello, Win32 API(Perl) World!", "Hello, World!", 0 );
