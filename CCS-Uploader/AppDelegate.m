#import "AppDelegate.h"
#import "Utils/ImageUtil.h"
#import "Utils/FileUtil.h"

@interface AppDelegate () {
    IBOutlet NSMenu *statusBarMenu;
    NSStatusItem *statusItem;
}

@end

@implementation AppDelegate

- (void)awakeFromNib
{
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    statusItem.image = [NSImage imageNamed:@"UploadIcon"];
    statusItem.menu = statusBarMenu;
    statusItem.highlightMode = YES;
    
    //[ImageUtil setExif:@"/Users/blagovest/Downloads/lotus.jpg" value:8];
    [ImageUtil scaleAndRotateImage:@"/Users/blagovest/Downloads/lotus.jpg"];
    [ImageUtil exif:@"/Users/blagovest/Downloads/lotus.jpg"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if (mainWindowController == nil) {
        mainWindowController = [MainWindowController new];
    }
    
    [NSApp activateIgnoringOtherApps:YES];
    [mainWindowController showWindow:nil];
    [mainWindowController.window makeKeyAndOrderFront:nil];
}

- (IBAction)openPrefs:(id)sender
{
    if (prefsWindowController == nil) {
        prefsWindowController = [PrefsWindowController new];
    }
    
    [prefsWindowController showWindow:nil];
}

- (IBAction)openMainWindow:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    [mainWindowController showWindow:nil];
    [mainWindowController.window makeKeyAndOrderFront:nil];
}

- (IBAction)exitClicked:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to quit?" defaultButton:@"Yes" alternateButton:@"No" otherButton:@"" informativeTextWithFormat:@""];

    [alert beginSheetModalForWindow:mainWindowController.window
        completionHandler:^(NSModalResponse response) {
            if (response == NSModalResponseOK) {
                [NSApp terminate:nil];
            }
        }
    ];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return NO;
}

@end
