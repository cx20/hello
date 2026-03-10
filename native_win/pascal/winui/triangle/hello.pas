{ hello.pas - WinUI3 XAML Island Triangle Sample using Free Pascal
 
  Draws a gradient-filled triangle via WinUI3 XAML DesktopWindowXamlSource
  using raw COM vtable calls. No C++/WinRT or cppwinrt dependency.
  MddBootstrapInitialize2 is called directly with version constants
  defined in Pascal. }

program hello;

{$mode objfpc}{$H+}
{$codepage utf8}

uses
    Windows, SysUtils;

{ =====================================================================
  Windows Runtime type declarations
  ===================================================================== }

type
    HSTRING = Pointer;
    TrustLevel = Integer;

    TGUID = packed record
        Data1: LongWord;
        Data2: Word;
        Data3: Word;
        Data4: array[0..7] of Byte;
    end;
    PGUID = ^TGUID;

    TMicrosoft_UI_WindowId = packed record
        Value: UInt64;
    end;

    TEventRegistrationToken = packed record
        Value: Int64;
    end;

{ =====================================================================
  COM vtable interface records
  ===================================================================== }

type
    { IInspectable vtable (extends IUnknown) }
    PIInspectable = ^TIInspectable;
    PIInspectableVtbl = ^TIInspectableVtbl;
    TIInspectableVtbl = packed record
        { IUnknown }
        QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject: Pointer): HRESULT; stdcall;
        AddRef:         function(Self: Pointer): LongWord; stdcall;
        Release:        function(Self: Pointer): LongWord; stdcall;
        { IInspectable }
        GetIids:            function(Self: Pointer; out iidCount: LongWord; out iids: PGUID): HRESULT; stdcall;
        GetRuntimeClassName: function(Self: Pointer; out className: HSTRING): HRESULT; stdcall;
        GetTrustLevel:      function(Self: Pointer; out trust: TrustLevel): HRESULT; stdcall;
    end;
    TIInspectable = packed record
        lpVtbl: PIInspectableVtbl;
    end;

    { IWindowsXamlManagerStatics }
    PIWindowsXamlManagerStatics = ^TIWindowsXamlManagerStatics;
    PIWindowsXamlManagerStaticsVtbl = ^TIWindowsXamlManagerStaticsVtbl;
    TIWindowsXamlManagerStaticsVtbl = packed record
        { IUnknown }
        QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject: Pointer): HRESULT; stdcall;
        AddRef:         function(Self: Pointer): LongWord; stdcall;
        Release:        function(Self: Pointer): LongWord; stdcall;
        { IInspectable }
        GetIids:            function(Self: Pointer; out iidCount: LongWord; out iids: PGUID): HRESULT; stdcall;
        GetRuntimeClassName: function(Self: Pointer; out className: HSTRING): HRESULT; stdcall;
        GetTrustLevel:      function(Self: Pointer; out trust: TrustLevel): HRESULT; stdcall;
        { IWindowsXamlManagerStatics }
        InitializeForCurrentThread: function(Self: Pointer; out value: PIInspectable): HRESULT; stdcall;
    end;
    TIWindowsXamlManagerStatics = packed record
        lpVtbl: PIWindowsXamlManagerStaticsVtbl;
    end;

    { IDesktopWindowXamlSource }
    PIDesktopWindowXamlSource = ^TIDesktopWindowXamlSource;
    PIDesktopWindowXamlSourceVtbl = ^TIDesktopWindowXamlSourceVtbl;
    TIDesktopWindowXamlSourceVtbl = packed record
        { IUnknown }
        QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject: Pointer): HRESULT; stdcall;
        AddRef:         function(Self: Pointer): LongWord; stdcall;
        Release:        function(Self: Pointer): LongWord; stdcall;
        { IInspectable }
        GetIids:            function(Self: Pointer; out iidCount: LongWord; out iids: PGUID): HRESULT; stdcall;
        GetRuntimeClassName: function(Self: Pointer; out className: HSTRING): HRESULT; stdcall;
        GetTrustLevel:      function(Self: Pointer; out trust: TrustLevel): HRESULT; stdcall;
        { IDesktopWindowXamlSource }
        get_Content:              function(Self: Pointer; out value: PIInspectable): HRESULT; stdcall;
        put_Content:              function(Self: Pointer; value: PIInspectable): HRESULT; stdcall;
        get_HasFocus:             function(Self: Pointer; out value: Integer): HRESULT; stdcall;
        get_SystemBackdrop:       function(Self: Pointer; out value: PIInspectable): HRESULT; stdcall;
        put_SystemBackdrop:       function(Self: Pointer; value: PIInspectable): HRESULT; stdcall;
        get_SiteBridge:           function(Self: Pointer; out value: PIInspectable): HRESULT; stdcall;
        add_TakeFocusRequested:   function(Self: Pointer; handler: Pointer; out token: TEventRegistrationToken): HRESULT; stdcall;
        remove_TakeFocusRequested: function(Self: Pointer; token: TEventRegistrationToken): HRESULT; stdcall;
        add_GotFocus:             function(Self: Pointer; handler: Pointer; out token: TEventRegistrationToken): HRESULT; stdcall;
        remove_GotFocus:          function(Self: Pointer; token: TEventRegistrationToken): HRESULT; stdcall;
        NavigateFocus:            function(Self: Pointer; request: PIInspectable; out result: PIInspectable): HRESULT; stdcall;
        Initialize:               function(Self: Pointer; parentWindowId: TMicrosoft_UI_WindowId): HRESULT; stdcall;
    end;
    TIDesktopWindowXamlSource = packed record
        lpVtbl: PIDesktopWindowXamlSourceVtbl;
    end;

    { IXamlReaderStatics }
    PIXamlReaderStatics = ^TIXamlReaderStatics;
    PIXamlReaderStaticsVtbl = ^TIXamlReaderStaticsVtbl;
    TIXamlReaderStaticsVtbl = packed record
        { IUnknown }
        QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject: Pointer): HRESULT; stdcall;
        AddRef:         function(Self: Pointer): LongWord; stdcall;
        Release:        function(Self: Pointer): LongWord; stdcall;
        { IInspectable }
        GetIids:            function(Self: Pointer; out iidCount: LongWord; out iids: PGUID): HRESULT; stdcall;
        GetRuntimeClassName: function(Self: Pointer; out className: HSTRING): HRESULT; stdcall;
        GetTrustLevel:      function(Self: Pointer; out trust: TrustLevel): HRESULT; stdcall;
        { IXamlReaderStatics }
        Load: function(Self: Pointer; xaml: HSTRING; out value: PIInspectable): HRESULT; stdcall;
        LoadWithInitialTemplateValidation: function(Self: Pointer; xaml: HSTRING; out value: PIInspectable): HRESULT; stdcall;
    end;
    TIXamlReaderStatics = packed record
        lpVtbl: PIXamlReaderStaticsVtbl;
    end;

    { IDispatcherQueueControllerStatics }
    PIDispatcherQueueControllerStatics = ^TIDispatcherQueueControllerStatics;
    PIDispatcherQueueControllerStaticsVtbl = ^TIDispatcherQueueControllerStaticsVtbl;
    TIDispatcherQueueControllerStaticsVtbl = packed record
        { IUnknown }
        QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject: Pointer): HRESULT; stdcall;
        AddRef:         function(Self: Pointer): LongWord; stdcall;
        Release:        function(Self: Pointer): LongWord; stdcall;
        { IInspectable }
        GetIids:            function(Self: Pointer; out iidCount: LongWord; out iids: PGUID): HRESULT; stdcall;
        GetRuntimeClassName: function(Self: Pointer; out className: HSTRING): HRESULT; stdcall;
        GetTrustLevel:      function(Self: Pointer; out trust: TrustLevel): HRESULT; stdcall;
        { IDispatcherQueueControllerStatics }
        CreateOnDedicatedThread: function(Self: Pointer; out value: PIInspectable): HRESULT; stdcall;
        CreateOnCurrentThread:   function(Self: Pointer; out value: PIInspectable): HRESULT; stdcall;
    end;
    TIDispatcherQueueControllerStatics = packed record
        lpVtbl: PIDispatcherQueueControllerStaticsVtbl;
    end;

{ =====================================================================
  DispatcherQueue types for CoreMessaging fallback
  ===================================================================== }

type
    TDispatcherQueueOptions = packed record
        dwSize:        LongWord;
        threadType:    LongWord;
        apartmentType: LongWord;
    end;

const
    DQTYPE_THREAD_CURRENT = 2;
    DQTAT_COM_NONE        = 0;

{ =====================================================================
  Interface GUIDs
  ===================================================================== }

const
    IID_IWindowsXamlManagerStatics: TGUID = (
        Data1: $56CB591D; Data2: $DE97; Data3: $539F;
        Data4: ($88, $1D, $8C, $CD, $C4, $4F, $A6, $C4));
    IID_IDesktopWindowXamlSource: TGUID = (
        Data1: $553AF92C; Data2: $1381; Data3: $51D6;
        Data4: ($BE, $E0, $F3, $4B, $EB, $04, $2E, $A8));
    IID_IXamlReaderStatics: TGUID = (
        Data1: $82A4CD9E; Data2: $435E; Data3: $5AEB;
        Data4: ($8C, $4F, $30, $0C, $EC, $E4, $5C, $AE));
    IID_IUIElement: TGUID = (
        Data1: $C3C01020; Data2: $320C; Data3: $5CF6;
        Data4: ($9D, $24, $D3, $96, $BB, $FA, $4D, $8B));
    IID_IDispatcherQueueControllerStatics: TGUID = (
        Data1: $F18D6145; Data2: $722B; Data3: $593D;
        Data4: ($BC, $F2, $A6, $1E, $71, $3F, $00, $37));

{ =====================================================================
  Windows App SDK version constants
  =====================================================================
  These correspond to macros in WindowsAppSDK-VersionInfo.h.
  Update when changing SDK version.

  WINDOWSAPPSDK_RELEASE_MAJORMINOR = (major shl 16) or minor
  WINDOWSAPPSDK_RELEASE_VERSION_TAG_W = '' for stable releases
  WINDOWSAPPSDK_RUNTIME_VERSION_UINT64 = packed PACKAGE_VERSION
    (0 = accept any runtime version for this major.minor) }

const
    WINDOWSAPPSDK_RELEASE_MAJORMINOR: LongWord     = $00010008; { 1.8 }
    WINDOWSAPPSDK_RELEASE_VERSION_TAG: WideString   = '';        { stable }
    WINDOWSAPPSDK_RUNTIME_VERSION_UINT64: UInt64    = 0;         { any }
    MddBootstrapInitializeOptions_None: LongWord    = 0;

{ =====================================================================
  External function declarations
  ===================================================================== }

{ combase.dll - WinRT API }
function WindowsCreateString(sourceString: PWideChar; length: LongWord;
    out str: HSTRING): HRESULT; stdcall; external 'combase.dll';
function WindowsDeleteString(str: HSTRING): HRESULT; stdcall;
    external 'combase.dll';
function RoInitialize(initType: LongWord): HRESULT; stdcall;
    external 'combase.dll';
procedure RoUninitialize; stdcall;
    external 'combase.dll';
function RoGetActivationFactory(activatableClassId: HSTRING;
    const iid: TGUID; out factory: Pointer): HRESULT; stdcall;
    external 'combase.dll';
function RoActivateInstance(activatableClassId: HSTRING;
    out instance: PIInspectable): HRESULT; stdcall;
    external 'combase.dll';

{ ole32.dll }
function CoInitializeEx(pvReserved: Pointer; dwCoInit: LongWord): HRESULT;
    stdcall; external 'ole32.dll';
procedure CoUninitialize; stdcall; external 'ole32.dll';

{ CoreMessaging.dll }
function CreateDispatcherQueueController(
    options: TDispatcherQueueOptions;
    out controller: Pointer): HRESULT; stdcall;
    external 'CoreMessaging.dll';

{ Microsoft.WindowsAppRuntime.Bootstrap.dll }
function MddBootstrapInitialize2(
    majorMinorVersion: LongWord;
    versionTag: PWideChar;
    minVersion: UInt64;
    options: LongWord): HRESULT; stdcall;
    external 'Microsoft.WindowsAppRuntime.Bootstrap.dll';
procedure MddBootstrapShutdown; stdcall;
    external 'Microsoft.WindowsAppRuntime.Bootstrap.dll';

{ Windowing_GetWindowIdFromWindow function pointer type }
type
    TFnWindowing_GetWindowIdFromWindow = function(
        hwnd: HWND; out windowId: TMicrosoft_UI_WindowId): HRESULT; stdcall;

{ =====================================================================
  Global state
  ===================================================================== }

var
    gMainWindow: HWND = 0;
    gDispatcherQueueController: PIInspectable = nil;
    gCoreDispatcherQueueController: Pointer = nil;
    gWindowsXamlManager: PIInspectable = nil;
    gDesktopWindowXamlSourceInspectable: PIInspectable = nil;
    gDesktopWindowXamlSource: PIDesktopWindowXamlSource = nil;

{ =====================================================================
  Utility functions
  ===================================================================== }

procedure LogState(const FuncName, Msg: AnsiString);
var
    Line: AnsiString;
begin
    Line := '[' + FuncName + '] ' + Msg + #10;
    OutputDebugStringA(PAnsiChar(Line));
end;

procedure ReleaseIf(var p: Pointer);
var
    Vtbl: PIInspectableVtbl;
begin
    if p <> nil then
    begin
        Vtbl := PIInspectable(p)^.lpVtbl;
        Vtbl^.Release(p);
        p := nil;
    end;
end;

function CreateHStringFromWide(const S: WideString; out HS: HSTRING): HRESULT;
begin
    HS := nil;
    if Length(S) = 0 then
    begin
        Result := WindowsCreateString(PWideChar(WideString(#0)), 0, HS);
        Exit;
    end;
    Result := WindowsCreateString(PWideChar(S), Length(S), HS);
end;

{ =====================================================================
  DispatcherQueue initialization
  ===================================================================== }

function EnsureDispatcherQueue: HRESULT;
const
    FN = 'EnsureDispatcherQueue';
var
    hr: HRESULT;
    ClassName: HSTRING;
    Statics: PIDispatcherQueueControllerStatics;
    Options: TDispatcherQueueOptions;
    hrCore: HRESULT;
begin
    ClassName := nil;
    Statics := nil;
    Result := 0;

    if (gDispatcherQueueController <> nil) and (gCoreDispatcherQueueController <> nil) then
    begin
        LogState(FN, 'already initialized');
        Exit;
    end;

    { Try WinUI3 DispatcherQueueController.CreateOnCurrentThread }
    if gDispatcherQueueController = nil then
    begin
        hr := CreateHStringFromWide('Microsoft.UI.Dispatching.DispatcherQueueController', ClassName);
        if hr >= 0 then
        begin
            hr := RoGetActivationFactory(ClassName, IID_IDispatcherQueueControllerStatics, Statics);
            LogState(FN, Format('RoGetActivationFactory(DispatcherQueueController) hr=0x%08X', [LongWord(hr)]));
            if hr >= 0 then
            begin
                hr := Statics^.lpVtbl^.CreateOnCurrentThread(Statics, gDispatcherQueueController);
                LogState(FN, Format('CreateOnCurrentThread hr=0x%08X', [LongWord(hr)]));
            end;
            ReleaseIf(Pointer(Statics));
        end;
        if ClassName <> nil then WindowsDeleteString(ClassName);
    end;

    { Fallback to CoreMessaging }
    if gCoreDispatcherQueueController = nil then
    begin
        FillChar(Options, SizeOf(Options), 0);
        Options.dwSize := SizeOf(Options);
        Options.threadType := DQTYPE_THREAD_CURRENT;
        Options.apartmentType := DQTAT_COM_NONE;
        hrCore := CreateDispatcherQueueController(Options, gCoreDispatcherQueueController);
        LogState(FN, Format('CoreMessaging CreateDispatcherQueueController hr=0x%08X', [LongWord(hrCore)]));
        if (hrCore < 0) and (gDispatcherQueueController = nil) then
            Result := hrCore;
    end;

    if (gDispatcherQueueController <> nil) or (gCoreDispatcherQueueController <> nil) then
        Result := 0;
end;

{ =====================================================================
  WindowId resolution
  ===================================================================== }

function GetWindowIdForHwnd(Wnd: HWND; out WindowId: TMicrosoft_UI_WindowId): HRESULT;
const
    FN = 'GetWindowIdForHwnd';
var
    FrameworkUdk: HMODULE;
    Proc: TFnWindowing_GetWindowIdFromWindow;
begin
    WindowId.Value := 0;

    FrameworkUdk := GetModuleHandleW('Microsoft.Internal.FrameworkUdk.dll');
    if FrameworkUdk = 0 then
        FrameworkUdk := LoadLibraryW('Microsoft.Internal.FrameworkUdk.dll');
    if FrameworkUdk = 0 then
    begin
        LogState(FN, 'LoadLibraryW failed');
        Result := HRESULT($80070000) or HRESULT(GetLastError);
        Exit;
    end;

    Proc := TFnWindowing_GetWindowIdFromWindow(
        GetProcAddress(FrameworkUdk, 'Windowing_GetWindowIdFromWindow'));
    if not Assigned(Proc) then
    begin
        LogState(FN, 'GetProcAddress failed');
        Result := HRESULT($80070000) or HRESULT(GetLastError);
        Exit;
    end;

    Result := Proc(Wnd, WindowId);
    LogState(FN, Format('Windowing_GetWindowIdFromWindow hr=0x%08X value=%u',
        [LongWord(Result), WindowId.Value]));
end;

{ =====================================================================
  XAML content loading
  ===================================================================== }

function LoadTriangleXaml: HRESULT;
const
    FN = 'LoadTriangleXaml';
    TriangleXaml: WideString =
        '<Canvas xmlns=''http://schemas.microsoft.com/winfx/2006/xaml/presentation'' ' +
        'xmlns:x=''http://schemas.microsoft.com/winfx/2006/xaml'' Background=''White''>' +
        '<Path Stroke=''Black'' StrokeThickness=''1''>' +
        '<Path.Fill>' +
        '<LinearGradientBrush StartPoint=''0,0'' EndPoint=''1,1''>' +
        '<GradientStop Color=''Red'' Offset=''0''/>' +
        '<GradientStop Color=''Green'' Offset=''0.5''/>' +
        '<GradientStop Color=''Blue'' Offset=''1''/>' +
        '</LinearGradientBrush>' +
        '</Path.Fill>' +
        '<Path.Data>' +
        '<PathGeometry>' +
        '<PathFigure StartPoint=''300,100'' IsClosed=''True''>' +
        '<LineSegment Point=''500,400''/>' +
        '<LineSegment Point=''100,400''/>' +
        '</PathFigure>' +
        '</PathGeometry>' +
        '</Path.Data>' +
        '</Path>' +
        '</Canvas>';
var
    hr: HRESULT;
    ClassName, XamlText: HSTRING;
    XamlReaderStatics: PIXamlReaderStatics;
    RootObject, RootElement: PIInspectable;
begin
    ClassName := nil;
    XamlText := nil;
    XamlReaderStatics := nil;
    RootObject := nil;
    RootElement := nil;

    { Get XamlReader activation factory }
    hr := CreateHStringFromWide('Microsoft.UI.Xaml.Markup.XamlReader', ClassName);
    if hr < 0 then
    begin
        LogState(FN, Format('CreateHString(class) failed hr=0x%08X', [LongWord(hr)]));
        Result := hr;
        Exit;
    end;

    hr := RoGetActivationFactory(ClassName, IID_IXamlReaderStatics, XamlReaderStatics);
    LogState(FN, Format('RoGetActivationFactory(XamlReader) hr=0x%08X', [LongWord(hr)]));
    WindowsDeleteString(ClassName);
    if hr < 0 then begin Result := hr; Exit; end;

    { Create HSTRING for XAML text }
    hr := CreateHStringFromWide(TriangleXaml, XamlText);
    if hr < 0 then
    begin
        LogState(FN, Format('CreateHString(xaml) failed hr=0x%08X', [LongWord(hr)]));
        ReleaseIf(Pointer(XamlReaderStatics));
        Result := hr;
        Exit;
    end;

    { Load XAML }
    hr := XamlReaderStatics^.lpVtbl^.Load(XamlReaderStatics, XamlText, RootObject);
    LogState(FN, Format('IXamlReaderStatics::Load hr=0x%08X', [LongWord(hr)]));
    WindowsDeleteString(XamlText);
    if hr < 0 then
    begin
        ReleaseIf(Pointer(XamlReaderStatics));
        Result := hr;
        Exit;
    end;

    { QueryInterface for IUIElement }
    hr := RootObject^.lpVtbl^.QueryInterface(RootObject, IID_IUIElement, RootElement);
    LogState(FN, Format('QI(IUIElement) hr=0x%08X', [LongWord(hr)]));
    if hr < 0 then
    begin
        ReleaseIf(Pointer(RootObject));
        ReleaseIf(Pointer(XamlReaderStatics));
        Result := hr;
        Exit;
    end;

    { Set content }
    hr := gDesktopWindowXamlSource^.lpVtbl^.put_Content(gDesktopWindowXamlSource, RootElement);
    LogState(FN, Format('put_Content hr=0x%08X', [LongWord(hr)]));

    ReleaseIf(Pointer(RootElement));
    ReleaseIf(Pointer(RootObject));
    ReleaseIf(Pointer(XamlReaderStatics));
    Result := hr;
end;

{ =====================================================================
  XAML Island initialization
  ===================================================================== }

function InitializeXamlIsland(ParentWindow: HWND): HRESULT;
const
    FN = 'InitializeXamlIsland';
var
    hr: HRESULT;
    ClassName: HSTRING;
    XamlManagerStatics: PIWindowsXamlManagerStatics;
    WindowId: TMicrosoft_UI_WindowId;
begin
    ClassName := nil;
    XamlManagerStatics := nil;

    hr := EnsureDispatcherQueue;
    if hr < 0 then begin Result := hr; Exit; end;

    { Initialize WindowsXamlManager }
    hr := CreateHStringFromWide('Microsoft.UI.Xaml.Hosting.WindowsXamlManager', ClassName);
    if hr < 0 then begin Result := hr; Exit; end;

    hr := RoGetActivationFactory(ClassName, IID_IWindowsXamlManagerStatics, XamlManagerStatics);
    LogState(FN, Format('RoGetActivationFactory(WindowsXamlManager) hr=0x%08X', [LongWord(hr)]));
    if hr < 0 then
    begin
        WindowsDeleteString(ClassName);
        Result := hr;
        Exit;
    end;

    hr := XamlManagerStatics^.lpVtbl^.InitializeForCurrentThread(
        XamlManagerStatics, gWindowsXamlManager);
    LogState(FN, Format('InitializeForCurrentThread hr=0x%08X', [LongWord(hr)]));
    if hr < 0 then
    begin
        { Retry after ensuring dispatcher queue }
        EnsureDispatcherQueue;
        hr := XamlManagerStatics^.lpVtbl^.InitializeForCurrentThread(
            XamlManagerStatics, gWindowsXamlManager);
        LogState(FN, Format('InitializeForCurrentThread retry hr=0x%08X', [LongWord(hr)]));
    end;
    if hr < 0 then
        LogState(FN, 'InitializeForCurrentThread failed; continuing with DesktopWindowXamlSource fallback');

    ReleaseIf(Pointer(XamlManagerStatics));
    WindowsDeleteString(ClassName);

    { Create DesktopWindowXamlSource }
    hr := CreateHStringFromWide('Microsoft.UI.Xaml.Hosting.DesktopWindowXamlSource', ClassName);
    if hr < 0 then begin Result := hr; Exit; end;

    hr := RoActivateInstance(ClassName, gDesktopWindowXamlSourceInspectable);
    LogState(FN, Format('RoActivateInstance(DesktopWindowXamlSource) hr=0x%08X', [LongWord(hr)]));
    WindowsDeleteString(ClassName);
    if hr < 0 then begin Result := hr; Exit; end;

    { QueryInterface for IDesktopWindowXamlSource }
    hr := gDesktopWindowXamlSourceInspectable^.lpVtbl^.QueryInterface(
        gDesktopWindowXamlSourceInspectable,
        IID_IDesktopWindowXamlSource,
        gDesktopWindowXamlSource);
    LogState(FN, Format('QI(IDesktopWindowXamlSource) hr=0x%08X', [LongWord(hr)]));
    if hr < 0 then begin Result := hr; Exit; end;

    { Get WindowId for parent HWND }
    hr := GetWindowIdForHwnd(ParentWindow, WindowId);
    if hr < 0 then begin Result := hr; Exit; end;

    { Initialize with parent window }
    hr := gDesktopWindowXamlSource^.lpVtbl^.Initialize(gDesktopWindowXamlSource, WindowId);
    LogState(FN, Format('Initialize hr=0x%08X', [LongWord(hr)]));
    if hr < 0 then begin Result := hr; Exit; end;

    Result := LoadTriangleXaml;
end;

procedure CleanupXamlIsland;
begin
    LogState('CleanupXamlIsland', 'begin');
    ReleaseIf(Pointer(gDesktopWindowXamlSource));
    ReleaseIf(Pointer(gDesktopWindowXamlSourceInspectable));
    ReleaseIf(Pointer(gWindowsXamlManager));
    ReleaseIf(gCoreDispatcherQueueController);
    ReleaseIf(Pointer(gDispatcherQueueController));
    LogState('CleanupXamlIsland', 'end');
end;

{ =====================================================================
  Window procedure and creation
  ===================================================================== }

function WindowProc(Wnd: HWND; Msg: UINT; WP: WPARAM; LP: LPARAM): LRESULT; stdcall;
begin
    case Msg of
        WM_DESTROY:
            begin
                PostQuitMessage(0);
                Result := 0;
            end;
    else
        Result := DefWindowProcW(Wnd, Msg, WP, LP);
    end;
end;

function CreateMainWindow(Instance: HINST): HRESULT;
const
    FN = 'CreateMainWindow';
    WndClassName: WideString = 'HelloWinUI3PascalWindow';
    WndTitle: WideString = 'Hello, World!';
var
    WC: TWndClassExW;
    RC: TRect;
    Style: LongWord;
begin
    FillChar(WC, SizeOf(WC), 0);
    WC.cbSize        := SizeOf(TWndClassExW);
    WC.style         := CS_HREDRAW or CS_VREDRAW;
    WC.lpfnWndProc   := @WindowProc;
    WC.hInstance     := Instance;
    WC.hCursor       := LoadCursorW(0, PWideChar(IDC_ARROW));
    WC.hbrBackground := COLOR_WINDOW + 1;
    WC.lpszClassName := PWideChar(WndClassName);

    if RegisterClassExW(WC) = 0 then
    begin
        if GetLastError <> 1410 then { ERROR_CLASS_ALREADY_EXISTS }
        begin
            LogState(FN, Format('RegisterClassExW failed gle=%u', [GetLastError]));
            Result := HRESULT($80070000) or HRESULT(GetLastError);
            Exit;
        end;
    end;

    Style := WS_OVERLAPPEDWINDOW;
    RC.Left := 0; RC.Top := 0; RC.Right := 960; RC.Bottom := 540;
    AdjustWindowRect(RC, Style, False);

    gMainWindow := CreateWindowExW(
        0,
        PWideChar(WndClassName),
        PWideChar(WndTitle),
        Style,
        Integer(CW_USEDEFAULT), Integer(CW_USEDEFAULT),
        RC.Right - RC.Left, RC.Bottom - RC.Top,
        0, 0, Instance, nil);

    if gMainWindow = 0 then
    begin
        LogState(FN, Format('CreateWindowExW failed gle=%u', [GetLastError]));
        Result := HRESULT($80070000) or HRESULT(GetLastError);
        Exit;
    end;

    ShowWindow(gMainWindow, SW_SHOW);
    UpdateWindow(gMainWindow);
    LogState(FN, Format('window created hwnd=0x%p', [Pointer(gMainWindow)]));
    Result := 0;
end;

{ =====================================================================
  Entry point
  ===================================================================== }

const
    RO_INIT_SINGLETHREADED = 0;
    COINIT_APARTMENTTHREADED = 2;
    RPC_E_CHANGED_MODE = HRESULT($80010106);

var
    hr: HRESULT;
    BootstrapInitialized: Boolean = False;
    ApartmentInitialized: Boolean = False;
    RoInitialized: Boolean = False;
    Msg: TMsg;

begin
    LogState('Main', 'begin');

    { Initialize Windows App SDK bootstrap }
    hr := MddBootstrapInitialize2(
        WINDOWSAPPSDK_RELEASE_MAJORMINOR,
        PWideChar(WINDOWSAPPSDK_RELEASE_VERSION_TAG),
        WINDOWSAPPSDK_RUNTIME_VERSION_UINT64,
        MddBootstrapInitializeOptions_None);
    LogState('Main', Format('MddBootstrapInitialize2 hr=0x%08X', [LongWord(hr)]));
    if hr < 0 then
    begin
        MessageBoxW(0, 'MddBootstrapInitialize2 failed.', 'Error', MB_ICONERROR);
        Halt(1);
    end;
    BootstrapInitialized := True;

    { Initialize COM apartment }
    hr := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
    LogState('Main', Format('CoInitializeEx hr=0x%08X', [LongWord(hr)]));
    if hr >= 0 then
        ApartmentInitialized := True
    else if LongWord(hr) <> LongWord(RPC_E_CHANGED_MODE) then
    begin
        MessageBoxW(0, 'CoInitializeEx failed.', 'Error', MB_ICONERROR);
        MddBootstrapShutdown;
        Halt(1);
    end;

    { Initialize WinRT }
    hr := RoInitialize(RO_INIT_SINGLETHREADED);
    LogState('Main', Format('RoInitialize hr=0x%08X', [LongWord(hr)]));
    if (hr >= 0) or (hr = 1) then { S_OK or S_FALSE }
        RoInitialized := True
    else if LongWord(hr) <> LongWord(RPC_E_CHANGED_MODE) then
    begin
        MessageBoxW(0, 'RoInitialize failed.', 'Error', MB_ICONERROR);
        if ApartmentInitialized then CoUninitialize;
        MddBootstrapShutdown;
        Halt(1);
    end;

    { Create dispatcher queue }
    hr := EnsureDispatcherQueue;
    if hr < 0 then
    begin
        MessageBoxW(0, 'EnsureDispatcherQueue failed.', 'Error', MB_ICONERROR);
        if RoInitialized then RoUninitialize;
        if ApartmentInitialized then CoUninitialize;
        MddBootstrapShutdown;
        Halt(1);
    end;

    { Create main window }
    hr := CreateMainWindow(HInstance);
    if hr < 0 then
    begin
        MessageBoxW(0, 'Failed to create main window.', 'Error', MB_ICONERROR);
        if RoInitialized then RoUninitialize;
        if ApartmentInitialized then CoUninitialize;
        MddBootstrapShutdown;
        Halt(1);
    end;

    { Initialize XAML island }
    hr := InitializeXamlIsland(gMainWindow);
    LogState('Main', Format('InitializeXamlIsland hr=0x%08X', [LongWord(hr)]));
    if hr < 0 then
    begin
        MessageBoxW(0, 'Failed to initialize WinUI3 XAML island.', 'Error', MB_ICONERROR);
        CleanupXamlIsland;
        if RoInitialized then RoUninitialize;
        if ApartmentInitialized then CoUninitialize;
        MddBootstrapShutdown;
        Halt(1);
    end;

    { Message loop }
    while GetMessageW(Msg, 0, 0, 0) do
    begin
        TranslateMessage(Msg);
        DispatchMessageW(Msg);
    end;

    { Cleanup }
    CleanupXamlIsland;
    if RoInitialized then RoUninitialize;
    if ApartmentInitialized then CoUninitialize;
    if BootstrapInitialized then MddBootstrapShutdown;

    LogState('Main', 'end');
end.