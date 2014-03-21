#import <Cocoa/Cocoa.h>

@class EventRow;
@class WizardWindowController;

@interface EventsViewController : NSViewController

- (id)initWithWizardController:(WizardWindowController *)parent;
- (void)refreshEvents:(BOOL)fromWizard;
- (void)refreshIfEmpty;
- (EventRow *)selectedEventRow;

@end
