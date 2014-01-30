#import <Cocoa/Cocoa.h>

#import "Wizard/LoadingViewController.h"
#import "Wizard/LoginViewController.h"
#import "Wizard/EventsViewController.h"
#import "Wizard/BrowseViewController.h"

@interface WizardWindowController : NSWindowController

- (void)showLoadingStep;
- (void)showLoginStep;
- (void)showEventsStep;
- (void)showBrowseStep;

@property NSButton *btnCancel, *btnBack, *btnNext;
@property LoadingViewController *loadingViewController;
@property LoginViewController *loginViewController;
@property EventsViewController *eventsViewController;
@property BrowseViewController *browseViewController;

@end
