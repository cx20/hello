use strict;
use warnings;
use Win32::API;
use FFI::Platypus;
use Config;

# ============================================================
# Architecture detection
# ============================================================
my $is_64bit = ($Config{ptrsize} == 8);
my $ptr_size = $Config{ptrsize};
my $ptr_pack = $is_64bit ? 'Q' : 'L';

print "=== Perl COM vtable IDispatch::Invoke ===\n";
print "Architecture: ", ($is_64bit ? "64-bit" : "32-bit"), "\n";
print "Pointer size: $ptr_size bytes\n\n";

# ============================================================
# FFI::Platypus setup
# ============================================================
my $ffi = FFI::Platypus->new(api => 2);
$ffi->lib(undef);  # Use current process

# ============================================================
# Constants
# ============================================================
use constant {
    S_OK                => 0,
    S_FALSE             => 1,
    CLSCTX_INPROC_SERVER => 0x1,
    CLSCTX_LOCAL_SERVER  => 0x4,
    CLSCTX_ALL           => 0x5,
    
    # VARIANT types
    VT_EMPTY    => 0,
    VT_I4       => 3,
    VT_BSTR     => 8,
    VT_DISPATCH => 9,
    
    # Invoke flags
    DISPATCH_METHOD => 0x1,
    
    # Memory
    MEM_COMMIT              => 0x1000,
    MEM_RELEASE             => 0x8000,
    PAGE_EXECUTE_READWRITE  => 0x40,
    
    # CoInitializeEx flags
    COINIT_APARTMENTTHREADED => 0x2,
    
    # vtable indices for IDispatch
    ONVTBL_QueryInterface   => 0,
    ONVTBL_AddRef           => 1,
    ONVTBL_Release          => 2,
    ONVTBL_GetTypeInfoCount => 3,
    ONVTBL_GetTypeInfo      => 4,
    ONVTBL_GetIDsOfNames    => 5,
    ONVTBL_Invoke           => 6,
};

# ============================================================
# Import Windows API functions via Win32::API
# ============================================================
my $RtlMoveMemory_Read = Win32::API->new('kernel32', 'RtlMoveMemory', 'PNN', 'V');
my $RtlMoveMemory_Write = Win32::API->new('kernel32', 'RtlMoveMemory', 'NPN', 'V');

my $VirtualAlloc = Win32::API->new('kernel32', 'VirtualAlloc', 'NNNN', 'N');
my $VirtualFree = Win32::API->new('kernel32', 'VirtualFree', 'NNN', 'I');

my $CoInitializeEx = Win32::API->new('ole32', 'CoInitializeEx', 'NN', 'I');
my $CoUninitialize = Win32::API->new('ole32', 'CoUninitialize', [], 'V');
my $CoCreateInstance = Win32::API->new('ole32', 'CoCreateInstance', 'PNNPP', 'I');
my $CLSIDFromProgID = Win32::API->new('ole32', 'CLSIDFromProgID', 'PP', 'I');

my $SysAllocString = Win32::API->new('oleaut32', 'SysAllocString', 'P', 'N');
my $SysFreeString = Win32::API->new('oleaut32', 'SysFreeString', 'N', 'V');
my $SysStringLen = Win32::API->new('oleaut32', 'SysStringLen', 'N', 'N');

# ============================================================
# Helper functions
# ============================================================
sub read_ptr {
    my ($addr) = @_;
    my $buf = "\0" x $ptr_size;
    $RtlMoveMemory_Read->Call($buf, $addr, $ptr_size);
    return unpack($ptr_pack, $buf);
}

sub read_mem {
    my ($addr, $size) = @_;
    my $buf = "\0" x $size;
    $RtlMoveMemory_Read->Call($buf, $addr, $size);
    return $buf;
}

sub write_mem {
    my ($dest, $data) = @_;
    $RtlMoveMemory_Write->Call($dest, $data, length($data));
}

sub encode_utf16 {
    my ($str) = @_;
    my $utf16 = '';
    $utf16 .= pack('v', ord($_)) for split //, $str;
    $utf16 .= "\0\0";
    return $utf16;
}

sub guid_from_string {
    my ($s) = @_;
    $s =~ s/[{}]//g;
    my @p = split /-/, $s;
    return pack('L S S', hex($p[0]), hex($p[1]), hex($p[2])) . pack('H*', $p[3] . $p[4]);
}

# ============================================================
# Thunk memory management
# ============================================================
my $thunk_mem;
my $thunk_size = 512;

sub init_thunk_memory {
    $thunk_mem = $VirtualAlloc->Call(0, $thunk_size, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    die "VirtualAlloc for thunk failed" unless $thunk_mem;
}

sub free_thunk_memory {
    $VirtualFree->Call($thunk_mem, 0, MEM_RELEASE) if $thunk_mem;
}

# Call thunk using FFI::Platypus
sub call_thunk {
    my ($code) = @_;
    write_mem($thunk_mem, $code);
    
    # Create function from address using FFI::Platypus
    my $func = $ffi->function($thunk_mem => [] => 'uint32');
    return $func->call();
}

# ============================================================
# Thunk-based vtable method calls
# ============================================================

# Call AddRef/Release: ULONG (this)
sub call_addref_release {
    my ($func_addr, $this) = @_;
    
    my $code;
    if ($is_64bit) {
        # x64: sub rsp,0x28; mov rcx,this; mov rax,func; call rax; add rsp,0x28; ret
        $code = pack('H*', '4883EC28');                      # sub rsp, 0x28
        $code .= pack('H*', '48B9') . pack('Q', $this);      # mov rcx, this
        $code .= pack('H*', '48B8') . pack('Q', $func_addr); # mov rax, func
        $code .= pack('H*', 'FFD0');                         # call rax
        $code .= pack('H*', '4883C428');                     # add rsp, 0x28
        $code .= pack('H*', 'C3');                           # ret
    } else {
        # x86 __stdcall: push this; call func; ret
        $code = pack('H*', '68') . pack('L', $this);         # push this
        $code .= pack('H*', 'B8') . pack('L', $func_addr);   # mov eax, func
        $code .= pack('H*', 'FFD0');                         # call eax
        $code .= pack('H*', 'C3');                           # ret
    }
    
    return call_thunk($code);
}

# Call GetIDsOfNames
sub call_GetIDsOfNames {
    my ($func_addr, $this, $riid_ptr, $names_ptr, $cNames, $lcid, $dispid_ptr) = @_;
    
    my $code;
    if ($is_64bit) {
        # x64: rcx=this, rdx=riid, r8=names, r9=cNames, stack[0x20]=lcid, stack[0x28]=dispid
        $code = pack('H*', '4883EC38');                         # sub rsp, 0x38
        $code .= pack('H*', '48B9') . pack('Q', $this);         # mov rcx, this
        $code .= pack('H*', '48BA') . pack('Q', $riid_ptr);     # mov rdx, riid
        $code .= pack('H*', '49B8') . pack('Q', $names_ptr);    # mov r8, names
        $code .= pack('H*', '49B9') . pack('Q', $cNames);       # mov r9, cNames
        $code .= pack('H*', '48C744242000000000');              # mov qword [rsp+0x20], lcid (0)
        $code .= pack('H*', '48B8') . pack('Q', $dispid_ptr);   # mov rax, dispid_ptr
        $code .= pack('H*', '4889442428');                      # mov [rsp+0x28], rax
        $code .= pack('H*', '48B8') . pack('Q', $func_addr);    # mov rax, func
        $code .= pack('H*', 'FFD0');                            # call rax
        $code .= pack('H*', '4883C438');                        # add rsp, 0x38
        $code .= pack('H*', 'C3');                              # ret
    } else {
        # x86 __stdcall: push args right to left
        $code = pack('H*', '68') . pack('L', $dispid_ptr);      # push dispid
        $code .= pack('H*', '68') . pack('L', $lcid);           # push lcid
        $code .= pack('H*', '68') . pack('L', $cNames);         # push cNames
        $code .= pack('H*', '68') . pack('L', $names_ptr);      # push names
        $code .= pack('H*', '68') . pack('L', $riid_ptr);       # push riid
        $code .= pack('H*', '68') . pack('L', $this);           # push this
        $code .= pack('H*', 'B8') . pack('L', $func_addr);      # mov eax, func
        $code .= pack('H*', 'FFD0');                            # call eax
        $code .= pack('H*', 'C3');                              # ret
    }
    
    return call_thunk($code);
}

# Call Invoke
sub call_Invoke {
    my ($func_addr, $this, $dispid, $riid_ptr, $lcid, $wFlags, $dispparams_ptr, $result_ptr, $excep_ptr, $argerr_ptr) = @_;
    
    my $code;
    if ($is_64bit) {
        # x64: rcx=this, rdx=dispid, r8=riid, r9=lcid, stack=wFlags,dispparams,result,excep,argerr
        $code = pack('H*', '4883EC48');                         # sub rsp, 0x48
        $code .= pack('H*', '48B9') . pack('Q', $this);         # mov rcx, this
        $code .= pack('H*', '48BA') . pack('Q', $dispid);       # mov rdx, dispid
        $code .= pack('H*', '49B8') . pack('Q', $riid_ptr);     # mov r8, riid
        $code .= pack('H*', '49B9') . pack('Q', $lcid);         # mov r9, lcid
        # stack args
        $code .= pack('H*', '48C744242001000000');              # mov qword [rsp+0x20], wFlags (1)
        $code .= pack('H*', '48B8') . pack('Q', $dispparams_ptr);
        $code .= pack('H*', '4889442428');                      # mov [rsp+0x28], dispparams
        $code .= pack('H*', '48B8') . pack('Q', $result_ptr);
        $code .= pack('H*', '4889442430');                      # mov [rsp+0x30], result
        $code .= pack('H*', '48B8') . pack('Q', $excep_ptr);
        $code .= pack('H*', '4889442438');                      # mov [rsp+0x38], excep
        $code .= pack('H*', '48B8') . pack('Q', $argerr_ptr);
        $code .= pack('H*', '4889442440');                      # mov [rsp+0x40], argerr
        $code .= pack('H*', '48B8') . pack('Q', $func_addr);    # mov rax, func
        $code .= pack('H*', 'FFD0');                            # call rax
        $code .= pack('H*', '4883C448');                        # add rsp, 0x48
        $code .= pack('H*', 'C3');                              # ret
    } else {
        # x86 __stdcall: push args right to left
        $code = pack('H*', '68') . pack('L', $argerr_ptr);
        $code .= pack('H*', '68') . pack('L', $excep_ptr);
        $code .= pack('H*', '68') . pack('L', $result_ptr);
        $code .= pack('H*', '68') . pack('L', $dispparams_ptr);
        $code .= pack('H*', '68') . pack('L', $wFlags);
        $code .= pack('H*', '68') . pack('L', $lcid);
        $code .= pack('H*', '68') . pack('L', $riid_ptr);
        $code .= pack('H*', '68') . pack('L', $dispid);
        $code .= pack('H*', '68') . pack('L', $this);
        $code .= pack('H*', 'B8') . pack('L', $func_addr);
        $code .= pack('H*', 'FFD0');
        $code .= pack('H*', 'C3');
    }
    
    return call_thunk($code);
}

# ============================================================
# VARIANT helpers
# ============================================================
sub get_variant_size {
    return $is_64bit ? 24 : 16;
}

sub make_variant_i4 {
    my ($value) = @_;
    my $var;
    if ($is_64bit) {
        $var = pack('S S S S l x12', VT_I4, 0, 0, 0, $value);
    } else {
        $var = pack('S S S S l x4', VT_I4, 0, 0, 0, $value);
    }
    return $var;
}

sub make_variant_bstr {
    my ($str) = @_;
    my $utf16 = encode_utf16($str);
    my $bstr = $SysAllocString->Call($utf16);
    die "SysAllocString failed" unless $bstr;
    
    my $var;
    if ($is_64bit) {
        $var = pack('S S S S Q x8', VT_BSTR, 0, 0, 0, $bstr);
    } else {
        $var = pack('S S S S L x4', VT_BSTR, 0, 0, 0, $bstr);
    }
    return ($var, $bstr);
}

sub make_variant_empty {
    my $var;
    if ($is_64bit) {
        $var = pack('S S S S x16', VT_EMPTY, 0, 0, 0);
    } else {
        $var = pack('S S S S x8', VT_EMPTY, 0, 0, 0);
    }
    return $var;
}

# ============================================================
# DISPPARAMS structure
# ============================================================
sub get_dispparams_size {
    return $is_64bit ? 24 : 16;
}

sub make_dispparams {
    my ($rgvarg_ptr, $cArgs) = @_;
    my $dp;
    if ($is_64bit) {
        $dp = pack('Q Q L L', $rgvarg_ptr, 0, $cArgs, 0);
    } else {
        $dp = pack('L L L L', $rgvarg_ptr, 0, $cArgs, 0);
    }
    return $dp;
}

# ============================================================
# EXCEPINFO structure
# ============================================================
sub get_excepinfo_size {
    return $is_64bit ? 64 : 32;
}

# ============================================================
# Main
# ============================================================
print "Initializing COM...\n";

my $hr = $CoInitializeEx->Call(0, COINIT_APARTMENTTHREADED);
print "CoInitializeEx: ", sprintf("0x%08X", $hr & 0xFFFFFFFF), "\n";

if ($hr != S_OK && $hr != S_FALSE && ($hr & 0xFFFFFFFF) != 0x80010106) {
    die "CoInitializeEx failed\n";
}
print "COM initialized successfully\n";

init_thunk_memory();
print "Thunk memory: ", sprintf("0x%X", $thunk_mem), "\n";

# Allocate work memory
my $mem_size = 4096;
my $work_mem = $VirtualAlloc->Call(0, $mem_size, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
die "VirtualAlloc for work_mem failed" unless $work_mem;
print "Work memory: ", sprintf("0x%X", $work_mem), "\n";

my $offset = 0;
sub alloc_work {
    my ($size) = @_;
    my $ptr = $work_mem + $offset;
    $offset += $size;
    $offset = ($offset + 7) & ~7;
    return $ptr;
}

eval {
    # Get CLSID for Shell.Application
    print "\n--- Getting CLSID ---\n";
    my $progid = encode_utf16("Shell.Application");
    my $clsid = "\0" x 16;
    
    $hr = $CLSIDFromProgID->Call($progid, $clsid);
    print "CLSIDFromProgID: ", sprintf("0x%08X", $hr & 0xFFFFFFFF), "\n";
    die "CLSIDFromProgID failed\n" if $hr != S_OK;
    
    # IID_IDispatch
    my $iid_dispatch = guid_from_string('{00020400-0000-0000-C000-000000000046}');
    
    # IID_NULL (all zeros) in work memory
    my $iid_null_ptr = alloc_work(16);
    write_mem($iid_null_ptr, "\0" x 16);
    
    # Create instance
    print "\n--- Creating Shell.Application ---\n";
    my $ppv = "\0" x $ptr_size;
    
    $hr = $CoCreateInstance->Call($clsid, 0, CLSCTX_ALL, $iid_dispatch, $ppv);
    print "CoCreateInstance: ", sprintf("0x%08X", $hr & 0xFFFFFFFF), "\n";
    die "CoCreateInstance failed\n" if $hr != S_OK;
    
    my $pDispatch = unpack($ptr_pack, $ppv);
    print "IDispatch: ", sprintf("0x%X", $pDispatch), "\n";
    
    # Read vtable pointer
    my $vtbl = read_ptr($pDispatch);
    print "vtable: ", sprintf("0x%X", $vtbl), "\n";
    
    # Print vtable entries
    print "\nvtable entries:\n";
    my @names = qw(QueryInterface AddRef Release GetTypeInfoCount GetTypeInfo GetIDsOfNames Invoke);
    for my $i (0..6) {
        my $addr = read_ptr($vtbl + $i * $ptr_size);
        print sprintf("  [%d] %-20s 0x%X\n", $i, $names[$i], $addr);
    }
    
    # Test AddRef
    print "\n--- Testing AddRef ---\n";
    my $addref_addr = read_ptr($vtbl + ONVTBL_AddRef * $ptr_size);
    my $refcount = call_addref_release($addref_addr, $pDispatch);
    print "AddRef result: $refcount\n";
    
    # ============================================================
    # GetIDsOfNames for "BrowseForFolder"
    # ============================================================
    print "\n--- GetIDsOfNames('BrowseForFolder') ---\n";
    
    # Method name in work memory
    my $method_name = encode_utf16("BrowseForFolder");
    my $name_buf_ptr = alloc_work(length($method_name));
    write_mem($name_buf_ptr, $method_name);
    
    # LPOLESTR* array (array of 1 pointer)
    my $names_array_ptr = alloc_work($ptr_size);
    write_mem($names_array_ptr, pack($ptr_pack, $name_buf_ptr));
    
    # DISPID output
    my $dispid_ptr = alloc_work(4);
    write_mem($dispid_ptr, "\0" x 4);
    
    my $getids_addr = read_ptr($vtbl + ONVTBL_GetIDsOfNames * $ptr_size);
    print "GetIDsOfNames address: ", sprintf("0x%X", $getids_addr), "\n";
    
    $hr = call_GetIDsOfNames($getids_addr, $pDispatch, $iid_null_ptr, $names_array_ptr, 1, 0, $dispid_ptr);
    print "GetIDsOfNames result: ", sprintf("0x%08X", $hr & 0xFFFFFFFF), "\n";
    die "GetIDsOfNames failed\n" if $hr != S_OK;
    
    my $dispid_buf = read_mem($dispid_ptr, 4);
    my $dispid = unpack('l', $dispid_buf);
    print "DISPID for BrowseForFolder: $dispid\n";
    
    # ============================================================
    # Invoke BrowseForFolder(hwnd, title, options, rootFolder)
    # ============================================================
    print "\n--- Invoke BrowseForFolder ---\n";
    
    my $var_size = get_variant_size();
    print "VARIANT size: $var_size bytes\n";
    
    # Create VARIANTs
    my $v_root  = make_variant_i4(36);  # 36 = Windows folder
    my $v_opt   = make_variant_i4(0);
    my ($v_title, $bstr_title) = make_variant_bstr("Hello, COM(Perl) World!");
    my $v_hwnd  = make_variant_i4(0);
    
    print "BSTR title ptr: ", sprintf("0x%X", $bstr_title), "\n";
    print "BSTR title length: ", $SysStringLen->Call($bstr_title), "\n";
    
    # Allocate VARIANT array (4 VARIANTs in reverse order)
    my $args_ptr = alloc_work($var_size * 4);
    write_mem($args_ptr + $var_size * 0, $v_root);   # rgvarg[0] = rootFolder
    write_mem($args_ptr + $var_size * 1, $v_opt);    # rgvarg[1] = options
    write_mem($args_ptr + $var_size * 2, $v_title);  # rgvarg[2] = title
    write_mem($args_ptr + $var_size * 3, $v_hwnd);   # rgvarg[3] = hwnd
    
    # Create DISPPARAMS
    my $dp_ptr = alloc_work(get_dispparams_size());
    my $dispparams = make_dispparams($args_ptr, 4);
    write_mem($dp_ptr, $dispparams);
    
    # Create result VARIANT
    my $result_ptr = alloc_work($var_size);
    write_mem($result_ptr, make_variant_empty());
    
    # Create EXCEPINFO
    my $excep_ptr = alloc_work(get_excepinfo_size());
    write_mem($excep_ptr, "\0" x get_excepinfo_size());
    
    # Create argerr
    my $argerr_ptr = alloc_work(4);
    write_mem($argerr_ptr, "\0" x 4);
    
    # Call Invoke
    my $invoke_addr = read_ptr($vtbl + ONVTBL_Invoke * $ptr_size);
    print "Invoke address: ", sprintf("0x%X", $invoke_addr), "\n";
    
    $hr = call_Invoke(
        $invoke_addr,
        $pDispatch,
        $dispid,
        $iid_null_ptr,
        0,              # lcid
        DISPATCH_METHOD,
        $dp_ptr,
        $result_ptr,
        $excep_ptr,
        $argerr_ptr
    );
    
    print "Invoke result: ", sprintf("0x%08X", $hr & 0xFFFFFFFF), "\n";
    
    # Read argerr
    my $argerr_buf = read_mem($argerr_ptr, 4);
    my $argerr = unpack('L', $argerr_buf);
    print "argerr: $argerr\n";
    
    if ($hr == S_OK) {
        # Read result VARIANT
        my $result_data = read_mem($result_ptr, $var_size);
        my $vt = unpack('S', $result_data);
        print "Result vt: $vt";
        print " (VT_DISPATCH)" if $vt == VT_DISPATCH;
        print " (VT_EMPTY)" if $vt == VT_EMPTY;
        print "\n";
        
        if ($vt == VT_DISPATCH) {
            my $folder_ptr;
            if ($is_64bit) {
                $folder_ptr = unpack('x8 Q', $result_data);
            } else {
                $folder_ptr = unpack('x8 L', $result_data);
            }
            print "Folder object: ", sprintf("0x%X", $folder_ptr), "\n";
            print "SUCCESS: Folder selected!\n";
            
            # Release folder object
            if ($folder_ptr) {
                my $folder_vtbl = read_ptr($folder_ptr);
                my $folder_release = read_ptr($folder_vtbl + ONVTBL_Release * $ptr_size);
                call_addref_release($folder_release, $folder_ptr);
            }
        } else {
            print "No folder selected (cancelled)\n";
        }
    } else {
        print "Invoke failed!\n";
    }
    
    # Cleanup
    $SysFreeString->Call($bstr_title) if $bstr_title;
    
    # Release IDispatch (balance AddRef + initial ref)
    print "\n--- Cleanup ---\n";
    my $release_addr = read_ptr($vtbl + ONVTBL_Release * $ptr_size);
    $refcount = call_addref_release($release_addr, $pDispatch);
    print "Release result: $refcount\n";
    $refcount = call_addref_release($release_addr, $pDispatch);
    print "Final Release result: $refcount\n";
};

if ($@) {
    print "Error: $@\n";
}

# Final cleanup
$VirtualFree->Call($work_mem, 0, MEM_RELEASE) if $work_mem;
free_thunk_memory();
$CoUninitialize->Call();

print "\nDone.\n";
