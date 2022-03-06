program hello;

uses
    Windows, Messages;

type
    COLOR16 = USHORT;
  
    PTriVertex = ^TTriVertex;
    _TRIVERTEX = record
        x: LONG;
        y: LONG;
        Red: COLOR16;
        Green: COLOR16;
        Blue: COLOR16;
        Alpha: COLOR16;
    end;
    TRIVERTEX   = _TRIVERTEX;
    LPTRIVERTEX = ^TRIVERTEX;
    TTriVertex  = _TRIVERTEX;
  
    PGradientTriangle = ^TGradientTriangle;
    _GRADIENT_TRIANGLE = record
        Vertex1: ULONG;
        Vertex2: ULONG;
        Vertex3: ULONG;
    end;
    GRADIENT_TRIANGLE   = _GRADIENT_TRIANGLE;
    LPGRADIENT_TRIANGLE = ^GRADIENT_TRIANGLE;
    PGRADIENT_TRIANGLE  = ^GRADIENT_TRIANGLE;
    TGradientTriangle   = _GRADIENT_TRIANGLE;
  
    TGradientFill = function(hdc: HDC; pVertex: PTRIVERTEX; dwNumVertex: ULONG; pMesh: PVOID; dwNumMesh, dwMode: ULONG): BOOL; stdcall;

var
    GradientFill: TGradientFill;

const
    GRADIENT_FILL_TRIANGLE = $00000002;

procedure DrawTriangle(hdc: HDC);
var
    vertex: array [0..2] of TRIVERTEX;
    gTriangle: GRADIENT_TRIANGLE;
const
    WIDTH  = 640;
    HEIGHT = 480;

begin
    vertex[0].x     := Round(WIDTH  * 1 / 2);
    vertex[0].y     := Round(HEIGHT * 1 / 4);
    vertex[0].Red   := $ffff;
    vertex[0].Green := $0000;
    vertex[0].Blue  := $0000;
    vertex[0].Alpha := $0000;

    vertex[1].x     := Round(WIDTH  * 3 / 4);
    vertex[1].y     := Round(HEIGHT * 3 / 4);
    vertex[1].Red   := $0000;
    vertex[1].Green := $ffff;
    vertex[1].Blue  := $0000;
    vertex[1].Alpha := $0000;

    vertex[2].x     := Round(WIDTH  * 1 / 4);
    vertex[2].y     := Round(HEIGHT * 3 / 4);
    vertex[2].Red   := $0000;
    vertex[2].Green := $0000;
    vertex[2].Blue  := $ffff;
    vertex[2].Alpha := $0000;
    
    gTriangle.Vertex1 := 0;
    gTriangle.Vertex2 := 1;
    gTriangle.Vertex3 := 2;

    GradientFill(hdc, vertex, 3, @gTriangle, 1, GRADIENT_FILL_TRIANGLE);
end;

procedure OnPaint(hdc: HDC);
begin
    DrawTriangle(hdc);
end;

function WindowProc(hWindow:HWnd; message:Cardinal; wParam:Word; lParam:Longint):LongWord; stdcall;
var
    hdc:        THandle;
    ps:         TPaintStruct;
begin
    case message of
        WM_PAINT:
            begin
                hdc := BeginPaint(hWindow, ps );
                OnPaint(hdc);
                EndPaint( hWindow, ps );
            end;

        WM_DESTROY:
            PostQuitMessage(0);
    else
        WindowProc := DefWindowProc(hWindow, message, wParam, lParam);
        exit;
    end;
    WindowProc := 0;
end;

function WinMain(hInstance, hPrevInstance:THandle; lpCmdLine:PAnsiChar; nCmdShow:Integer):Integer; stdcall;
var
    wcex:       TWndClassEx;
    hWindow:    HWnd;
    msg:        TMsg;
    LibHandle : THandle;
const
    ClassName = 'helloWindow';
    WindowName = 'Hello, World!';

begin
    LibHandle := LoadLibrary(PChar('msimg32.dll'));
    Pointer(GradientFill) := GetProcAddress(LibHandle, 'GradientFill');

    wcex.cbSize         := SizeOf(TWndclassEx);
    wcex.style          := CS_HREDRAW or CS_VREDRAW;
    wcex.lpfnWndProc    := WndProc(@WindowProc);
    wcex.cbClsExtra     := 0;
    wcex.cbWndExtra     := 0;
    wcex.hInstance      := hInstance;
    wcex.hIcon          := LoadIcon(0, IDI_APPLICATION);
    wcex.hCursor        := LoadCursor(0, IDC_ARROW);
    wcex.hbrBackground  := COLOR_WINDOW +1;
    wcex.lpszMenuName   := nil;
    wcex.lpszClassName  := ClassName;

    RegisterClassEx(wcex);
    hWindow := CreateWindowEX(
        0,
        ClassName,
        WindowName,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
        0, 0, hInstance, nil
    );

    ShowWindow(hWindow, SW_SHOWDEFAULT);
    UpdateWindow(hWindow);

    while GetMessage(msg, 0, 0, 0) do begin
        TranslateMessage(msg);
        DispatchMessage(msg);
    end;
    
    GradientFill := nil;
    FreeLibrary(LibHandle);

    WinMain := msg.wParam;
end;

begin
    WinMain( hInstance, 0, nil, cmdShow );
end.
