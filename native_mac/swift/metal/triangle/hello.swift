import Cocoa
import MetalKit

final class Renderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    init?(view: MTKView) {
        guard let device = view.device,
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.commandQueue = commandQueue

        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float4 color;
        };

        vertex VertexOut vertex_main(uint vid [[vertex_id]]) {
            float4 positions[3] = {
                float4( 0.0,  0.7, 0.0, 1.0),
                float4(-0.7, -0.7, 0.0, 1.0),
                float4( 0.7, -0.7, 0.0, 1.0)
            };

            float4 colors[3] = {
                float4(1.0, 0.0, 0.0, 1.0),
                float4(0.0, 1.0, 0.0, 1.0),
                float4(0.0, 0.0, 1.0, 1.0)
            };

            VertexOut out;
            out.position = positions[vid];
            out.color = colors[vid];
            return out;
        }

        fragment float4 fragment_main(VertexOut in [[stage_in]]) {
            return in.color;
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let vertexFunction = library.makeFunction(name: "vertex_main"),
                  let fragmentFunction = library.makeFunction(name: "fragment_main") else {
                return nil
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            return nil
        }

        super.init()
        view.delegate = self
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var renderer: Renderer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 640, height: 480)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let window = NSWindow(contentRect: rect, styleMask: style, backing: .buffered, defer: false)
        window.title = "Hello, Metal World!"
        window.center()

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        let view = MTKView(frame: rect, device: device)
        view.clearColor = MTLClearColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0)
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 60

        guard let renderer = Renderer(view: view) else {
            fatalError("Failed to create Metal renderer")
        }

        window.contentView = view
        window.makeKeyAndOrderFront(nil)

        self.renderer = renderer
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
