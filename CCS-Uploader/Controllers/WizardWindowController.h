#import <Cocoa/Cocoa.h>

@class MainWindowController;

#import "Wizard/LoadingViewController.h"
#import "Wizard/LoginViewController.h"
#import "Wizard/EventsViewController.h"
#import "Wizard/BrowseViewController.h"
#import "Wizard/ReviewViewController.h"
#import "Wizard/ScheduleViewController.h"

typedef NS_ENUM(NSUInteger, WizardStep) {
    kWizardStepLoading = 0,
    kWizardStepLogin,
    kWizardStepEvents,
    kWizardStepBrowse,
    kWizardStepReview,
    kWizardStepSchedule,
};

@interface WizardWindowController : NSWindowController

- (id)initWithMainWindowController:(MainWindowController *)parent;
- (void)showStep:(WizardStep)step;
- (void)openEvent:(NSString *)orderNumber isQuicPost:(BOOL)isQuicPost;
- (void)showEvent:(NSString *)orderNumber user:(NSString *)user pass:(NSString *)pass
    source:(NSString *)source filename:(NSString *)filename;

@property (readonly) NSTextField *txtStepTitle, *txtStepDescription;
@property (readonly) NSButton *btnCancel, *btnBack, *btnNext;
@property LoadingViewController *loadingViewController;
@property LoginViewController *loginViewController;
@property EventsViewController *eventsViewController;
@property BrowseViewController *browseViewController;
@property ReviewViewController *reviewViewController;
@property ScheduleViewController *scheduleViewController;

@property (readonly) WizardStep wizardStep;

@property NSString *effectiveUser, *effectivePass;
@property NSInteger effectiveService;
@property NSString *effectiveCoreDomain;

@property (readonly) MainWindowController *mainWindowController;
@property EventRow *eventRow;

@end
