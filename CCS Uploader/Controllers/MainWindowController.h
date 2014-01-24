#import <Cocoa/Cocoa.h>

#import "WizardWindowController.h"

@interface MainWindowController : NSWindowController<NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSWindowDelegate> {
    @private
    IBOutlet NSTableView *tblThumbnails, *tblFullSize;
    IBOutlet NSMenu *menuThumbnails;
    IBOutlet WizardWindowController *wizardWindowController;
}

- (IBAction)deleteRowFromThumbnails:(id)sender;

@end
