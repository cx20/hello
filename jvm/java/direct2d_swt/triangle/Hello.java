import org.eclipse.swt.SWT;
import org.eclipse.swt.events.ControlAdapter;
import org.eclipse.swt.events.ControlEvent;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.ptr.PointerByReference;
import com.sun.jna.win32.StdCallLibrary;
import com.sun.jna.win32.W32APIOptions;

import java.util.Arrays;
import java.util.List;
import java.util.UUID;

/**
 * Hello Direct2D (Java + SWT + JNA)
 *
 * Draws a centered triangle similar to typical Direct2D "hello" samples:
 * - White background
 * - Blue thin stroke
 * - Triangle fits within the client area
 *
 * Notes:
 * - Direct2D COM methods here are invoked via vtable indices (see vtable.txt).
 * - Small structs such as D2D1_COLOR_F / D2D1_POINT_2F / D2D1_SIZE_U MUST be
 *   passed by value; otherwise drawing may silently do nothing.
 */
public final class Hello {

    // ----------------------------
    // Debug logging
    // ----------------------------

    public interface Kernel32 extends StdCallLibrary {
        Kernel32 INSTANCE = Native.load("kernel32", Kernel32.class, W32APIOptions.DEFAULT_OPTIONS);
        void OutputDebugStringW(String lpOutputString);
    }

    private static void log(String fmt, Object... args) {
        String msg;
        try {
            msg = (args == null || args.length == 0) ? fmt : String.format(fmt, args);
        } catch (Throwable t) {
            msg = fmt + " (formatting failed: " + t + ")";
        }
        String line = String.format("[HelloD2D][%d] %s\n", Thread.currentThread().getId(), msg);
        System.out.print(line);
        try {
            Kernel32.INSTANCE.OutputDebugStringW(line);
        } catch (Throwable ignored) {
        }
    }

    // ----------------------------
    // Win32 / COM
    // ----------------------------

    private static final int COINIT_APARTMENTTHREADED = 0x2;

    public interface Ole32 extends StdCallLibrary {
        Ole32 INSTANCE = Native.load("ole32", Ole32.class, W32APIOptions.DEFAULT_OPTIONS);
        int CoInitializeEx(Pointer pvReserved, int dwCoInit);
        void CoUninitialize();
    }

    // ----------------------------
    // Direct2D - native API entry
    // ----------------------------

    private static final int D2D1_FACTORY_TYPE_SINGLE_THREADED = 0;
    private static final int D2D1_RENDER_TARGET_TYPE_DEFAULT = 0;
    private static final int DXGI_FORMAT_UNKNOWN = 0;
    private static final int D2D1_ALPHA_MODE_UNKNOWN = 0;
    private static final int D2D1_RENDER_TARGET_USAGE_NONE = 0;
    private static final int D2D1_FEATURE_LEVEL_DEFAULT = 0;
    private static final int D2D1_PRESENT_OPTIONS_NONE = 0;

    public interface D2D1 extends StdCallLibrary {
        D2D1 INSTANCE = Native.load("d2d1", D2D1.class, W32APIOptions.DEFAULT_OPTIONS);
        int D2D1CreateFactory(int factoryType, GUID riid, Pointer pFactoryOptions, PointerByReference ppFactory);
    }

    // ----------------------------
    // Direct2D - structs
    // ----------------------------

    public static final class GUID extends Structure {
        public int Data1;
        public short Data2;
        public short Data3;
        public byte[] Data4 = new byte[8];

        public GUID() {}

        public GUID(UUID uuid) {
            long msb = uuid.getMostSignificantBits();
            long lsb = uuid.getLeastSignificantBits();

            Data1 = (int) (msb >>> 32);
            Data2 = (short) ((msb >>> 16) & 0xFFFF);
            Data3 = (short) (msb & 0xFFFF);
            for (int i = 0; i < 8; i++) {
                Data4[i] = (byte) ((lsb >>> (8 * (7 - i))) & 0xFF);
            }
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("Data1", "Data2", "Data3", "Data4");
        }
    }

    public static class D2D1_COLOR_F extends Structure {
        public float r, g, b, a;

        public D2D1_COLOR_F() {}
        public D2D1_COLOR_F(float r, float g, float b, float a) {
            this.r = r; this.g = g; this.b = b; this.a = a;
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("r", "g", "b", "a");
        }

        public static final class ByValue extends D2D1_COLOR_F implements Structure.ByValue {
            public ByValue() {}
            public ByValue(float r, float g, float b, float a) { super(r, g, b, a); }
        }
    }

    public static class D2D1_POINT_2F extends Structure {
        public float x, y;

        public D2D1_POINT_2F() {}
        public D2D1_POINT_2F(float x, float y) {
            this.x = x; this.y = y;
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("x", "y");
        }

        public static final class ByValue extends D2D1_POINT_2F implements Structure.ByValue {
            public ByValue() {}
            public ByValue(float x, float y) { super(x, y); }
        }
    }

    public static class D2D1_SIZE_U extends Structure {
        public int width;
        public int height;

        public D2D1_SIZE_U() {}
        public D2D1_SIZE_U(int width, int height) {
            this.width = width; this.height = height;
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("width", "height");
        }

        public static final class ByValue extends D2D1_SIZE_U implements Structure.ByValue {
            public ByValue() {}
            public ByValue(int width, int height) { super(width, height); }
        }
    }

    public static final class D2D1_PIXEL_FORMAT extends Structure {
        public int format;
        public int alphaMode;

        public D2D1_PIXEL_FORMAT() {}
        public D2D1_PIXEL_FORMAT(int format, int alphaMode) {
            this.format = format;
            this.alphaMode = alphaMode;
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("format", "alphaMode");
        }
    }

    public static final class D2D1_RENDER_TARGET_PROPERTIES extends Structure {
        public int type;
        public D2D1_PIXEL_FORMAT pixelFormat;
        public float dpiX;
        public float dpiY;
        public int usage;
        public int minLevel;

        public D2D1_RENDER_TARGET_PROPERTIES() {
            this.pixelFormat = new D2D1_PIXEL_FORMAT();
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("type", "pixelFormat", "dpiX", "dpiY", "usage", "minLevel");
        }
    }

    public static final class D2D1_HWND_RENDER_TARGET_PROPERTIES extends Structure {
        public long hwnd;
        public D2D1_SIZE_U pixelSize;
        public int presentOptions;

        public D2D1_HWND_RENDER_TARGET_PROPERTIES() {
            this.pixelSize = new D2D1_SIZE_U();
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("hwnd", "pixelSize", "presentOptions");
        }
    }

    // ----------------------------
    // Direct2D - vtable invocation helpers
    // ----------------------------

    // vtable indices from vtable.txt (your attachment)
    private static final int VTBL_IUNKNOWN_RELEASE = 2;
    private static final int VTBL_ID2D1FACTORY_CREATEHWNDRENDERTARGET = 14;
    private static final int VTBL_ID2D1RENDERTARGET_CREATESOLIDCOLORBRUSH = 8;
    private static final int VTBL_ID2D1RENDERTARGET_DRAWLINE = 15;
    private static final int VTBL_ID2D1RENDERTARGET_CLEAR = 47;
    private static final int VTBL_ID2D1RENDERTARGET_BEGINDRAW = 48;
    private static final int VTBL_ID2D1RENDERTARGET_ENDDRAW = 49;
    private static final int VTBL_ID2D1HWNDRENDERTARGET_RESIZE = 58;

    public interface Fn_CreateHwndRenderTarget extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis, D2D1_RENDER_TARGET_PROPERTIES rtProps, D2D1_HWND_RENDER_TARGET_PROPERTIES hwndProps, PointerByReference ppRenderTarget);
    }

    public interface Fn_CreateSolidColorBrush extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis, D2D1_COLOR_F.ByValue color, Pointer brushPropsNullable, PointerByReference ppBrush);
    }

    public interface Fn_BeginDraw extends StdCallLibrary.StdCallCallback {
        void invoke(Pointer pThis);
    }

    public interface Fn_EndDraw extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis, Pointer tag1Nullable, Pointer tag2Nullable);
    }

    public interface Fn_Clear extends StdCallLibrary.StdCallCallback {
        void invoke(Pointer pThis, D2D1_COLOR_F.ByValue clearColor);
    }

    public interface Fn_DrawLine extends StdCallLibrary.StdCallCallback {
        void invoke(Pointer pThis, D2D1_POINT_2F.ByValue p0, D2D1_POINT_2F.ByValue p1, Pointer brush, float strokeWidth, Pointer strokeStyleNullable);
    }

    public interface Fn_Resize extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis, D2D1_SIZE_U.ByValue size);
    }

    public interface Fn_Release extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis);
    }

    private static Pointer vtbl(Pointer comObj) {
        return comObj.getPointer(0);
    }

    private static Pointer vtblEntry(Pointer comObj, int index) {
        return vtbl(comObj).getPointer((long) index * Native.POINTER_SIZE);
    }

    private static <T extends com.sun.jna.Callback> T fn(Pointer comObj, int index, Class<T> type) {
        Pointer pFn = vtblEntry(comObj, index);
        return type.cast(com.sun.jna.CallbackReference.getCallback(type, pFn));
    }

    private static void safeRelease(Pointer comObj) {
        if (comObj == null || Pointer.nativeValue(comObj) == 0) return;
        Fn_Release rel = fn(comObj, VTBL_IUNKNOWN_RELEASE, Fn_Release.class);
        rel.invoke(comObj);
    }

    private static void checkHR(String what, int hr) {
        if (hr < 0) {
            log("%s -> FAILED hr=0x%08X", what, hr);
            throw new RuntimeException(String.format("%s failed: HRESULT=0x%08X", what, hr));
        }
        log("%s -> OK hr=0x%08X", what, hr);
    }

    // IID_ID2D1Factory = {06152247-6f50-465a-9245-118bfd3b6007}
    private static final GUID IID_ID2D1Factory = new GUID(UUID.fromString("06152247-6f50-465a-9245-118bfd3b6007"));

    // ----------------------------
    // App state
    // ----------------------------

    private static Pointer g_factory;
    private static Pointer g_hwndRenderTarget;
    private static Pointer g_brush;

    private static void initD2D(long hwnd, int width, int height) {
        log("initD2D: enter hwnd=0x%X size=%dx%d", hwnd, width, height);

        PointerByReference ppFactory = new PointerByReference();
        int hr = D2D1.INSTANCE.D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, IID_ID2D1Factory, Pointer.NULL, ppFactory);
        checkHR("D2D1CreateFactory", hr);
        g_factory = ppFactory.getValue();
        log("initD2D: factory=%s", g_factory);

        D2D1_RENDER_TARGET_PROPERTIES rtProps = new D2D1_RENDER_TARGET_PROPERTIES();
        rtProps.type = D2D1_RENDER_TARGET_TYPE_DEFAULT;
        rtProps.pixelFormat = new D2D1_PIXEL_FORMAT(DXGI_FORMAT_UNKNOWN, D2D1_ALPHA_MODE_UNKNOWN);
        rtProps.dpiX = 0.0f;
        rtProps.dpiY = 0.0f;
        rtProps.usage = D2D1_RENDER_TARGET_USAGE_NONE;
        rtProps.minLevel = D2D1_FEATURE_LEVEL_DEFAULT;
        rtProps.write();

        D2D1_HWND_RENDER_TARGET_PROPERTIES hwndProps = new D2D1_HWND_RENDER_TARGET_PROPERTIES();
        hwndProps.hwnd = hwnd;
        hwndProps.pixelSize = new D2D1_SIZE_U(width, height);
        hwndProps.presentOptions = D2D1_PRESENT_OPTIONS_NONE;
        hwndProps.write();

        PointerByReference ppRT = new PointerByReference();
        Fn_CreateHwndRenderTarget createRT = fn(g_factory, VTBL_ID2D1FACTORY_CREATEHWNDRENDERTARGET, Fn_CreateHwndRenderTarget.class);
        hr = createRT.invoke(g_factory, rtProps, hwndProps, ppRT);
        checkHR("ID2D1Factory::CreateHwndRenderTarget", hr);
        g_hwndRenderTarget = ppRT.getValue();
        log("initD2D: hwndRenderTarget=%s", g_hwndRenderTarget);

        // Blue brush (similar to typical samples)
        PointerByReference ppBrush = new PointerByReference();
        Fn_CreateSolidColorBrush createBrush = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_CREATESOLIDCOLORBRUSH, Fn_CreateSolidColorBrush.class);
        D2D1_COLOR_F.ByValue blue = new D2D1_COLOR_F.ByValue(0.0f, 0.0f, 1.0f, 1.0f);
        blue.write();
        hr = createBrush.invoke(g_hwndRenderTarget, blue, Pointer.NULL, ppBrush);
        checkHR("ID2D1RenderTarget::CreateSolidColorBrush", hr);
        g_brush = ppBrush.getValue();
        log("initD2D: brush=%s", g_brush);

        log("initD2D: leave");
    }

    private static void resizeD2D(int width, int height) {
        if (g_hwndRenderTarget == null || Pointer.nativeValue(g_hwndRenderTarget) == 0) return;
        Fn_Resize resize = fn(g_hwndRenderTarget, VTBL_ID2D1HWNDRENDERTARGET_RESIZE, Fn_Resize.class);
        D2D1_SIZE_U.ByValue size = new D2D1_SIZE_U.ByValue(Math.max(1, width), Math.max(1, height));
        size.write();
        int hr = resize.invoke(g_hwndRenderTarget, size);
        checkHR("ID2D1HwndRenderTarget::Resize", hr);
    }

    private static void drawTriangle(int width, int height) {
        if (g_hwndRenderTarget == null || Pointer.nativeValue(g_hwndRenderTarget) == 0) return;

        Fn_BeginDraw beginDraw = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_BEGINDRAW, Fn_BeginDraw.class);
        Fn_Clear clear = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_CLEAR, Fn_Clear.class);
        Fn_DrawLine drawLine = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_DRAWLINE, Fn_DrawLine.class);
        Fn_EndDraw endDraw = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_ENDDRAW, Fn_EndDraw.class);

        beginDraw.invoke(g_hwndRenderTarget);

        // White background (match common hello samples)
        D2D1_COLOR_F.ByValue white = new D2D1_COLOR_F.ByValue(1.0f, 1.0f, 1.0f, 1.0f);
        white.write();
        clear.invoke(g_hwndRenderTarget, white);

        float w = Math.max(1, width);
        float h = Math.max(1, height);

        // A nice centered triangle with margins
        D2D1_POINT_2F.ByValue p0 = new D2D1_POINT_2F.ByValue(w * 0.50f, h * 0.18f);
        D2D1_POINT_2F.ByValue p1 = new D2D1_POINT_2F.ByValue(w * 0.22f, h * 0.78f);
        D2D1_POINT_2F.ByValue p2 = new D2D1_POINT_2F.ByValue(w * 0.78f, h * 0.78f);
        p0.write(); p1.write(); p2.write();

        float stroke = 2.5f;
        drawLine.invoke(g_hwndRenderTarget, p0, p1, g_brush, stroke, Pointer.NULL);
        drawLine.invoke(g_hwndRenderTarget, p1, p2, g_brush, stroke, Pointer.NULL);
        drawLine.invoke(g_hwndRenderTarget, p2, p0, g_brush, stroke, Pointer.NULL);

        int hr = endDraw.invoke(g_hwndRenderTarget, Pointer.NULL, Pointer.NULL);
        checkHR("ID2D1RenderTarget::EndDraw", hr);
    }

    private static void cleanup() {
        safeRelease(g_brush);
        g_brush = null;
        safeRelease(g_hwndRenderTarget);
        g_hwndRenderTarget = null;
        safeRelease(g_factory);
        g_factory = null;
    }

    public static void main(String[] args) {
        log("main: start");

        int hr = Ole32.INSTANCE.CoInitializeEx(Pointer.NULL, COINIT_APARTMENTTHREADED);
        checkHR("CoInitializeEx", hr);

        Display display = new Display();
        Shell shell = new Shell(display);
        shell.setText("Hello, Direct2D(Java) World!");
        shell.setSize(800, 600);

        shell.addListener(SWT.Dispose, e -> {
            cleanup();
            Ole32.INSTANCE.CoUninitialize();
        });

        shell.open();

        long hwnd = shell.handle;
        log("main: SWT shell hwnd=0x%X", hwnd);
        initD2D(hwnd, shell.getClientArea().width, shell.getClientArea().height);

        shell.addControlListener(new ControlAdapter() {
            @Override
            public void controlResized(ControlEvent e) {
                int w = shell.getClientArea().width;
                int h = shell.getClientArea().height;
                resizeD2D(w, h);
                shell.redraw();
            }
        });

        shell.addListener(SWT.Paint, e -> {
            int w = shell.getClientArea().width;
            int h = shell.getClientArea().height;
            drawTriangle(w, h);
        });

        shell.redraw();

        while (!shell.isDisposed()) {
            if (!display.readAndDispatch()) {
                display.sleep();
            }
        }
        display.dispose();
        log("main: loop exited");
    }
}
