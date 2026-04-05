#import <Cocoa/Cocoa.h>

@interface CocoaDelegate : NSObject <NSApplicationDelegate>
@end

@implementation CocoaDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    (void)aNotification;
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

@end

void createCocoaWindow(void)
{
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        CocoaDelegate *delegate = [[CocoaDelegate alloc] init];
        [app setDelegate:delegate];

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
        [window setTitle:@"Hello, World! (D)"];
        [window makeKeyAndOrderFront:nil];

        NSRect labelRect = NSMakeRect(50, 125, 300, 50);
        NSTextField *label = [[NSTextField alloc] initWithFrame:labelRect];
        [label setStringValue:@"Hello, D World!"];
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
}
