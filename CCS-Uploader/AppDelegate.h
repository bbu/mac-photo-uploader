#import <Cocoa/Cocoa.h>

#import "Controllers/MainWindowController.h"
#import "Controllers/PrefsWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    @private
    MainWindowController *mainWindowController;
    PrefsWindowController *prefsWindowController;
}

-(IBAction)openPrefs:(id)sender;

@end
