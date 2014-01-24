#import <Cocoa/Cocoa.h>

#import "Controllers/MainWindowController.h"
#import "Controllers/PrefsWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    @private
    MainWindowController *mainWindowController;
    PrefsWindowController *prefsWindowController;
}

@property (assign) IBOutlet NSWindow *window;

-(IBAction)openPrefs:(id)sender;

@end
