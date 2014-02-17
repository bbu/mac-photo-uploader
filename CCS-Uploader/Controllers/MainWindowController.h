#import <Cocoa/Cocoa.h>

#import "WizardWindowController.h"

@interface MainWindowController : NSWindowController<NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSWindowDelegate> {
}

- (IBAction)deleteRowFromThumbnails:(id)sender;

@end
