#import <Cocoa/Cocoa.h>
#include <iostream>

// Global variables to hold Cocoa objects
static NSApplication *g_app = nil;
static NSWindow *g_window = nil;
static NSTextField *g_label = nil;

// Delegate for application lifecycle
@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    (void)aNotification;
    [g_app activateIgnoringOtherApps:YES];
}

@end

// C bridge functions (called from C++ code)

extern "C" {

void cocoa_initialize_app()
{
    g_app = [NSApplication sharedApplication];
    AppDelegate *delegate = [[AppDelegate alloc] init];
    [g_app setDelegate:delegate];
    std::cout << "Cocoa application initialized" << std::endl;
}

void cocoa_create_window(const char* title)
{
    @autoreleasepool {
        // Get screen dimensions
        NSRect screenRect = [[NSScreen mainScreen] frame];
        NSRect windowRect = NSMakeRect(
            (screenRect.size.width - 400) / 2,
            (screenRect.size.height - 300) / 2,
            400,
            300
        );

        // Create window
        g_window = [[NSWindow alloc]
            initWithContentRect:windowRect
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
            backing:NSBackingStoreBuffered
            defer:NO
        ];

        // Set window title
        NSString *titleStr = [NSString stringWithUTF8String:title];
        [g_window setTitle:titleStr];
        [g_window makeKeyAndOrderFront:nil];

        std::cout << "Window created with title: " << title << std::endl;
    }
}

void cocoa_add_label(const char* text)
{
    @autoreleasepool {
        // Create label
        NSRect labelRect = NSMakeRect(50, 125, 300, 50);
        g_label = [[NSTextField alloc] initWithFrame:labelRect];

        // Configure label
        NSString *labelText = [NSString stringWithUTF8String:text];
        [g_label setStringValue:labelText];
        [g_label setEditable:NO];
        [g_label setSelectable:NO];
        [g_label setBezeled:NO];
        [g_label setDrawsBackground:NO];

        // Set font
        NSFont *font = [NSFont systemFontOfSize:24.0];
        [g_label setFont:font];

        // Set text color
        NSMutableAttributedString *attrString = 
            [[NSMutableAttributedString alloc] initWithString:labelText];
        [attrString addAttribute:NSForegroundColorAttributeName 
                          value:[NSColor blackColor] 
                          range:NSMakeRange(0, [attrString length])];
        [g_label setAttributedStringValue:attrString];

        // Add label to window
        [[g_window contentView] addSubview:g_label];

        std::cout << "Label added with text: " << text << std::endl;
    }
}

void cocoa_run_app()
{
    [g_app run];
}

} // extern "C"
