#import <Cocoa/Cocoa.h>

@class WizardWindowController, EventRow;

@interface BrowseViewController : NSViewController

- (id)initWithWizardController:(WizardWindowController *)parent;
- (void)startLoadEvent:(EventRow *)event fromWizard:(BOOL)fromWizard;

@end
