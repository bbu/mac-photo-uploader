#import <Cocoa/Cocoa.h>

#import "WizardWindowController.h"

#import "../Models/TransferManager.h"

@interface MainWindowController : NSWindowController<NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSWindowDelegate>

@property (readonly) NSMutableSet *openedEvents;
@property (readonly) TransferManager *transferManager;

- (void)openEvent:(NSDictionary *)params filename:(NSString *)filename;

@end
