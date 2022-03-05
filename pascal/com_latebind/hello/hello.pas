program hello;

uses
    ComObj;

var
    shell: Variant;
    folder: Variant;

begin
    shell := CreateOleObject('Shell.Application');
    folder := shell.BrowseForFolder( 0, 'Hello, COM(Pascal) World!', 0, 36 );
end.
