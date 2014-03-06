#import <Cocoa/Cocoa.h>

@class WizardWindowController;

@interface ScheduleViewController : NSViewController

- (id)initWithWizardController:(WizardWindowController *)parent;
- (void)resetFormState;
- (void)pushTransfer;

@end
