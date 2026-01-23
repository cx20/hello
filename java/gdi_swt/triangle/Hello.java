import org.eclipse.swt.internal.Callback;
import org.eclipse.swt.internal.win32.OS;
import org.eclipse.swt.internal.win32.WNDCLASS;
import org.eclipse.swt.internal.win32.PAINTSTRUCT;
import org.eclipse.swt.internal.win32.MSG;

import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.win32.StdCallLibrary;

import java.util.Arrays;
import java.util.List;

public class Hello {
    static final int CS_OWNDC = 0x0020;
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int CW_USEDEFAULT = 0x80000000;
    static final int SW_SHOWDEFAULT = 10;
    static final int WM_CLOSE = 0x0010;
    static final int WM_DESTROY = 0x0002;
    static final int WM_PAINT = 0x000F;
    static final int WM_QUIT = 0x0012;
    static final int PM_REMOVE = 0x0001;
    static final int BLACK_BRUSH = 4;
    static final int IDI_APPLICATION = 32512;
    static final int IDC_ARROW = 32512;
    static final int GRADIENT_FILL_TRIANGLE = 2;

    static final int WIDTH = 640;
    static final int HEIGHT = 480;

    static Callback wndProcCallback;

    public interface Msimg32 extends StdCallLibrary {
        Msimg32 INSTANCE = Native.load("msimg32", Msimg32.class);
        
        boolean GradientFill(
            Pointer hdc,
            TRIVERTEX[] pVertex,
            int nVertex,
            GRADIENT_TRIANGLE[] pMesh,
            int nMesh,
            int ulMode
        );
    }

    public static class TRIVERTEX extends Structure {
        public int x;
        public int y;
        public short Red;
        public short Green;
        public short Blue;
        public short Alpha;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("x", "y", "Red", "Green", "Blue", "Alpha");
        }
    }

    public static class GRADIENT_TRIANGLE extends Structure {
        public int Vertex1;
        public int Vertex2;
        public int Vertex3;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("Vertex1", "Vertex2", "Vertex3");
        }
    }

    public static void main(String[] args) {
        long hInstance = OS.GetModuleHandle(null);
        
        wndProcCallback = new Callback(Hello.class, "WndProc", 4);
        long wndProcAddress = wndProcCallback.getAddress();
        
        char[] className = "HelloClass\0".toCharArray();
        
        WNDCLASS wc = new WNDCLASS();
        wc.style = CS_OWNDC;
        wc.lpfnWndProc = wndProcAddress;
        wc.hInstance = hInstance;
        wc.hIcon = OS.LoadIcon(0, IDI_APPLICATION);
        wc.hCursor = OS.LoadCursor(0, IDC_ARROW);
        wc.hbrBackground = OS.GetStockObject(BLACK_BRUSH);
        wc.lpszClassName = OS.HeapAlloc(OS.GetProcessHeap(), OS.HEAP_ZERO_MEMORY, className.length * 2);
        OS.MoveMemory(wc.lpszClassName, className, className.length * 2);
        
        OS.RegisterClass(wc);
        
        char[] windowName = "Hello, World!\0".toCharArray();
        long hWnd = OS.CreateWindowEx(
            0,
            className,
            windowName,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            WIDTH, HEIGHT,
            0, 0, hInstance, null
        );
        
        OS.ShowWindow(hWnd, SW_SHOWDEFAULT);
        
        MSG msg = new MSG();
        boolean bQuit = false;
        while (!bQuit) {
            if (OS.PeekMessage(msg, 0, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) {
                    bQuit = true;
                } else {
                    OS.TranslateMessage(msg);
                    OS.DispatchMessage(msg);
                }
            }
        }
        
        OS.DestroyWindow(hWnd);
        
        wndProcCallback.dispose();
        OS.HeapFree(OS.GetProcessHeap(), 0, wc.lpszClassName);
    }
    
    static long WndProc(long hWnd, long uMsg, long wParam, long lParam) {
        switch ((int) uMsg) {
            case WM_CLOSE:
                OS.PostMessage(hWnd, WM_QUIT, 0, 0);
                return 0;
            case WM_DESTROY:
                return 0;
            case WM_PAINT: {
                PAINTSTRUCT ps = new PAINTSTRUCT();
                long hdc = OS.BeginPaint(hWnd, ps);
                drawTriangle(hdc);
                OS.EndPaint(hWnd, ps);
                return 0;
            }
            default:
                return OS.DefWindowProc(hWnd, (int) uMsg, wParam, lParam);
        }
    }
    
/*
    static void drawTriangle(long hdc) {
        TRIVERTEX[] vertex = new TRIVERTEX[3];
        
        // Vertex 0: red
        vertex[0] = new TRIVERTEX();
        vertex[0].x = WIDTH / 2;
        vertex[0].y = HEIGHT / 4;
        vertex[0].Red = (short) 0xFFFF;
        vertex[0].Green = 0;
        vertex[0].Blue = 0;
        vertex[0].Alpha = 0;
        
        // Vertex 1: green
        vertex[1] = new TRIVERTEX();
        vertex[1].x = WIDTH * 3 / 4;
        vertex[1].y = HEIGHT * 3 / 4;
        vertex[1].Red = 0;
        vertex[1].Green = (short) 0xFFFF;
        vertex[1].Blue = 0;
        vertex[1].Alpha = 0;
        
        // Vertex 2: blue
        vertex[2] = new TRIVERTEX();
        vertex[2].x = WIDTH / 4;
        vertex[2].y = HEIGHT * 3 / 4;
        vertex[2].Red = 0;
        vertex[2].Green = 0;
        vertex[2].Blue = (short) 0xFFFF;
        vertex[2].Alpha = 0;
        
        GRADIENT_TRIANGLE[] mesh = new GRADIENT_TRIANGLE[1];
        mesh[0] = new GRADIENT_TRIANGLE();
        mesh[0].Vertex1 = 0;
        mesh[0].Vertex2 = 1;
        mesh[0].Vertex3 = 2;
        
        Pointer hdcPtr = new Pointer(hdc);
        boolean result = Msimg32.INSTANCE.GradientFill(
            hdcPtr,
            vertex,
            3,
            mesh,
            1,
            GRADIENT_FILL_TRIANGLE
        );
        
        System.out.println("GradientFill result: " + result);
    }
*/
    static void drawTriangle(long hdc) {
        TRIVERTEX[] vertex = (TRIVERTEX[]) new TRIVERTEX().toArray(3);
        
        // Vertex 0: red
        vertex[0].x = WIDTH / 2;
        vertex[0].y = HEIGHT / 4;
        vertex[0].Red = (short) 0xFFFF;
        vertex[0].Green = 0;
        vertex[0].Blue = 0;
        vertex[0].Alpha = 0;
        
        // Vertex 1: green
        vertex[1].x = WIDTH * 3 / 4;
        vertex[1].y = HEIGHT * 3 / 4;
        vertex[1].Red = 0;
        vertex[1].Green = (short) 0xFFFF;
        vertex[1].Blue = 0;
        vertex[1].Alpha = 0;
        
        // Vertex 2: blue
        vertex[2].x = WIDTH / 4;
        vertex[2].y = HEIGHT * 3 / 4;
        vertex[2].Red = 0;
        vertex[2].Green = 0;
        vertex[2].Blue = (short) 0xFFFF;
        vertex[2].Alpha = 0;
        
        GRADIENT_TRIANGLE[] mesh = (GRADIENT_TRIANGLE[]) new GRADIENT_TRIANGLE().toArray(1);
        mesh[0].Vertex1 = 0;
        mesh[0].Vertex2 = 1;
        mesh[0].Vertex3 = 2;
        
        Pointer hdcPtr = new Pointer(hdc);
        boolean result = Msimg32.INSTANCE.GradientFill(
            hdcPtr,
            vertex,
            3,
            mesh,
            1,
            GRADIENT_FILL_TRIANGLE
        );
        
        System.out.println("GradientFill result: " + result);
    }
}
