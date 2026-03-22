#!/usr/bin/perl
# WinRT Toast Notification (FFI::Platypus only, no further external libraries)
#
# This sample demonstrates how to show a Windows Toast Notification
# using Perl's FFI::Platypus to call WinRT COM APIs via raw vtable access.
#
# Requirements:
#   - Windows 10/11, x64
#   - Perl 5.26+ (64-bit) with FFI::Platypus
#   - Strawberry Perl 5.30+ includes FFI::Platypus by default
#   - Or install manually: cpanm FFI::Platypus
#
# Usage:
#   perl hello.pl
#
# VTable layout for WinRT interfaces:
#   0: QueryInterface      (IUnknown)
#   1: AddRef              (IUnknown)
#   2: Release             (IUnknown)
#   3: GetIids             (IInspectable)
#   4: GetRuntimeClassName (IInspectable)
#   5: GetTrustLevel       (IInspectable)
#   6+: Interface-specific methods

use strict;
use warnings;
use FFI::Platypus 1.00;
use FFI::Platypus::Memory qw(malloc free memcpy);
use FFI::Platypus::Buffer qw(scalar_to_buffer);
use Encode qw(encode);

# ============================================================
# Constants
# ============================================================
use constant {
    RO_INIT_MULTITHREADED   => 1,
    S_OK                    => 0,
    S_FALSE                 => 1,
    SIZEOF_PTR              => 8,              # x64 only
    HSTRING_HEADER_SIZE     => 8 * 5,          # Opaque header: 5 pointers
    APP_ID                  => '0123456789ABCDEF',
};

# WinRT Runtime Class names
use constant {
    RUNTIMECLASS_XML_DOCUMENT       => 'Windows.Data.Xml.Dom.XmlDocument',
    RUNTIMECLASS_TOAST_MANAGER      => 'Windows.UI.Notifications.ToastNotificationManager',
    RUNTIMECLASS_TOAST_NOTIFICATION => 'Windows.UI.Notifications.ToastNotification',
};

# ============================================================
# GUIDs (packed as 16-byte binary: DWORD + WORD + WORD + BYTE[8])
# ============================================================
sub make_guid {
    my ($d1, $d2, $d3, @d4) = @_;
    pack('VvvC8', $d1, $d2, $d3, @d4);
}

my $IID_IToastNotificationManagerStatics = make_guid(
    0x50ac103f, 0xd235, 0x4598,
    0xbb, 0xef, 0x98, 0xfe, 0x4d, 0x1a, 0x3a, 0xd4
);
my $IID_IToastNotificationFactory = make_guid(
    0x04124b20, 0x82c6, 0x4229,
    0xb1, 0x09, 0xfd, 0x9e, 0xd4, 0x66, 0x2b, 0x53
);
my $IID_IXmlDocument = make_guid(
    0xf7f3a506, 0x1e87, 0x42d6,
    0xbc, 0xfb, 0xb8, 0xc8, 0x09, 0xfa, 0x54, 0x94
);
my $IID_IXmlDocumentIO = make_guid(
    0x6cd0e74e, 0xee65, 0x4489,
    0x9e, 0xbf, 0xca, 0x43, 0xe8, 0x7b, 0xa6, 0x37
);

# ============================================================
# FFI setup and DLL function imports
# ============================================================
my $ffi = FFI::Platypus->new(
    api => 1,
    lib => ['combase.dll', 'shell32.dll', 'kernel32.dll'],
);

# combase.dll - WinRT runtime functions
$ffi->attach( RoInitialize => ['uint32'] => 'sint32' );
$ffi->attach( RoUninitialize => [] => 'void' );
$ffi->attach( WindowsCreateStringReference =>
    ['opaque', 'uint32', 'opaque', 'opaque'] => 'sint32' );
$ffi->attach( RoActivateInstance =>
    ['opaque', 'opaque'] => 'sint32' );
$ffi->attach( RoGetActivationFactory =>
    ['opaque', 'opaque', 'opaque'] => 'sint32' );

# shell32.dll - App ID registration
$ffi->attach( SetCurrentProcessExplicitAppUserModelID =>
    ['opaque'] => 'sint32' );

# kernel32.dll - Debug output
$ffi->attach( OutputDebugStringW => ['opaque'] => 'void' );

# ============================================================
# GC guard: prevent deallocation of buffers that must remain
# alive while WinRT holds references to them.
# WindowsCreateStringReference does NOT copy the string.
# ============================================================
my @gc_guard;

# ============================================================
# Memory helpers
# ============================================================

# Allocate zeroed memory and register it in the GC guard
sub alloc {
    my ($size) = @_;
    my $ptr = malloc($size);
    # Zero-fill the buffer
    my $zeros = "\0" x $size;
    my ($src, $len) = scalar_to_buffer($zeros);
    memcpy($ptr, $src, $len);
    push @gc_guard, $ptr;
    return $ptr;
}

# Allocate memory and copy Perl string data into it
sub alloc_bytes {
    my ($data) = @_;
    my $len = length($data);
    my $buf = alloc($len);
    my ($src, undef) = scalar_to_buffer($data);
    memcpy($buf, $src, $len);
    return $buf;
}

# Read a pointer-sized value (8 bytes on x64) from a memory address
sub read_ptr {
    my ($addr) = @_;
    return unpack('Q<', unpack('P8', pack('Q<', $addr)));
}

# Encode a Perl string as UTF-16LE with null terminator
sub to_wstr {
    my ($str) = @_;
    return encode('UTF-16LE', $str . "\0");
}

# ============================================================
# Debug output
# ============================================================
sub debug_print {
    my ($msg) = @_;
    my $wstr = to_wstr("[PlToast] $msg\n");
    my $buf = alloc_bytes($wstr);
    OutputDebugStringW($buf);
    print "[PlToast] $msg\n";
}

# ============================================================
# HSTRING helper
# ============================================================
sub create_hstring {
    my ($str) = @_;

    # Allocate a persistent UTF-16LE buffer (must outlive the HSTRING)
    my $wstr = to_wstr($str);
    my $buf = alloc_bytes($wstr);

    my $header = alloc(HSTRING_HEADER_SIZE);
    my $hs_out = alloc(SIZEOF_PTR);

    my $hr = WindowsCreateStringReference($buf, length($str), $header, $hs_out);
    die sprintf("WindowsCreateStringReference failed: 0x%08X", $hr & 0xFFFFFFFF)
        unless $hr == S_OK;

    # Return the HSTRING handle value (pointer as integer)
    return read_ptr($hs_out);
}

# ============================================================
# COM VTable helpers
# ============================================================

# Create and call a COM method by VTable index
# Returns an FFI::Platypus::Function object
sub com_call {
    my ($obj_addr, $index, $arg_types, $ret_type) = @_;
    $ret_type //= 'sint32';

    # Dereference the vtable pointer: obj -> vtbl -> vtbl[index]
    my $vtbl    = read_ptr($obj_addr);
    my $fn_addr = read_ptr($vtbl + $index * SIZEOF_PTR);

    return $ffi->function($fn_addr, $arg_types, $ret_type);
}

# IUnknown::Release (VTable index 2)
sub com_release {
    my ($obj_addr) = @_;
    return unless $obj_addr && $obj_addr != 0;
    eval {
        com_call($obj_addr, 2, ['opaque'], 'uint32')->call($obj_addr);
    };
    # Ignore release errors during cleanup
}

# IUnknown::QueryInterface (VTable index 0)
sub com_query_interface {
    my ($obj_addr, $iid_bytes) = @_;

    my $iid_buf = alloc_bytes($iid_bytes);
    my $out = alloc(SIZEOF_PTR);

    my $hr = com_call($obj_addr, 0,
        ['opaque', 'opaque', 'opaque'], 'sint32'
    )->call($obj_addr, $iid_buf, $out);

    die sprintf("QueryInterface failed: 0x%08X", $hr & 0xFFFFFFFF)
        unless $hr == S_OK;

    return read_ptr($out);
}

# ============================================================
# Create IXmlDocument from XML string
# ============================================================
sub create_xml_document_from_string {
    my ($xml_string) = @_;

    # RoActivateInstance to get IInspectable for XmlDocument
    my $hs_class = create_hstring(RUNTIMECLASS_XML_DOCUMENT);
    my $inspectable_out = alloc(SIZEOF_PTR);
    my $hr = RoActivateInstance($hs_class, $inspectable_out);
    die sprintf("RoActivateInstance(XmlDocument) failed: 0x%08X", $hr & 0xFFFFFFFF)
        unless $hr == S_OK;
    my $inspectable = read_ptr($inspectable_out);
    debug_print(sprintf("XmlDocument IInspectable: 0x%016X", $inspectable));

    # QueryInterface for IXmlDocument
    my $xml_doc = com_query_interface($inspectable, $IID_IXmlDocument);
    debug_print(sprintf("IXmlDocument: 0x%016X", $xml_doc));
    com_release($inspectable);

    # QueryInterface for IXmlDocumentIO (needed for LoadXml)
    my $xml_doc_io = com_query_interface($xml_doc, $IID_IXmlDocumentIO);
    debug_print(sprintf("IXmlDocumentIO: 0x%016X", $xml_doc_io));

    # IXmlDocumentIO::LoadXml (VTable index 6)
    # Layout: IUnknown(0-2) + IInspectable(3-5) + LoadXml(6)
    my $hs_xml = create_hstring($xml_string);
    $hr = com_call($xml_doc_io, 6,
        ['opaque', 'opaque'], 'sint32'
    )->call($xml_doc_io, $hs_xml);
    die sprintf("IXmlDocumentIO::LoadXml failed: 0x%08X", $hr & 0xFFFFFFFF)
        unless $hr == S_OK;
    debug_print("XML loaded successfully");

    com_release($xml_doc_io);
    return $xml_doc;
}

# ============================================================
# Main
# ============================================================
sub main {
    debug_print("=== Starting Toast Notification ===");
    debug_print("Perl: $^V ($^O)");

    # Set AppUserModelID for desktop toast routing (non-packaged apps)
    my $app_id_buf = alloc_bytes(to_wstr(APP_ID));
    my $hr = SetCurrentProcessExplicitAppUserModelID($app_id_buf);
    debug_print(sprintf("SetCurrentProcessExplicitAppUserModelID: 0x%08X", $hr & 0xFFFFFFFF));

    # Initialize WinRT
    $hr = RoInitialize(RO_INIT_MULTITHREADED);
    unless ($hr == S_OK || $hr == S_FALSE) {
        die sprintf("RoInitialize failed: 0x%08X", $hr & 0xFFFFFFFF);
    }
    debug_print("WinRT initialized");

    eval {
        # Toast XML content (same structure as C/Python/Ruby version)
        my $xml_string =
            "<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">\r\n" .
            "\t<visual>\r\n" .
            "\t\t<binding template=\"ToastGeneric\">\r\n" .
            "\t\t\t<text><![CDATA[Hello, WinRT(Perl) World!]]></text>\r\n" .
            "\t\t</binding>\r\n" .
            "\t</visual>\r\n" .
            "\t<audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />\r\n" .
            "</toast>\r\n";

        my $input_xml = create_xml_document_from_string($xml_string);

        # ---- ToastNotificationManager ----
        # Get IToastNotificationManagerStatics via activation factory
        my $hs_tnm = create_hstring(RUNTIMECLASS_TOAST_MANAGER);
        my $iid_statics_buf = alloc_bytes($IID_IToastNotificationManagerStatics);
        my $statics_out = alloc(SIZEOF_PTR);

        $hr = RoGetActivationFactory($hs_tnm, $iid_statics_buf, $statics_out);
        die sprintf("RoGetActivationFactory(ToastNotificationManager) failed: 0x%08X",
            $hr & 0xFFFFFFFF) unless $hr == S_OK;
        my $toast_statics = read_ptr($statics_out);
        debug_print(sprintf("IToastNotificationManagerStatics: 0x%016X", $toast_statics));

        # IToastNotificationManagerStatics::CreateToastNotifierWithId (VTable index 7)
        # Layout: IUnknown(0-2) + IInspectable(3-5) + CreateToastNotifier(6)
        #         + CreateToastNotifierWithId(7)
        my $hs_appid = create_hstring(APP_ID);
        my $notifier_out = alloc(SIZEOF_PTR);
        debug_print("Using App ID: " . APP_ID);

        $hr = com_call($toast_statics, 7,
            ['opaque', 'opaque', 'opaque'], 'sint32'
        )->call($toast_statics, $hs_appid, $notifier_out);
        die sprintf("CreateToastNotifierWithId failed: 0x%08X", $hr & 0xFFFFFFFF)
            unless $hr == S_OK;
        my $notifier = read_ptr($notifier_out);
        debug_print(sprintf("IToastNotifier: 0x%016X", $notifier));

        # ---- ToastNotificationFactory ----
        # Get IToastNotificationFactory via activation factory
        my $hs_tn = create_hstring(RUNTIMECLASS_TOAST_NOTIFICATION);
        my $iid_factory_buf = alloc_bytes($IID_IToastNotificationFactory);
        my $factory_out = alloc(SIZEOF_PTR);

        $hr = RoGetActivationFactory($hs_tn, $iid_factory_buf, $factory_out);
        die sprintf("RoGetActivationFactory(ToastNotification) failed: 0x%08X",
            $hr & 0xFFFFFFFF) unless $hr == S_OK;
        my $notif_factory = read_ptr($factory_out);
        debug_print(sprintf("IToastNotificationFactory: 0x%016X", $notif_factory));

        # IToastNotificationFactory::CreateToastNotification (VTable index 6)
        # Layout: IUnknown(0-2) + IInspectable(3-5) + CreateToastNotification(6)
        my $toast_out = alloc(SIZEOF_PTR);
        $hr = com_call($notif_factory, 6,
            ['opaque', 'opaque', 'opaque'], 'sint32'
        )->call($notif_factory, $input_xml, $toast_out);
        die sprintf("CreateToastNotification failed: 0x%08X", $hr & 0xFFFFFFFF)
            unless $hr == S_OK;
        my $toast = read_ptr($toast_out);
        debug_print(sprintf("IToastNotification: 0x%016X", $toast));

        # ---- Show the toast ----
        # IToastNotifier::Show (VTable index 6)
        # Layout: IUnknown(0-2) + IInspectable(3-5) + Show(6)
        $hr = com_call($notifier, 6,
            ['opaque', 'opaque'], 'sint32'
        )->call($notifier, $toast);
        die sprintf("IToastNotifier::Show failed: 0x%08X", $hr & 0xFFFFFFFF)
            unless $hr == S_OK;
        debug_print("Toast notification shown!");

        # Keep the program running so the notification remains visible
        print "\nPress Enter to exit...\n";
        <STDIN>;

        # Cleanup COM objects (release in reverse order of creation)
        com_release($toast);
        com_release($notif_factory);
        com_release($notifier);
        com_release($toast_statics);
        com_release($input_xml);

        debug_print("=== Toast Notification Complete ===");
    };
    if ($@) {
        debug_print("ERROR: $@");
    }

    RoUninitialize();
    debug_print("WinRT uninitialized");
}

main();
