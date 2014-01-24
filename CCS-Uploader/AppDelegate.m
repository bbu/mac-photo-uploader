#import "AppDelegate.h"
#import "Utils/ImageUtil.h"

@interface AppDelegate () {
    IBOutlet NSMenu *statusBarMenu;
    NSStatusItem *statusBar;
}

@end

@implementation AppDelegate

- (void)awakeFromNib
{
    statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    statusBar.image = [NSImage imageNamed:@"UploadIcon"];
    statusBar.menu = statusBarMenu;
    statusBar.highlightMode = YES;
    
    //[ImageUtil setExif:@"/Users/blagovest/Downloads/EXIF_Orientation_Samples/left.jpg"];
    //[ImageUtil exif:@"/Users/blagovest/Downloads/EXIF_Orientation_Samples/left.jpg"];
    //NSImage *img = [[NSImage alloc] initWithContentsOfFile:@"/Users/blagovest/Downloads/DSC00381.JPG"];
    //[ImageUtil generateThumbnailForImage:img atPath:@"/Users/blagovest/Downloads/result.JPG" forWidth:150];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if (mainWindowController == nil) {
        mainWindowController = [MainWindowController new];
    }
    
    //[NSApp activateIgnoringOtherApps:YES];
    [mainWindowController showWindow:nil];
    //[mainWindowController.window makeKeyAndOrderFront:nil];
}

-(IBAction)openPrefs:(id)sender
{
    if (prefsWindowController == nil) {
        prefsWindowController = [PrefsWindowController new];
    }
    
    [prefsWindowController showWindow:nil];
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

@end
