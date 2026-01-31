program hello;

{$mode delphi}

uses
  Windows, SysUtils;

// ===========================================
// Direct2D Types and Constants
// ===========================================
type
  D2D1_FACTORY_TYPE = Cardinal;
  D2D1_RENDER_TARGET_TYPE = Cardinal;
  D2D1_ALPHA_MODE = Cardinal;
  D2D1_RENDER_TARGET_USAGE = Cardinal;
  D2D1_FEATURE_LEVEL = Cardinal;
  D2D1_PRESENT_OPTIONS = Cardinal;
  DXGI_FORMAT = Cardinal;

const
  D2D1_FACTORY_TYPE_SINGLE_THREADED = 0;
  D2D1_RENDER_TARGET_TYPE_DEFAULT = 0;
  D2D1_ALPHA_MODE_UNKNOWN = 0;
  D2D1_RENDER_TARGET_USAGE_NONE = 0;
  D2D1_FEATURE_LEVEL_DEFAULT = 0;
  D2D1_PRESENT_OPTIONS_NONE = 0;
  DXGI_FORMAT_UNKNOWN = 0;

  // VTable indices (from vtable.txt)
  // IUnknown
  IUnknown_Release = 2;

  // ID2D1Factory
  ID2D1Factory_CreateHwndRenderTarget = 14;

  // ID2D1RenderTarget
  ID2D1RenderTarget_CreateSolidColorBrush = 8;
  ID2D1RenderTarget_DrawLine = 15;
  ID2D1RenderTarget_Clear = 47;
  ID2D1RenderTarget_BeginDraw = 48;
  ID2D1RenderTarget_EndDraw = 49;

  // ID2D1HwndRenderTarget
  ID2D1HwndRenderTarget_Resize = 58;

type
  // Direct2D Structures
  D2D1_COLOR_F = record
    r, g, b, a: Single;
  end;

  D2D1_POINT_2F = record
    x, y: Single;
  end;

  D2D1_SIZE_U = record
    width, height: Cardinal;
  end;

  D2D1_PIXEL_FORMAT = record
    format: DXGI_FORMAT;
    alphaMode: D2D1_ALPHA_MODE;
  end;

  D2D1_RENDER_TARGET_PROPERTIES = record
    _type: D2D1_RENDER_TARGET_TYPE;
    pixelFormat: D2D1_PIXEL_FORMAT;
    dpiX: Single;
    dpiY: Single;
    usage: D2D1_RENDER_TARGET_USAGE;
    minLevel: D2D1_FEATURE_LEVEL;
  end;

  D2D1_HWND_RENDER_TARGET_PROPERTIES = record
    hwnd: HWND;
    pixelSize: D2D1_SIZE_U;
    presentOptions: D2D1_PRESENT_OPTIONS;
  end;

  // COM Interface structures (VTable style)
  PPointer = ^Pointer;

  // ID2D1Factory VTable
  ID2D1FactoryVtbl = record
    // IUnknown (0-2)
    QueryInterface: Pointer;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID2D1Factory (3-14+)
    ReloadSystemMetrics: Pointer;          // 3
    GetDesktopDpi: Pointer;                // 4
    CreateRectangleGeometry: Pointer;      // 5
    CreateRoundedRectangleGeometry: Pointer; // 6
    CreateEllipseGeometry: Pointer;        // 7
    CreateGeometryGroup: Pointer;          // 8
    CreateTransformedGeometry: Pointer;    // 9
    CreatePathGeometry: Pointer;           // 10
    CreateStrokeStyle: Pointer;            // 11
    CreateDrawingStateBlock: Pointer;      // 12
    CreateWicBitmapRenderTarget: Pointer;  // 13
    CreateHwndRenderTarget: function(Self: Pointer;
      const renderTargetProperties: D2D1_RENDER_TARGET_PROPERTIES;
      const hwndRenderTargetProperties: D2D1_HWND_RENDER_TARGET_PROPERTIES;
      out hwndRenderTarget: Pointer): HRESULT; stdcall; // 14
  end;
  PID2D1FactoryVtbl = ^ID2D1FactoryVtbl;

  ID2D1Factory = record
    lpVtbl: PID2D1FactoryVtbl;
  end;
  PID2D1Factory = ^ID2D1Factory;

  // ID2D1RenderTarget VTable
  ID2D1RenderTargetVtbl = record
    // IUnknown (0-2)
    QueryInterface: Pointer;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID2D1Resource (3)
    GetFactory: Pointer;
    // ID2D1RenderTarget (4-56)
    CreateBitmap: Pointer;                    // 4
    CreateBitmapFromWicBitmap: Pointer;       // 5
    CreateSharedBitmap: Pointer;              // 6
    CreateBitmapBrush: Pointer;               // 7
    CreateSolidColorBrush: function(Self: Pointer;
      const color: D2D1_COLOR_F;
      brushProperties: Pointer;
      out solidColorBrush: Pointer): HRESULT; stdcall; // 8
    CreateGradientStopCollection: Pointer;    // 9
    CreateLinearGradientBrush: Pointer;       // 10
    CreateRadialGradientBrush: Pointer;       // 11
    CreateCompatibleRenderTarget: Pointer;    // 12
    CreateLayer: Pointer;                     // 13
    CreateMesh: Pointer;                      // 14
    DrawLine: procedure(Self: Pointer;
      point0: D2D1_POINT_2F;
      point1: D2D1_POINT_2F;
      brush: Pointer;
      strokeWidth: Single;
      strokeStyle: Pointer); stdcall;         // 15
    DrawRectangle: Pointer;                   // 16
    FillRectangle: Pointer;                   // 17
    DrawRoundedRectangle: Pointer;            // 18
    FillRoundedRectangle: Pointer;            // 19
    DrawEllipse: Pointer;                     // 20
    FillEllipse: Pointer;                     // 21
    DrawGeometry: Pointer;                    // 22
    FillGeometry: Pointer;                    // 23
    FillMesh: Pointer;                        // 24
    FillOpacityMask: Pointer;                 // 25
    DrawBitmap: Pointer;                      // 26
    DrawText: Pointer;                        // 27
    DrawTextLayout: Pointer;                  // 28
    DrawGlyphRun: Pointer;                    // 29
    SetTransform: Pointer;                    // 30
    GetTransform: Pointer;                    // 31
    SetAntialiasMode: Pointer;                // 32
    GetAntialiasMode: Pointer;                // 33
    SetTextAntialiasMode: Pointer;            // 34
    GetTextAntialiasMode: Pointer;            // 35
    SetTextRenderingParams: Pointer;          // 36
    GetTextRenderingParams: Pointer;          // 37
    SetTags: Pointer;                         // 38
    GetTags: Pointer;                         // 39
    PushLayer: Pointer;                       // 40
    PopLayer: Pointer;                        // 41
    Flush: Pointer;                           // 42
    SaveDrawingState: Pointer;                // 43
    RestoreDrawingState: Pointer;             // 44
    PushAxisAlignedClip: Pointer;             // 45
    PopAxisAlignedClip: Pointer;              // 46
    Clear: procedure(Self: Pointer; const clearColor: D2D1_COLOR_F); stdcall; // 47
    BeginDraw: procedure(Self: Pointer); stdcall; // 48
    EndDraw: function(Self: Pointer; tag1, tag2: Pointer): HRESULT; stdcall; // 49
    GetPixelFormat: Pointer;                  // 50
    SetDpi: Pointer;                          // 51
    GetDpi: Pointer;                          // 52
    GetSize: Pointer;                         // 53
    GetPixelSize: Pointer;                    // 54
    GetMaximumBitmapSize: Pointer;            // 55
    IsSupported: Pointer;                     // 56
    // ID2D1HwndRenderTarget (57-59)
    CheckWindowState: Pointer;                // 57
    Resize: function(Self: Pointer; const pixelSize: D2D1_SIZE_U): HRESULT; stdcall; // 58
    GetHwnd: Pointer;                         // 59
  end;
  PID2D1RenderTargetVtbl = ^ID2D1RenderTargetVtbl;

  ID2D1RenderTarget = record
    lpVtbl: PID2D1RenderTargetVtbl;
  end;
  PID2D1RenderTarget = ^ID2D1RenderTarget;

  // ID2D1Brush VTable (for Release)
  ID2D1BrushVtbl = record
    QueryInterface: Pointer;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
  end;
  PID2D1BrushVtbl = ^ID2D1BrushVtbl;

  ID2D1Brush = record
    lpVtbl: PID2D1BrushVtbl;
  end;
  PID2D1Brush = ^ID2D1Brush;

// ===========================================
// External function declarations
// ===========================================
function D2D1CreateFactory(
  factoryType: D2D1_FACTORY_TYPE;
  const riid: TGUID;
  pFactoryOptions: Pointer;
  out ppIFactory: PID2D1Factory
): HRESULT; stdcall; external 'd2d1.dll';

// ===========================================
// Global variables
// ===========================================
var
  g_hWnd: HWND = 0;
  g_pFactory: PID2D1Factory = nil;
  g_pRenderTarget: PID2D1RenderTarget = nil;
  g_pBrush: PID2D1Brush = nil;

const
  IID_ID2D1Factory: TGUID = '{06152247-6f50-465a-9245-118bfd3b6007}';

// ===========================================
// Initialize Direct2D
// ===========================================
function InitDirect2D: HRESULT;
var
  rc: TRect;
  rtProps: D2D1_RENDER_TARGET_PROPERTIES;
  hwndProps: D2D1_HWND_RENDER_TARGET_PROPERTIES;
  blue: D2D1_COLOR_F;
begin
  // Create factory
  Result := D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED,
    IID_ID2D1Factory, nil, g_pFactory);
  if Failed(Result) then Exit;

  // Get client rect
  GetClientRect(g_hWnd, rc);

  // Setup render target properties
  ZeroMemory(@rtProps, SizeOf(rtProps));
  rtProps._type := D2D1_RENDER_TARGET_TYPE_DEFAULT;
  rtProps.pixelFormat.format := DXGI_FORMAT_UNKNOWN;
  rtProps.pixelFormat.alphaMode := D2D1_ALPHA_MODE_UNKNOWN;

  // Setup hwnd render target properties
  ZeroMemory(@hwndProps, SizeOf(hwndProps));
  hwndProps.hwnd := g_hWnd;
  hwndProps.pixelSize.width := rc.Right - rc.Left;
  hwndProps.pixelSize.height := rc.Bottom - rc.Top;
  hwndProps.presentOptions := D2D1_PRESENT_OPTIONS_NONE;

  // Create HwndRenderTarget
  Result := g_pFactory^.lpVtbl^.CreateHwndRenderTarget(g_pFactory,
    rtProps, hwndProps, Pointer(g_pRenderTarget));
  if Failed(Result) then Exit;

  // Create SolidColorBrush (blue)
  blue.r := 0.0;
  blue.g := 0.0;
  blue.b := 1.0;
  blue.a := 1.0;
  Result := g_pRenderTarget^.lpVtbl^.CreateSolidColorBrush(g_pRenderTarget,
    blue, nil, Pointer(g_pBrush));
end;

// ===========================================
// Cleanup
// ===========================================
procedure Cleanup;
begin
  if g_pBrush <> nil then
  begin
    g_pBrush^.lpVtbl^.Release(g_pBrush);
    g_pBrush := nil;
  end;
  if g_pRenderTarget <> nil then
  begin
    g_pRenderTarget^.lpVtbl^.Release(g_pRenderTarget);
    g_pRenderTarget := nil;
  end;
  if g_pFactory <> nil then
  begin
    g_pFactory^.lpVtbl^.Release(g_pFactory);
    g_pFactory := nil;
  end;
end;

// ===========================================
// Render
// ===========================================
procedure Render;
var
  white: D2D1_COLOR_F;
  p1, p2, p3: D2D1_POINT_2F;
begin
  if (g_pRenderTarget = nil) or (g_pBrush = nil) then Exit;

  // BeginDraw
  g_pRenderTarget^.lpVtbl^.BeginDraw(g_pRenderTarget);

  // Clear (white)
  white.r := 1.0;
  white.g := 1.0;
  white.b := 1.0;
  white.a := 1.0;
  g_pRenderTarget^.lpVtbl^.Clear(g_pRenderTarget, white);

  // Triangle vertices
  p1.x := 320; p1.y := 120;
  p2.x := 480; p2.y := 360;
  p3.x := 160; p3.y := 360;

  // DrawLine - triangle edges
  g_pRenderTarget^.lpVtbl^.DrawLine(g_pRenderTarget, p1, p2, g_pBrush, 2.0, nil);
  g_pRenderTarget^.lpVtbl^.DrawLine(g_pRenderTarget, p2, p3, g_pBrush, 2.0, nil);
  g_pRenderTarget^.lpVtbl^.DrawLine(g_pRenderTarget, p3, p1, g_pBrush, 2.0, nil);

  // EndDraw
  g_pRenderTarget^.lpVtbl^.EndDraw(g_pRenderTarget, nil, nil);
end;

// ===========================================
// Window Procedure
// ===========================================
function WndProc(hWnd: HWND; message: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  size: D2D1_SIZE_U;
begin
  case message of
    WM_PAINT:
      begin
        Render;
        ValidateRect(hWnd, nil);
        Result := 0;
      end;

    WM_SIZE:
      begin
        if g_pRenderTarget <> nil then
        begin
          size.width := lParam and $FFFF;
          size.height := (lParam shr 16) and $FFFF;
          g_pRenderTarget^.lpVtbl^.Resize(g_pRenderTarget, size);
        end;
        Result := 0;
      end;

    WM_DESTROY:
      begin
        PostQuitMessage(0);
        Result := 0;
      end;

  else
    Result := DefWindowProc(hWnd, message, wParam, lParam);
  end;
end;

// ===========================================
// Initialize Window
// ===========================================
function InitWindow(hInstance: HINST; nCmdShow: Integer): Boolean;
var
  wcex: WNDCLASSEX;
begin
  ZeroMemory(@wcex, SizeOf(wcex));
  wcex.cbSize := SizeOf(WNDCLASSEX);
  wcex.style := CS_HREDRAW or CS_VREDRAW;
  wcex.lpfnWndProc := @WndProc;
  wcex.hInstance := hInstance;
  wcex.hCursor := LoadCursor(0, IDC_ARROW);
  wcex.hbrBackground := COLOR_WINDOW + 1;
  wcex.lpszClassName := 'HelloD2DClass';

  if RegisterClassEx(wcex) = 0 then
  begin
    Result := False;
    Exit;
  end;

  g_hWnd := CreateWindow('HelloD2DClass', 'Hello, Direct2D(Pascal) World!',
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
    0, 0, hInstance, nil);

  if g_hWnd = 0 then
  begin
    Result := False;
    Exit;
  end;

  ShowWindow(g_hWnd, nCmdShow);
  UpdateWindow(g_hWnd);
  Result := True;
end;

// ===========================================
// Main
// ===========================================
var
  msg: TMsg;
begin
  if not InitWindow(hInstance, CmdShow) then
  begin
    MessageBox(0, 'InitWindow failed', 'Error', MB_OK);
    Halt(1);
  end;

  if Failed(InitDirect2D) then
  begin
    MessageBox(0, 'InitDirect2D failed', 'Error', MB_OK);
    Cleanup;
    Halt(1);
  end;

  // Force initial paint after Direct2D is ready
  InvalidateRect(g_hWnd, nil, True);

  ZeroMemory(@msg, SizeOf(msg));
  while GetMessage(msg, 0, 0, 0) do
  begin
    TranslateMessage(msg);
    DispatchMessage(msg);
  end;

  Cleanup;
end.
