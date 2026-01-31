program hello;

{$mode objfpc}{$H+}

uses
    Windows, Messages;

type
    GpStatus = Integer;
    GpGraphics = Pointer;
    GpPath = Pointer;
    GpBrush = Pointer;
    GpFillMode = Integer;
    ARGB = DWORD;
    PARGB = ^ARGB;

    GpPoint = record
        X: Integer;
        Y: Integer;
    end;
    PGpPoint = ^GpPoint;

    GdiplusStartupInput = record
        GdiplusVersion: DWORD;
        DebugEventCallback: Pointer;
        SuppressBackgroundThread: BOOL;
        SuppressExternalCodecs: BOOL;
    end;
    PGdiplusStartupInput = ^GdiplusStartupInput;

    GdiplusStartupOutput = record
        NotificationHook: Pointer;
        NotificationUnhook: Pointer;
    end;
    PGdiplusStartupOutput = ^GdiplusStartupOutput;

    TGdiplusStartup = function(var token: ULONG_PTR; input: PGdiplusStartupInput; output: PGdiplusStartupOutput): GpStatus; stdcall;
    TGdiplusShutdown = procedure(token: ULONG_PTR); stdcall;
    TGdipCreateFromHDC = function(hdc: HDC; var graphics: GpGraphics): GpStatus; stdcall;
    TGdipDeleteGraphics = function(graphics: GpGraphics): GpStatus; stdcall;
    TGdipCreatePath = function(fillMode: GpFillMode; var path: GpPath): GpStatus; stdcall;
    TGdipDeletePath = function(path: GpPath): GpStatus; stdcall;
    TGdipAddPathLine2I = function(path: GpPath; points: PGpPoint; count: Integer): GpStatus; stdcall;
    TGdipClosePathFigure = function(path: GpPath): GpStatus; stdcall;
    TGdipCreatePathGradientFromPath = function(path: GpPath; var polyGradient: GpBrush): GpStatus; stdcall;
    TGdipDeleteBrush = function(brush: GpBrush): GpStatus; stdcall;
    TGdipSetPathGradientCenterColor = function(brush: GpBrush; color: ARGB): GpStatus; stdcall;
    TGdipSetPathGradientSurroundColorsWithCount = function(brush: GpBrush; colors: PARGB; var count: Integer): GpStatus; stdcall;
    TGdipFillPath = function(graphics: GpGraphics; brush: GpBrush; path: GpPath): GpStatus; stdcall;

const
    FillModeAlternate = 0;

var
    GdiplusStartup: TGdiplusStartup;
    GdiplusShutdown: TGdiplusShutdown;
    GdipCreateFromHDC: TGdipCreateFromHDC;
    GdipDeleteGraphics: TGdipDeleteGraphics;
    GdipCreatePath: TGdipCreatePath;
    GdipDeletePath: TGdipDeletePath;
    GdipAddPathLine2I: TGdipAddPathLine2I;
    GdipClosePathFigure: TGdipClosePathFigure;
    GdipCreatePathGradientFromPath: TGdipCreatePathGradientFromPath;
    GdipDeleteBrush: TGdipDeleteBrush;
    GdipSetPathGradientCenterColor: TGdipSetPathGradientCenterColor;
    GdipSetPathGradientSurroundColorsWithCount: TGdipSetPathGradientSurroundColorsWithCount;
    GdipFillPath: TGdipFillPath;

    gdiplusToken: ULONG_PTR;
    gdiplusLib: THandle;
    gdiplusInitialized: Boolean;

procedure DebugLog(const Msg: AnsiString);
begin
    OutputDebugStringA(PAnsiChar(Msg));
end;

procedure DebugLogStatus(const Func: AnsiString; Status: GpStatus);
var
    S: AnsiString;
begin
    Str(Status, S);
    DebugLog(Func + ' returned status: ' + S);
end;

function MakeARGB(a, r, g, b: Byte): ARGB;
begin
    Result := (ARGB(a) shl 24) or (ARGB(r) shl 16) or (ARGB(g) shl 8) or ARGB(b);
end;

function LoadGdiplus: Boolean;
begin
    Result := False;
    gdiplusLib := LoadLibrary('gdiplus.dll');
    if gdiplusLib = 0 then
    begin
        DebugLog('Failed to load gdiplus.dll');
        Exit;
    end;
    DebugLog('gdiplus.dll loaded');

    Pointer(GdiplusStartup) := GetProcAddress(gdiplusLib, 'GdiplusStartup');
    Pointer(GdiplusShutdown) := GetProcAddress(gdiplusLib, 'GdiplusShutdown');
    Pointer(GdipCreateFromHDC) := GetProcAddress(gdiplusLib, 'GdipCreateFromHDC');
    Pointer(GdipDeleteGraphics) := GetProcAddress(gdiplusLib, 'GdipDeleteGraphics');
    Pointer(GdipCreatePath) := GetProcAddress(gdiplusLib, 'GdipCreatePath');
    Pointer(GdipDeletePath) := GetProcAddress(gdiplusLib, 'GdipDeletePath');
    Pointer(GdipAddPathLine2I) := GetProcAddress(gdiplusLib, 'GdipAddPathLine2I');
    Pointer(GdipClosePathFigure) := GetProcAddress(gdiplusLib, 'GdipClosePathFigure');
    Pointer(GdipCreatePathGradientFromPath) := GetProcAddress(gdiplusLib, 'GdipCreatePathGradientFromPath');
    Pointer(GdipDeleteBrush) := GetProcAddress(gdiplusLib, 'GdipDeleteBrush');
    Pointer(GdipSetPathGradientCenterColor) := GetProcAddress(gdiplusLib, 'GdipSetPathGradientCenterColor');
    Pointer(GdipSetPathGradientSurroundColorsWithCount) := GetProcAddress(gdiplusLib, 'GdipSetPathGradientSurroundColorsWithCount');
    Pointer(GdipFillPath) := GetProcAddress(gdiplusLib, 'GdipFillPath');

    if (GdiplusStartup = nil) or (GdiplusShutdown = nil) or
       (GdipCreateFromHDC = nil) or (GdipDeleteGraphics = nil) or
       (GdipCreatePath = nil) or (GdipDeletePath = nil) or
       (GdipAddPathLine2I = nil) or (GdipClosePathFigure = nil) or
       (GdipCreatePathGradientFromPath = nil) or (GdipDeleteBrush = nil) or
       (GdipSetPathGradientCenterColor = nil) or
       (GdipSetPathGradientSurroundColorsWithCount = nil) or
       (GdipFillPath = nil) then
    begin
        DebugLog('Failed to get proc addresses');
        Exit;
    end;
    DebugLog('All proc addresses loaded');

    Result := True;
end;

procedure UnloadGdiplus;
begin
    if gdiplusLib <> 0 then
        FreeLibrary(gdiplusLib);
    DebugLog('gdiplus.dll unloaded');
end;

function InitGdiplus: Boolean;
var
    input: GdiplusStartupInput;
    status: GpStatus;
begin
    Result := False;
    FillChar(input, SizeOf(input), 0);
    input.GdiplusVersion := 1;
    status := GdiplusStartup(gdiplusToken, @input, nil);
    DebugLogStatus('GdiplusStartup', status);
    if status = 0 then
    begin
        gdiplusInitialized := True;
        Result := True;
    end;
end;

procedure ShutdownGdiplus;
begin
    if gdiplusInitialized then
    begin
        GdiplusShutdown(gdiplusToken);
        DebugLog('GdiplusShutdown called');
    end;
end;

procedure DrawTriangle(hdc: HDC);
var
    graphics: GpGraphics;
    path: GpPath;
    brush: GpBrush;
    points: array[0..2] of GpPoint;
    colors: array[0..2] of ARGB;
    count: Integer;
    centerColor: ARGB;
    status: GpStatus;
const
    WIDTH = 640;
    HEIGHT = 480;
begin
    DebugLog('DrawTriangle called');

    if not gdiplusInitialized then
    begin
        DebugLog('GDI+ not initialized');
        Exit;
    end;

    graphics := nil;
    path := nil;
    brush := nil;

    // Create Graphics object
    status := GdipCreateFromHDC(hdc, graphics);
    DebugLogStatus('GdipCreateFromHDC', status);
    if (status <> 0) or (graphics = nil) then
        Exit;

    // Define triangle vertices
    points[0].X := WIDTH div 2;
    points[0].Y := HEIGHT div 4;
    points[1].X := (WIDTH * 3) div 4;
    points[1].Y := (HEIGHT * 3) div 4;
    points[2].X := WIDTH div 4;
    points[2].Y := (HEIGHT * 3) div 4;
    DebugLog('Triangle points defined');

    // Create GraphicsPath
    status := GdipCreatePath(FillModeAlternate, path);
    DebugLogStatus('GdipCreatePath', status);
    if (status <> 0) or (path = nil) then
    begin
        GdipDeleteGraphics(graphics);
        Exit;
    end;

    // Add lines to path
    status := GdipAddPathLine2I(path, @points[0], 3);
    DebugLogStatus('GdipAddPathLine2I', status);
    if status <> 0 then
    begin
        GdipDeletePath(path);
        GdipDeleteGraphics(graphics);
        Exit;
    end;

    // Close the path figure
    status := GdipClosePathFigure(path);
    DebugLogStatus('GdipClosePathFigure', status);

    // Create PathGradientBrush
    status := GdipCreatePathGradientFromPath(path, brush);
    DebugLogStatus('GdipCreatePathGradientFromPath', status);
    if (status <> 0) or (brush = nil) then
    begin
        GdipDeletePath(path);
        GdipDeleteGraphics(graphics);
        Exit;
    end;

    // Set center color (RGB 85 = 255/3)
    centerColor := MakeARGB(255, 85, 85, 85);
    status := GdipSetPathGradientCenterColor(brush, centerColor);
    DebugLogStatus('GdipSetPathGradientCenterColor', status);

    // Set surround colors (red, green, blue)
    colors[0] := MakeARGB(255, 255, 0, 0);   // Red
    colors[1] := MakeARGB(255, 0, 255, 0);   // Green
    colors[2] := MakeARGB(255, 0, 0, 255);   // Blue
    count := 3;
    status := GdipSetPathGradientSurroundColorsWithCount(brush, @colors[0], count);
    DebugLogStatus('GdipSetPathGradientSurroundColorsWithCount', status);

    // Fill path
    status := GdipFillPath(graphics, brush, path);
    DebugLogStatus('GdipFillPath', status);

    // Release resources
    GdipDeleteBrush(brush);
    GdipDeletePath(path);
    GdipDeleteGraphics(graphics);
    DebugLog('DrawTriangle finished');
end;

procedure OnPaint(hdc: HDC);
begin
    DrawTriangle(hdc);
end;

function WindowProc(hWindow: HWnd; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
    dc: HDC;
    ps: TPaintStruct;
begin
    Result := 0;
    case Msg of
        WM_PAINT:
            begin
                dc := BeginPaint(hWindow, @ps);
                OnPaint(dc);
                EndPaint(hWindow, @ps);
            end;
        WM_DESTROY:
            PostQuitMessage(0);
    else
        Result := DefWindowProc(hWindow, Msg, wParam, lParam);
    end;
end;

function WinMain(hInstance: THandle): Integer;
var
    wcex: TWndClassEx;
    hWindow: HWnd;
    msg: TMsg;
const
    ClassName = 'helloWindow';
    WindowName = 'Hello, World!';
begin
    Result := 0;
    gdiplusInitialized := False;

    DebugLog('=== Application started ===');

    // Load and initialize GDI+
    if not LoadGdiplus then
    begin
        DebugLog('LoadGdiplus failed');
        Exit;
    end;

    if not InitGdiplus then
    begin
        DebugLog('InitGdiplus failed');
        UnloadGdiplus;
        Exit;
    end;

    FillChar(wcex, SizeOf(wcex), 0);
    wcex.cbSize := SizeOf(TWndclassEx);
    wcex.style := CS_HREDRAW or CS_VREDRAW;
    wcex.lpfnWndProc := @WindowProc;
    wcex.hInstance := hInstance;
    wcex.hIcon := LoadIcon(0, IDI_APPLICATION);
    wcex.hCursor := LoadCursor(0, IDC_ARROW);
    wcex.hbrBackground := COLOR_WINDOW + 1;
    wcex.lpszClassName := ClassName;

    if RegisterClassEx(wcex) = 0 then
    begin
        DebugLog('RegisterClassEx failed');
        ShutdownGdiplus;
        UnloadGdiplus;
        Exit;
    end;

    hWindow := CreateWindowEx(
        0,
        ClassName,
        WindowName,
        WS_OVERLAPPEDWINDOW,
        Integer(CW_USEDEFAULT), Integer(CW_USEDEFAULT), 640, 480,
        0, 0, hInstance, nil
    );

    if hWindow = 0 then
    begin
        DebugLog('CreateWindowEx failed');
        ShutdownGdiplus;
        UnloadGdiplus;
        Exit;
    end;
    DebugLog('Window created');

    ShowWindow(hWindow, SW_SHOWDEFAULT);
    UpdateWindow(hWindow);

    while GetMessage(msg, 0, 0, 0) do
    begin
        TranslateMessage(msg);
        DispatchMessage(msg);
    end;

    // Shutdown and unload GDI+
    ShutdownGdiplus;
    UnloadGdiplus;

    DebugLog('=== Application ended ===');
    Result := msg.wParam;
end;

begin
    WinMain(hInstance);
end.
