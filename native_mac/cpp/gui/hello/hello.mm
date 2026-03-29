#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}

@end

int main(int argc, const char *argv[])
{
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];

        // Create window
        NSRect screenRect = [[NSScreen mainScreen] frame];
        NSRect windowRect = NSMakeRect(
            (screenRect.size.width - 400) / 2,
            (screenRect.size.height - 300) / 2,
            400,
            300
        );

        NSWindow *window = [[NSWindow alloc] 
            initWithContentRect:windowRect
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
            backing:NSBackingStoreBuffered
            defer:NO
        ];
        [window setTitle:@"Hello, World!"];
        [window makeKeyAndOrderFront:nil];

        // Create label
        NSRect labelRect = NSMakeRect(50, 125, 300, 50);
        NSTextField *label = [[NSTextField alloc] initWithFrame:labelRect];
        [label setStringValue:@"Hello, World!"];
        [label setEditable:NO];
        [label setSelectable:NO];
        [label setBezeled:NO];
        [label setDrawsBackground:NO];

        NSFont *font = [NSFont systemFontOfSize:24.0];
        [label setFont:font];

        NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:[label stringValue]];
        [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, [attrString length])];
        [label setAttributedStringValue:attrString];

        [[window contentView] addSubview:label];

        [app run];
    }

    return 0;
}
