#import "ReviewViewController.h"

#import "../WizardWindowController.h"

@interface ReviewViewController () {
    WizardWindowController *wizardWindowController;
}

@end

@implementation ReviewViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"ReviewView" bundle:nil];
    
    if (self) {
        wizardWindowController = parent;
    }
    
    return self;
}

@end
