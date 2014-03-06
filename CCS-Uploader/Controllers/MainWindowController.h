#import <Cocoa/Cocoa.h>

#import "WizardWindowController.h"

#import "../Models/TransferManager.h"

@interface MainWindowController : NSWindowController<NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSWindowDelegate>

@property (readonly) TransferManager *transferManager;

@end
