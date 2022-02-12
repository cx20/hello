require 'win32ole'

shell = WIN32OLE.new('Shell.Application')
folder = shell.BrowseForFolder( 0, "Hello, COM(Ruby) World!", 0, 36 )
