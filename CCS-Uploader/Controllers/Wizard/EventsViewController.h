#import <Cocoa/Cocoa.h>

@class WizardWindowController;

@interface EventsViewController : NSViewController

- (id)initWithWizardController:(WizardWindowController *)parent;
- (void)refreshEvents:(BOOL)fromWizard;

@end
