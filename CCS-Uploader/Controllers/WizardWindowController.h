#import <Cocoa/Cocoa.h>

#import "Wizard/LoadingViewController.h"
#import "Wizard/LoginViewController.h"
#import "Wizard/EventsViewController.h"
#import "Wizard/BrowseViewController.h"

typedef NS_ENUM(NSUInteger, WizardStep) {
    kWizardStepLoading = 0,
    kWizardStepLogin,
    kWizardStepEvents,
    kWizardStepBrowse,
    kWizardStepReview,
    kWizardStepSchedule,
};

@interface WizardWindowController : NSWindowController

- (void)showStep:(WizardStep)step;

@property (readonly) NSTextField *txtStepTitle, *txtStepDescription;
@property (readonly) NSButton *btnCancel, *btnBack, *btnNext;
@property LoadingViewController *loadingViewController;
@property LoginViewController *loginViewController;
@property EventsViewController *eventsViewController;
@property BrowseViewController *browseViewController;

@end
