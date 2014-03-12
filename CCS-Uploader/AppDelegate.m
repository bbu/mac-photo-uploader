#import "AppDelegate.h"

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

    //NSString *domainName = [[NSBundle mainBundle] bundleIdentifier];
    //[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domainName];
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

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    if (!flag) {
        [self openMainWindow:nil];
    }
    
    return NO;
}

- (IBAction)openPrefs:(id)sender
{
    if (prefsWindowController == nil) {
        prefsWindowController = [PrefsWindowController new];
    }
    
    [NSApp activateIgnoringOtherApps:YES];
    [prefsWindowController showWindow:nil];
    [prefsWindowController.window makeKeyAndOrderFront:nil];
}

- (IBAction)openMainWindow:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    [mainWindowController showWindow:nil];
    [mainWindowController.window makeKeyAndOrderFront:nil];
}

- (IBAction)exitClicked:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to quit?"
        defaultButton:@"Yes" alternateButton:@"No" otherButton:@"" informativeTextWithFormat:@""];

    [alert beginSheetModalForWindow:mainWindowController.window
        completionHandler:^(NSModalResponse response) {
            if (response == NSModalResponseOK) {
                [mainWindowController.transferManager save];
                [NSApp terminate:nil];
            }
        }
    ];
}

@end
