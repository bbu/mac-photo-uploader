#import "AppDelegate.h"
#import "Utils/ImageUtil.h"
#import "Utils/FileUtil.h"
#import "Utils/Base64.h"
#import "Utils/CCSPassword.h"

#import "Services/VerifyOrderService.h"

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
    
    /*
    VerifyOrderService *s = [VerifyOrderService new];
    
    [s startVerifyOrder:@"11420" password:@"11420" orderNumber:@"26710294" version:@"CCSTransfer 999" bypassPassword:NO complete:^(VerifyOrderResult *result) {
            NSLog(@"complete");
        }
    ];
    */
    //[ImageUtil setExif:@"/Users/blagovest/Downloads/test.png" value:3];
    
    /*BOOL success;
    CGSize imageSize = CGSizeZero;
    NSMutableString *imageType = [NSMutableString new];
    NSUInteger imageOrientation = 0;
    
    success = [ImageUtil getImageProperties:@"/Users/blagovest/Downloads/test.png" size:&imageSize type:imageType orientation:&imageOrientation];
    
    if (success) {
        NSLog(@"Properties: %lf x %lf, %@, %lu", imageSize.width, imageSize.height, imageType, imageOrientation);
    }*/
    /*
    [ImageUtil resizeAndRotateImage:@"/Users/blagovest/Downloads/lotus8.jpg" outputImageFilename:@"/Users/blagovest/Downloads/lotus.jpg"
        resizeToMaxSide:200 rotate:kDontRotate compressionQuality:1];
    */
    
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
