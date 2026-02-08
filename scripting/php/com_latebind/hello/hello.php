<?php
/*
  COM Late Binding via PHP COM extension
  
  Simple and straightforward like Python/Perl/Ruby
*/

// Create Shell.Application COM object
$shell = new COM("Shell.Application");

// Call BrowseForFolder method
// BrowseForFolder(Hwnd, Title, Options, RootFolder)
$folder = $shell->BrowseForFolder(0, "Hello, COM(PHP) World!", 0, 36);

// Check if folder was selected
if ($folder !== null) {
    echo "Folder selected!\n";
    // You can access folder properties if needed
    // $title = $folder->Title;
    // echo "Selected: $title\n";
} else {
    echo "No folder selected (cancelled)\n";
}

echo "Program ended normally\n";
