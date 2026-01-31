require 'fiddle/import'

module MessageBox
    extend Fiddle::Importer
    dlload 'user32'
    typealias 'HANDLE', 'void*'
    typealias 'HWND', 'HANDLE'
    typealias 'LPCSTR', 'const char*'
    typealias 'UINT', 'unsigned int'
    extern 'int MessageBoxA(HWND, LPCSTR, LPCSTR, UINT)'
end

MessageBox::MessageBoxA nil, "Hello, Win32 API(Ruby) World!", "Hello, World!", 0
