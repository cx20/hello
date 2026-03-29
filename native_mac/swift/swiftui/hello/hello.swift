import SwiftUI

@main
struct HelloApp: App {
    var body: some Scene {
        WindowGroup("Hello, World!") {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(.black)
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}
