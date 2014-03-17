#import "AppDelegate.h"
#import "Utils/TransferFileParser.h"
#import "Utils/ImageUtil.h"

@interface AppDelegate () {
    IBOutlet NSMenu *statusBarMenu;
    NSStatusItem *statusItem;
    TransferFileParser *transferFileParser;
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
    
    /*
    [ImageUtil resizeAndRotateImage:@"/Users/blagovest/Downloads/lotus.jpg" outputImageFilename:@"/Users/blagovest/Downloads/watermark.jpg"
        resizeToMaxSide:640 rotate:kDontRotate
        horizontalWatermark:nil
        verticalWatermark:[NSData dataWithContentsOfFile:@"/Users/blagovest/Downloads/testv.tif"]
        compressionQuality:0.8];
    */
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    if (transferFileParser == nil) {
        transferFileParser = [TransferFileParser new];
    }
    
    NSDictionary *parsedFile = [transferFileParser parse:filename];
    
    if (parsedFile == nil) {
        NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"Could not parse \"%@\".", filename]
            defaultButton:@"OK" alternateButton:@"" otherButton:@"" informativeTextWithFormat:@""];
        
        [alert beginSheetModalForWindow:mainWindowController.window completionHandler:nil];
        return YES;
    }
    
    if (mainWindowController == nil) {
        mainWindowController = [MainWindowController new];
    }
    
    [mainWindowController openEvent:parsedFile filename:filename];
    return YES;
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
