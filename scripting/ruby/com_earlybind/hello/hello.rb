# hello.rb - COM Early Binding via Ruby Fiddle
require 'fiddle/import'
require 'fiddle/types'

# ============================================================
# Memory Helper
# ============================================================
module Mem
  @keep = []
  def self.keep(p) = (@keep << p; p)

  def self.to_ptr(data)
    return 0 if data.nil?
    data = data.b
    p = Fiddle::Pointer.malloc(data.bytesize)
    p[0, data.bytesize] = data
    keep(p)
  end

  def self.malloc(size)
    keep(Fiddle::Pointer.malloc(size))
  end
end

def wstr_z(str)
  (str.encode('UTF-16LE') + "\0\0".force_encoding('UTF-16LE')).b
end

def create_guid_ptr(d1, d2, d3, d4_bytes)
  Mem.to_ptr([d1, d2, d3, *d4_bytes].pack('LSSC8'))
end

# ============================================================
# Win32 API
# ============================================================
module Win32
  extend Fiddle::Importer
  dlload 'ole32.dll', 'oleaut32.dll'

  extern 'long CoInitialize(void*)'
  extern 'void CoUninitialize()'
  extern 'long CoCreateInstance(void*, void*, unsigned long, void*, void*)'
  extern 'void* SysAllocString(const short*)'
  extern 'void SysFreeString(void*)'
  extern 'void VariantInit(void*)'
  extern 'long VariantClear(void*)'
end

# Constants (outside module to avoid scope issues)
CLSCTX_INPROC_SERVER = 1
VT_I4 = 3
VT_BSTR = 8
VT_DISPATCH = 9
ssfWINDOWS = 36  # Windows folder

# ============================================================
# COM helper
# ============================================================
module COM
  def self.call(obj, index, ret_type, arg_types, *args)
    raise "COM.call: obj is nil/0" if obj.nil? || obj == 0

    p_obj = Fiddle::Pointer.new(obj.to_i)
    vtbl  = p_obj[0, 8].unpack1('Q')
    vptr  = Fiddle::Pointer.new(vtbl)

    fn_addr = vptr[index * 8, 8].unpack1('Q')
    fn = Fiddle::Function.new(fn_addr, [Fiddle::TYPE_VOIDP] + arg_types, ret_type)

    real = args.map do |a|
      if a.nil?
        0
      elsif a.is_a?(Fiddle::Pointer)
        a.to_i
      elsif a.respond_to?(:to_i)
        a.to_i
      else
        a
      end
    end

    fn.call(obj.to_i, *real)
  end

  def self.release(obj)
    return if obj.nil? || obj == 0
    call(obj, 2, Fiddle::TYPE_INT, [])
  end
end

# ============================================================
# GUIDs
# ============================================================
# CLSID_Shell: {13709620-C279-11CE-A49E-444553540000}
CLSID_Shell = create_guid_ptr(
  0x13709620, 0xC279, 0x11CE,
  [0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00]
)

# IID_IShellDispatch: {D8F015C0-C278-11CE-A49E-444553540000}
IID_IShellDispatch = create_guid_ptr(
  0xD8F015C0, 0xC278, 0x11CE,
  [0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00]
)

# ============================================================
# VARIANT helper (16 bytes on x64)
# ============================================================
def make_variant_i4(value)
  # VARIANT: vt(2) + reserved(6) + union(8)
  v = Mem.malloc(16)
  v[0, 2] = [VT_I4].pack('S')  # vt
  v[8, 4] = [value].pack('L')         # lVal
  v
end

def make_variant_bstr(bstr)
  v = Mem.malloc(16)
  v[0, 2] = [VT_BSTR].pack('S')
  v[8, 8] = [bstr.to_i].pack('Q')     # bstrVal
  v
end

# ============================================================
# Main
# ============================================================
puts "=== COM Early Binding (Ruby) ==="

# Initialize COM
hr = Win32.CoInitialize(nil)
if hr != 0
  puts "CoInitialize failed: 0x#{hr.to_s(16).upcase}"
  exit 1
end
puts "COM initialized"

begin
  # Create Shell.Application object
  pp_shell = Mem.malloc(8)
  hr = Win32.CoCreateInstance(
    CLSID_Shell,
    nil,
    CLSCTX_INPROC_SERVER,
    IID_IShellDispatch,
    pp_shell
  )

  if hr != 0
    puts "CoCreateInstance failed: 0x#{hr.to_s(16).upcase}"
    exit 1
  end

  p_shell = pp_shell[0, 8].unpack1('Q')
  puts "IShellDispatch created"

  # Prepare arguments for BrowseForFolder
  # BrowseForFolder(Hwnd, Title, Options, RootFolder)
  # vtable index: 10 (IShellDispatch)
  
  v_hwnd = make_variant_i4(0)
  
  title_wstr = Mem.to_ptr(wstr_z("Hello, COM(Ruby) World!"))
  bstr_title = Win32.SysAllocString(title_wstr)
  v_title = make_variant_bstr(bstr_title)
  
  v_options = make_variant_i4(0)
  v_root = make_variant_i4(ssfWINDOWS)

  # Output pointer for Folder
  pp_folder = Mem.malloc(8)

  puts "Calling BrowseForFolder via vtable[10]..."

  # IShellDispatch vtable:
  # 0: QueryInterface, 1: AddRef, 2: Release
  # 3: GetTypeInfoCount, 4: GetTypeInfo, 5: GetIDsOfNames, 6: Invoke
  # 7: Application, 8: Parent, 9: NameSpace, 10: BrowseForFolder
  VTBL_BROWSEFORFOLDER = 10

  # Call BrowseForFolder
  # HRESULT BrowseForFolder(LONG Hwnd, BSTR Title, LONG Options, VARIANT vRootFolder, Folder** ppsdf)
  hr = COM.call(
    p_shell,
    VTBL_BROWSEFORFOLDER,
    Fiddle::TYPE_INT,
    [
      Fiddle::TYPE_INT,      # Hwnd (passed as LONG)
      Fiddle::TYPE_VOIDP,    # Title (BSTR)
      Fiddle::TYPE_INT,      # Options
      Fiddle::TYPE_VOIDP,    # vRootFolder (VARIANT by value - pass pointer)
      Fiddle::TYPE_VOIDP     # ppsdf (output)
    ],
    0,                       # Hwnd
    bstr_title,              # Title
    0,                       # Options
    v_root,                  # RootFolder
    pp_folder                # Output
  )

  puts "BrowseForFolder returned: 0x#{hr.to_s(16).upcase}"

  # Free BSTR
  Win32.SysFreeString(bstr_title)

  # Check result
  p_folder = pp_folder[0, 8].unpack1('Q')
  if hr == 0 && p_folder != 0
    puts "Folder selected!"
    # Release Folder object
    COM.release(p_folder)
  else
    puts "No folder selected (cancelled or error)"
  end

  # Release IShellDispatch
  puts "Releasing IShellDispatch..."
  COM.release(p_shell)

ensure
  # Uninitialize COM
  Win32.CoUninitialize()
  puts "COM uninitialized"
end

puts "Program ended normally"
