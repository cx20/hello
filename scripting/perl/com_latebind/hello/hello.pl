use strict;
use Win32::OLE;

my $shell = Win32::OLE->new('Shell.Application');
my $folder = $shell->BrowseForFolder( 0, 'Hello, COM(Perl) World!', 0, 36 )
