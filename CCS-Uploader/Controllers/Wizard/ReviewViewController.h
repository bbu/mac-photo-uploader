#import <Cocoa/Cocoa.h>

@class WizardWindowController;

@interface ReviewViewController : NSViewController

- (id)initWithWizardController:(WizardWindowController *)parent;
- (void)reload;

@end
