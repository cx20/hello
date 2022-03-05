program hello;

uses
    Windows, Messages;

function WindowProc(hWindow:HWnd; message:Cardinal; wParam:Word; lParam:Longint):LongWord; stdcall;
var
    hdc:        THandle;
    ps:         TPaintStruct;
const
    strMessage = 'Hello, Win32 GUI(Pascal) World!';
begin
    case message of
        WM_PAINT:
            begin
                hdc := BeginPaint(hWindow, ps );
                TextOut( hdc, 0, 0, strMessage, Length(strMessage) );
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
const
    ClassName = 'helloWindow';
    WindowName = 'Hello, World!';

begin
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

    WinMain := msg.wParam;
end;

begin
    WinMain( hInstance, 0, nil, cmdShow );
end.
