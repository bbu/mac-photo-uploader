#import "ScheduleViewController.h"

#import "../WizardWindowController.h"

@interface ScheduleViewController () {
    WizardWindowController *wizardWindowController;
}

@end

@implementation ScheduleViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"ScheduleView" bundle:nil];
    
    if (self) {
        wizardWindowController = parent;
    }
    
    return self;
}

- (void)resetFormState
{
    
}

@end
