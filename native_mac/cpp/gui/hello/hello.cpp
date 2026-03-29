#include <iostream>
#include <string>

// Forward declarations for bridge functions
extern "C" {
    void cocoa_initialize_app();
    void cocoa_create_window(const char* title);
    void cocoa_add_label(const char* text);
    void cocoa_run_app();
}

class CocoaApp {
public:
    CocoaApp() {
        cocoa_initialize_app();
    }

    void createWindow(const std::string& title) {
        std::cout << "Creating Cocoa window: " << title << std::endl;
        cocoa_create_window(title.c_str());
    }

    void addLabel(const std::string& text) {
        std::cout << "Adding label: " << text << std::endl;
        cocoa_add_label(text.c_str());
    }

    void run() {
        std::cout << "Running application loop..." << std::endl;
        cocoa_run_app();
    }
};

int main(int argc, const char* argv[])
{
    (void)argc;
    (void)argv;

    try {
        // Create and run the Cocoa application using C++ wrapper
        CocoaApp app;
        app.createWindow("Hello, World! (C++)");
        app.addLabel("Hello, World!");
        app.run();
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
