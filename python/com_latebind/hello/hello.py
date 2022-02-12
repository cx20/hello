import win32com.client
 
shell = win32com.client.Dispatch('Shell.Application')
folder = shell.BrowseForFolder( 0, "Hello, COM(Python) World!", 0, 36 )
