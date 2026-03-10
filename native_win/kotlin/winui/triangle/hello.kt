@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

private const val S_OK = 0
private const val S_FALSE = 1
private const val RPC_E_CHANGED_MODE = -2147417850
private const val COINIT_APARTMENTTHREADED = 0x2u
private const val RO_INIT_SINGLETHREADED = 0u
private const val HSTRING_HEADER_SIZE = 40
private const val WINDOW_TITLE = "Hello, World!"
private const val WINDOW_CLASS = "HelloWinUI3KotlinWindow"
private const val WIN_X64 = "win-x64"

private typealias ComPtr = COpaquePointer?

private var gDesktopWindowXamlSource: ComPtr = null
private var gDesktopWindowXamlSourceInspectable: ComPtr = null
private var gWindowsXamlManager: ComPtr = null
private var gDispatcherQueueController: ComPtr = null

private fun logState(functionName: String, message: String) {
    OutputDebugStringA("[$functionName] $message\n")
}

private fun fail(message: String): Nothing = throw RuntimeException(message)

private fun hrHex(hr: Int): String = "0x${hr.toUInt().toString(16).padStart(8, '0')}"

private fun checkHr(functionName: String, label: String, hr: Int) {
    logState(functionName, "$label hr=${hrHex(hr)}")
    if (hr < 0) fail("$label failed: ${hrHex(hr)}")
}

private fun CPointer<UShortVar>.toKStringUtf16(): String {
    val chars = mutableListOf<Char>()
    var index = 0
    while (true) {
        val value = this[index]
        if (value.toInt() == 0) break
        chars += value.toInt().toChar()
        index++
    }
    return chars.joinToString("")
}

private fun fileExists(path: String): Boolean = GetFileAttributesW(path) != INVALID_FILE_ATTRIBUTES

private fun listSubdirectories(path: String): List<String> = memScoped {
    val result = mutableListOf<String>()
    val findData = alloc<WIN32_FIND_DATAW>()
    val searchPattern = "$path\\*"
    val handle = FindFirstFileW(searchPattern, findData.ptr)
    if (handle == INVALID_HANDLE_VALUE) return@memScoped result

    try {
        do {
            val name = findData.cFileName.toKStringUtf16()
            if (name != "." && name != ".." && (findData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY.toUInt()) != 0u) {
                result += name
            }
        } while (FindNextFileW(handle, findData.ptr) != 0)
    } finally {
        FindClose(handle)
    }

    result
}

private fun currentArchFolder(): String = WIN_X64

private data class BootstrapPackage(
    val root: String,
    val packageVersion: String,
    val majorMinor: UInt,
    val minVersion: ULong
)

private fun parseMajorMinor(version: String): UInt {
    val parts = version.split('.')
    if (parts.size < 2) fail("Invalid package version: $version")
    val major = parts[0].toUInt()
    val minor = parts[1].toUInt()
    return (major shl 16) or minor
}

private fun resolvePackageWithHeader(packageNames: List<String>): BootstrapPackage {
    val functionName = "resolvePackageWithHeader"
    logState(functionName, "begin")
    val nugetBase = getEnvironmentVariable("NUGET_PACKAGES")
        ?: "${getEnvironmentVariable("USERPROFILE") ?: fail("USERPROFILE was not set")}\\.nuget\\packages"
    logState(functionName, "base=$nugetBase")

    val candidates = mutableListOf<Pair<String, String>>()
    for (packageName in packageNames) {
        val packageDir = "$nugetBase\\$packageName"
        logState(functionName, "scan package dir=$packageDir")
        for (version in listSubdirectories(packageDir)) {
            val root = "$packageDir\\$version"
            if (fileExists("$root\\include\\MddBootstrap.h")) {
                candidates += version to root
            }
        }
    }

    val selected = candidates.maxByOrNull { it.first }
        ?: fail("Windows App SDK package was not found")
    val packageVersion = selected.first
    val root = selected.second
    val majorMinor = parseMajorMinor(packageVersion)
    logState(
        functionName,
        "selected=$root packageVersion=$packageVersion majorMinor=0x${majorMinor.toString(16).padStart(8, '0')}"
    )
    return BootstrapPackage(root, packageVersion, majorMinor, 0u)
}

private fun resolvePackageContainingFile(packageNames: List<String>, fileName: String): String {
    val functionName = "resolvePackageContainingFile"
    logState(functionName, "begin fileName=$fileName")
    val nugetBase = getEnvironmentVariable("NUGET_PACKAGES")
        ?: "${getEnvironmentVariable("USERPROFILE") ?: fail("USERPROFILE was not set")}\\.nuget\\packages"
    val arch = currentArchFolder()

    val candidates = mutableListOf<Pair<String, String>>()
    for (packageName in packageNames) {
        val packageDir = "$nugetBase\\$packageName"
        logState(functionName, "scan package dir=$packageDir")
        for (version in listSubdirectories(packageDir)) {
            val root = "$packageDir\\$version"
            val direct = "$root\\runtimes\\$arch\\native\\$fileName"
            val framework = "$root\\runtimes-framework\\$arch\\native\\$fileName"
            if (fileExists(direct) || fileExists(framework)) {
                candidates += version to root
            }
        }
    }

    val selected = candidates.maxByOrNull { it.first }
        ?: fail("No package contained $fileName")
    logState(functionName, "selected=${selected.second}")
    return selected.second
}

private fun resolveRuntimeDll(fileName: String): String {
    val functionName = "resolveRuntimeDll"
    logState(functionName, "begin fileName=$fileName")
    val packageRoot = if (fileName == "Microsoft.Internal.FrameworkUdk.dll") {
        resolvePackageContainingFile(
            listOf("microsoft.windowsappsdk.interactiveexperiences"),
            fileName
        )
    } else {
        resolvePackageWithHeader(listOf("microsoft.windowsappsdk", "microsoft.windowsappsdk.foundation")).root
    }
    val arch = currentArchFolder()
    val direct = "$packageRoot\\runtimes\\$arch\\native\\$fileName"
    if (fileExists(direct)) {
        logState(functionName, "resolved direct path=$direct")
        return direct
    }
    val framework = "$packageRoot\\runtimes-framework\\$arch\\native\\$fileName"
    if (fileExists(framework)) {
        logState(functionName, "resolved framework path=$framework")
        return framework
    }
    val fallback = "$packageRoot\\lib\\$arch\\$fileName"
    if (fileExists(fallback)) {
        logState(functionName, "resolved fallback path=$fallback")
        return fallback
    }
    fail("Could not locate $fileName")
}

private fun guidBytes(
    d1: UInt,
    d2: UShort,
    d3: UShort,
    b0: UByte,
    b1: UByte,
    b2: UByte,
    b3: UByte,
    b4: UByte,
    b5: UByte,
    b6: UByte,
    b7: UByte
): ByteArray {
    return byteArrayOf(
        (d1 and 0xFFu).toByte(),
        ((d1 shr 8) and 0xFFu).toByte(),
        ((d1 shr 16) and 0xFFu).toByte(),
        ((d1 shr 24) and 0xFFu).toByte(),
        (d2.toUInt() and 0xFFu).toByte(),
        ((d2.toUInt() shr 8) and 0xFFu).toByte(),
        (d3.toUInt() and 0xFFu).toByte(),
        ((d3.toUInt() shr 8) and 0xFFu).toByte(),
        b0.toByte(), b1.toByte(), b2.toByte(), b3.toByte(),
        b4.toByte(), b5.toByte(), b6.toByte(), b7.toByte()
    )
}

private val IID_IDISPATCHER_QUEUE_CONTROLLER_STATICS = guidBytes(
    0xF18D6145u, 0x722Bu, 0x593Du,
    0xBCu, 0xF2u, 0xA6u, 0x1Eu, 0x71u, 0x3Fu, 0x00u, 0x37u
)
private val IID_IWINDOWS_XAML_MANAGER_STATICS = guidBytes(
    0x56CB591Du, 0xDE97u, 0x539Fu,
    0x88u, 0x1Du, 0x8Cu, 0xCDu, 0xC4u, 0x4Fu, 0xA6u, 0xC4u
)
private val IID_IDESKTOP_WINDOW_XAML_SOURCE = guidBytes(
    0x553AF92Cu, 0x1381u, 0x51D6u,
    0xBEu, 0xE0u, 0xF3u, 0x4Bu, 0xEBu, 0x04u, 0x2Eu, 0xA8u
)
private val IID_IXAML_READER_STATICS = guidBytes(
    0x82A4CD9Eu, 0x435Eu, 0x5AEBu,
    0x8Cu, 0x4Fu, 0x30u, 0x0Cu, 0xECu, 0xE4u, 0x5Cu, 0xAEu
)
private val IID_IUI_ELEMENT = guidBytes(
    0xC3C01020u, 0x320Cu, 0x5CF6u,
    0x9Du, 0x24u, 0xD3u, 0x96u, 0xBBu, 0xFAu, 0x4Du, 0x8Bu
)

private val combaseDll = LoadLibraryW("combase.dll") ?: fail("Failed to load combase.dll")

private fun proc(module: HMODULE?, name: String): COpaquePointer =
    GetProcAddress(module, name) ?: fail("GetProcAddress failed: $name")

private typealias FnRoInitialize = CFunction<(UInt) -> Int>
private typealias FnRoUninitialize = CFunction<() -> Unit>
private typealias FnRoGetActivationFactory = CFunction<(COpaquePointer?, COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>
private typealias FnRoActivateInstance = CFunction<(COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>
private typealias FnWindowsCreateStringReference =
    CFunction<(COpaquePointer?, UInt, COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>
private typealias FnMddBootstrapInitialize2 = CFunction<(UInt, CPointer<UShortVar>?, ULong, UInt) -> Int>
private typealias FnMddBootstrapShutdown = CFunction<() -> Unit>
private typealias FnWindowingGetWindowIdFromWindow = CFunction<(HWND?, CPointer<ULongVar>) -> Int>

private val pfnRoInitialize = proc(combaseDll, "RoInitialize").reinterpret<FnRoInitialize>()
private val pfnRoUninitialize = proc(combaseDll, "RoUninitialize").reinterpret<FnRoUninitialize>()
private val pfnRoGetActivationFactory =
    proc(combaseDll, "RoGetActivationFactory").reinterpret<FnRoGetActivationFactory>()
private val pfnRoActivateInstance =
    proc(combaseDll, "RoActivateInstance").reinterpret<FnRoActivateInstance>()
private val pfnWindowsCreateStringReference =
    proc(combaseDll, "WindowsCreateStringReference").reinterpret<FnWindowsCreateStringReference>()

private fun getVTableEntry(obj: ComPtr, index: Int): COpaquePointer {
    val vtable = obj?.reinterpret<COpaquePointerVar>()?.pointed?.value
        ?: fail("VTable pointer was null")
    return (vtable.reinterpret<COpaquePointerVar>() + index)!!.pointed.value
        ?: fail("VTable slot $index was null")
}

private fun comRelease(obj: ComPtr) {
    if (obj == null) return
    val fn = getVTableEntry(obj, 2).reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
    fn(obj)
}

private fun comQueryInterface(obj: ComPtr, iidBytes: ByteArray): ComPtr = memScoped {
    val iid = allocArray<ByteVar>(16)
    for (i in iidBytes.indices) iid[i] = iidBytes[i]
    val result = alloc<COpaquePointerVar>()
    val fn = getVTableEntry(obj, 0)
        .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>>()
    val hr = fn(obj, iid, result.ptr)
    checkHr("comQueryInterface", "QueryInterface", hr)
    result.value
}

private fun MemScope.createHStringReference(text: String): COpaquePointer? {
    val wstr = text.wcstr.ptr
    val header = allocArray<ByteVar>(HSTRING_HEADER_SIZE)
    val hstring = alloc<COpaquePointerVar>()
    val hr = pfnWindowsCreateStringReference(wstr, text.length.toUInt(), header, hstring.ptr)
    checkHr("createHStringReference", "WindowsCreateStringReference", hr)
    return hstring.value
}

private fun getEnvironmentVariable(name: String): String? = memScoped {
    val bufferSize = 32767u
    val buffer = allocArray<UShortVar>(bufferSize.toInt())
    val length = GetEnvironmentVariableW(name, buffer, bufferSize)
    if (length == 0u) null else buffer.toKStringUtf16()
}

private data class BootstrapRuntime(
    val module: HMODULE,
    val shutdown: CPointer<FnMddBootstrapShutdown>
)

private fun initializeBootstrap(): BootstrapRuntime {
    val functionName = "initializeBootstrap"
    logState(functionName, "begin")
    val packageInfo = resolvePackageWithHeader(listOf("microsoft.windowsappsdk", "microsoft.windowsappsdk.foundation"))
    val bootstrapPath = resolveRuntimeDll("Microsoft.WindowsAppRuntime.Bootstrap.dll")
    val module = LoadLibraryW(bootstrapPath) ?: fail("LoadLibraryW failed: $bootstrapPath")
    logState(functionName, "bootstrap dll path=$bootstrapPath")
    logState(functionName, "selected package version=${packageInfo.packageVersion}")
    val initialize = proc(module, "MddBootstrapInitialize2").reinterpret<FnMddBootstrapInitialize2>()
    val shutdown = proc(module, "MddBootstrapShutdown").reinterpret<FnMddBootstrapShutdown>()
    memScoped {
        val hr = initialize(
            packageInfo.majorMinor,
            "".wcstr.ptr,
            packageInfo.minVersion,
            0u
        )
        checkHr(functionName, "MddBootstrapInitialize2", hr)
    }
    logState(functionName, "end")
    return BootstrapRuntime(module, shutdown)
}

private fun shutdownBootstrap(runtime: BootstrapRuntime) {
    logState("shutdownBootstrap", "begin")
    runtime.shutdown()
    FreeLibrary(runtime.module)
    logState("shutdownBootstrap", "end")
}

private fun ensureDispatcherQueue() {
    val functionName = "ensureDispatcherQueue"
    logState(functionName, "begin")
    memScoped {
        val className = createHStringReference("Microsoft.UI.Dispatching.DispatcherQueueController")
        val iid = allocArray<ByteVar>(16)
        for (i in IID_IDISPATCHER_QUEUE_CONTROLLER_STATICS.indices) iid[i] = IID_IDISPATCHER_QUEUE_CONTROLLER_STATICS[i]
        val factory = alloc<COpaquePointerVar>()
        val hrFactory = pfnRoGetActivationFactory(className, iid, factory.ptr)
        checkHr(functionName, "RoGetActivationFactory", hrFactory)

        val controller = alloc<COpaquePointerVar>()
        val createOnCurrentThread = getVTableEntry(factory.value, 7)
            .reinterpret<CFunction<(COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>>()
        val hrCreate = createOnCurrentThread(factory.value, controller.ptr)
        checkHr(functionName, "CreateOnCurrentThread", hrCreate)
        gDispatcherQueueController = controller.value
        comRelease(factory.value)
    }
    logState(functionName, "end")
}

private fun initializeWindowsXamlManager() {
    val functionName = "initializeWindowsXamlManager"
    logState(functionName, "begin")
    memScoped {
        val className = createHStringReference("Microsoft.UI.Xaml.Hosting.WindowsXamlManager")
        val iid = allocArray<ByteVar>(16)
        for (i in IID_IWINDOWS_XAML_MANAGER_STATICS.indices) iid[i] = IID_IWINDOWS_XAML_MANAGER_STATICS[i]
        val factory = alloc<COpaquePointerVar>()
        val hrFactory = pfnRoGetActivationFactory(className, iid, factory.ptr)
        checkHr(functionName, "RoGetActivationFactory", hrFactory)

        val manager = alloc<COpaquePointerVar>()
        val initializeForCurrentThread = getVTableEntry(factory.value, 6)
            .reinterpret<CFunction<(COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>>()
        val hrInitialize = initializeForCurrentThread(factory.value, manager.ptr)
        checkHr(functionName, "InitializeForCurrentThread", hrInitialize)
        gWindowsXamlManager = manager.value
        comRelease(factory.value)
    }
    logState(functionName, "end")
}

private fun getWindowId(hwnd: HWND?): ULong {
    val functionName = "getWindowId"
    logState(functionName, "begin")
    val path = resolveRuntimeDll("Microsoft.Internal.FrameworkUdk.dll")
    val module = LoadLibraryW(path) ?: fail("LoadLibraryW failed: $path")
    return memScoped {
        val result = alloc<ULongVar>()
        val fn = proc(module, "Windowing_GetWindowIdFromWindow").reinterpret<FnWindowingGetWindowIdFromWindow>()
        val hr = fn(hwnd, result.ptr)
        checkHr(functionName, "Windowing_GetWindowIdFromWindow", hr)
        FreeLibrary(module)
        logState(functionName, "value=${result.value}")
        result.value
    }
}

private fun loadTriangleXaml(source: ComPtr) {
    val functionName = "loadTriangleXaml"
    logState(functionName, "begin")
    val triangleXaml =
        "<Canvas xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' " +
        "xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Background='White'>" +
        "<Path Stroke='Black' StrokeThickness='1'>" +
        "<Path.Fill>" +
        "<LinearGradientBrush StartPoint='0,0' EndPoint='1,1'>" +
        "<GradientStop Color='Red' Offset='0'/>" +
        "<GradientStop Color='Green' Offset='0.5'/>" +
        "<GradientStop Color='Blue' Offset='1'/>" +
        "</LinearGradientBrush>" +
        "</Path.Fill>" +
        "<Path.Data>" +
        "<PathGeometry>" +
        "<PathFigure StartPoint='300,100' IsClosed='True'>" +
        "<LineSegment Point='500,400'/>" +
        "<LineSegment Point='100,400'/>" +
        "</PathFigure>" +
        "</PathGeometry>" +
        "</Path.Data>" +
        "</Path>" +
        "</Canvas>"

    memScoped {
        val readerClass = createHStringReference("Microsoft.UI.Xaml.Markup.XamlReader")
        val iidReader = allocArray<ByteVar>(16)
        for (i in IID_IXAML_READER_STATICS.indices) iidReader[i] = IID_IXAML_READER_STATICS[i]
        val readerFactory = alloc<COpaquePointerVar>()
        val hrFactory = pfnRoGetActivationFactory(readerClass, iidReader, readerFactory.ptr)
        checkHr(functionName, "RoGetActivationFactory(XamlReader)", hrFactory)

        val xaml = createHStringReference(triangleXaml)
        val rootObject = alloc<COpaquePointerVar>()
        val load = getVTableEntry(readerFactory.value, 6)
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>>()
        val hrLoad = load(readerFactory.value, xaml, rootObject.ptr)
        checkHr(functionName, "IXamlReaderStatics::Load", hrLoad)

        val uiElement = comQueryInterface(rootObject.value, IID_IUI_ELEMENT)
        val putContent = getVTableEntry(source, 7)
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Int>>()
        val hrPutContent = putContent(source, uiElement)
        checkHr(functionName, "IDesktopWindowXamlSource::put_Content", hrPutContent)

        comRelease(uiElement)
        comRelease(rootObject.value)
        comRelease(readerFactory.value)
    }
    logState(functionName, "end")
}

private fun initializeXamlIsland(hwnd: HWND?) {
    val functionName = "initializeXamlIsland"
    logState(functionName, "begin")
    memScoped {
        val className = createHStringReference("Microsoft.UI.Xaml.Hosting.DesktopWindowXamlSource")
        val sourceInspectable = alloc<COpaquePointerVar>()
        val hrActivate = pfnRoActivateInstance(className, sourceInspectable.ptr)
        checkHr(functionName, "RoActivateInstance", hrActivate)
        gDesktopWindowXamlSourceInspectable = sourceInspectable.value
        gDesktopWindowXamlSource = comQueryInterface(sourceInspectable.value, IID_IDESKTOP_WINDOW_XAML_SOURCE)

        val windowId = getWindowId(hwnd)
        val initialize = getVTableEntry(gDesktopWindowXamlSource, 17)
            .reinterpret<CFunction<(COpaquePointer?, ULong) -> Int>>()
        val hrInitialize = initialize(gDesktopWindowXamlSource, windowId)
        checkHr(functionName, "IDesktopWindowXamlSource::Initialize", hrInitialize)

        loadTriangleXaml(gDesktopWindowXamlSource)
    }
    logState(functionName, "end")
}

private fun cleanupXamlIsland() {
    logState("cleanupXamlIsland", "begin")
    comRelease(gDesktopWindowXamlSource)
    gDesktopWindowXamlSource = null
    comRelease(gDesktopWindowXamlSourceInspectable)
    gDesktopWindowXamlSourceInspectable = null
    comRelease(gWindowsXamlManager)
    gWindowsXamlManager = null
    comRelease(gDispatcherQueueController)
    gDispatcherQueueController = null
    logState("cleanupXamlIsland", "end")
}

private fun windowProc(hWnd: HWND?, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {
    return when (uMsg.toInt()) {
        WM_DESTROY -> {
            PostQuitMessage(0)
            0L
        }
        else -> DefWindowProcW(hWnd, uMsg, wParam, lParam)
    }
}

private fun createMainWindow(hInstance: HINSTANCE?): HWND? = memScoped {
    logState("createMainWindow", "begin")
    val classNameW = WINDOW_CLASS.wcstr.ptr
    val wcex = alloc<WNDCLASSEXW>().apply {
        cbSize = sizeOf<WNDCLASSEXW>().toUInt()
        style = (CS_HREDRAW or CS_VREDRAW).toUInt()
        lpfnWndProc = staticCFunction(::windowProc)
        cbClsExtra = 0
        cbWndExtra = 0
        this.hInstance = hInstance
        hCursor = LoadCursorW(null, IDC_ARROW)
        hbrBackground = GetSysColorBrush(COLOR_WINDOW)
        lpszMenuName = null
        lpszClassName = classNameW
        hIcon = null
        hIconSm = null
    }

    if (RegisterClassExW(wcex.ptr) == 0.toUShort()) {
        val gle = GetLastError()
        if (gle.toInt() != ERROR_CLASS_ALREADY_EXISTS) fail("RegisterClassExW failed: $gle")
    }

    val rect = alloc<RECT>().apply {
        left = 0
        top = 0
        right = 960
        bottom = 540
    }
    AdjustWindowRect(rect.ptr, WS_OVERLAPPEDWINDOW.toUInt(), 0)

    val hwnd = CreateWindowExW(
        dwExStyle = 0u,
        lpClassName = WINDOW_CLASS,
        lpWindowName = WINDOW_TITLE,
        dwStyle = (WS_OVERLAPPEDWINDOW or WS_VISIBLE).toUInt(),
        X = CW_USEDEFAULT,
        Y = CW_USEDEFAULT,
        nWidth = rect.right - rect.left,
        nHeight = rect.bottom - rect.top,
        hWndParent = null,
        hMenu = null,
        hInstance = hInstance,
        lpParam = null
    ) ?: fail("CreateWindowExW failed: ${GetLastError()}")

    ShowWindow(hwnd, SW_SHOW)
    UpdateWindow(hwnd)
    logState("createMainWindow", "end hwnd=$hwnd")
    hwnd
}

fun main() {
    logState("main", "begin")
    var bootstrapRuntime: BootstrapRuntime? = null
    var coInitialized = false
    var roInitialized = false

    try {
        bootstrapRuntime = initializeBootstrap()

        val hrCo = CoInitializeEx(null, COINIT_APARTMENTTHREADED)
        logState("main", "CoInitializeEx hr=${hrHex(hrCo)}")
        if (hrCo >= 0) {
            coInitialized = true
        } else if (hrCo != RPC_E_CHANGED_MODE) {
            fail("CoInitializeEx failed: ${hrHex(hrCo)}")
        }

        val hrRo = pfnRoInitialize(RO_INIT_SINGLETHREADED)
        logState("main", "RoInitialize hr=${hrHex(hrRo)}")
        if (hrRo == S_OK || hrRo == S_FALSE) {
            roInitialized = true
        } else if (hrRo != RPC_E_CHANGED_MODE) {
            fail("RoInitialize failed: ${hrHex(hrRo)}")
        }

        ensureDispatcherQueue()
        initializeWindowsXamlManager()

        val hInstance = GetModuleHandleW(null)
        val hwnd = createMainWindow(hInstance)
        initializeXamlIsland(hwnd)

        memScoped {
            val msg = alloc<MSG>()
            while (GetMessageW(msg.ptr, null, 0u, 0u) > 0) {
                TranslateMessage(msg.ptr)
                DispatchMessageW(msg.ptr)
            }
        }
    } catch (e: Throwable) {
        logState("main", "error=${e.message ?: "unknown"}")
        MessageBoxW(null, e.message ?: "Unknown error", "Error", MB_OK.toUInt())
    } finally {
        cleanupXamlIsland()
        if (roInitialized) {
            pfnRoUninitialize()
        }
        if (coInitialized) {
            CoUninitialize()
        }
        if (bootstrapRuntime != null) {
            shutdownBootstrap(bootstrapRuntime)
        }
    }
    logState("main", "end")
}
