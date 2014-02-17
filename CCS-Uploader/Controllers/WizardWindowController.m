#import "WizardWindowController.h"
#import "MainWindowController.h"

@interface WizardWindowController () {
    MainWindowController *mainWindowController;
    
    IBOutlet NSView *contentView;
    IBOutlet NSTextField *txtStepTitle, *txtStepDescription;
    IBOutlet NSButton *btnCancel, *btnBack, *btnNext;
    
    LoadingViewController *loadingViewController;
    LoginViewController *loginViewController;
    EventsViewController *eventsViewController;
    BrowseViewController *browseViewController;
    ReviewViewController *reviewViewController;
    ScheduleViewController *scheduleViewController;

    NSAlert *alert;
    
    WizardStep wizardStep;
    
    NSString *effectiveUser, *effectivePass;
    NSInteger effectiveService;
    NSString *effectiveCoreDomain;
}
@end

@implementation WizardWindowController

@synthesize txtStepTitle, txtStepDescription;
@synthesize btnCancel, btnBack, btnNext;
@synthesize effectiveUser, effectivePass;
@synthesize effectiveService;
@synthesize effectiveCoreDomain;

@synthesize
    loadingViewController,
    loginViewController,
    eventsViewController,
    browseViewController,
    reviewViewController,
    scheduleViewController;

- (id)initWithMainWindowController:(MainWindowController *)parent
{
    self = [super initWithWindowNibName:@"WizardWindow"];

    if (self) {
        mainWindowController = parent;
        loadingViewController = [LoadingViewController new];
        loginViewController = [[LoginViewController alloc] initWithWizardController:self];
        eventsViewController = [[EventsViewController alloc] initWithWizardController:self];
        browseViewController = [[BrowseViewController alloc] initWithWizardController:self];
        reviewViewController = [[ReviewViewController alloc] initWithWizardController:self];
        scheduleViewController = [[ScheduleViewController alloc] initWithWizardController:self];
        alert = [NSAlert new];
    }
    
    return self;
}

- (IBAction)showWindow:(id)sender
{
    [super showWindow:sender];
    [loginViewController reloadAccounts];
    [self showStep:kWizardStepLogin];
}

- (IBAction)btnCancelClicked:(id)sender
{
    [self.window close];
}

- (IBAction)btnBackClicked:(id)sender
{
    switch (wizardStep) {
        case kWizardStepLogin:
        case kWizardStepLoading:
            break;
            
        case kWizardStepEvents: {
            [self showStep:kWizardStepLogin];
        } break;

        case kWizardStepBrowse: {
            [self showStep:kWizardStepEvents];
        } break;
            
        case kWizardStepReview: {
            [self showStep:kWizardStepBrowse];
        } break;
            
        case kWizardStepSchedule: {
            [self showStep:kWizardStepReview];
        } break;
    }
}

- (IBAction)btnNextClicked:(id)sender
{
    switch (wizardStep) {
        case kWizardStepLogin: {
            [loginViewController startLogin];
        } break;

        case kWizardStepEvents: {
            EventRow *selectedEvent = [eventsViewController selectedEventRow];
            
            if (selectedEvent) {
                [browseViewController startLoadEvent:selectedEvent fromWizard:YES];
            }
        } break;

        case kWizardStepBrowse: {
            [self showStep:kWizardStepReview];
        } break;
            
        case kWizardStepReview: {
            [self showStep:kWizardStepSchedule];
        } break;
            
        case kWizardStepSchedule: {
            [self.window close];
        } break;
            
        case kWizardStepLoading: break;
    }
}

- (void)showStep:(WizardStep)step
{
    static NSString *titles[] = {
        @"",
        @"Sign In",
        @"Choose an Event",
        @"",
        @"",
        @"",
    };
    
    static NSString *descriptions[] = {
        @"",
        @"Choose a service and enter your username and password",
        @"Select an event from the list to continue",
        @"",
        @"",
        @"",
    };
    
    wizardStep = step;
    
    [btnBack setEnabled:step == kWizardStepLoading || step == kWizardStepLogin ? NO : YES];
    [btnNext setEnabled:step == kWizardStepLoading ? NO : YES];
    
    if (step != kWizardStepLoading && titles[step].length) {
        txtStepTitle.stringValue = titles[step];
    }
    
    if (step != kWizardStepLoading && descriptions[step].length) {
        txtStepDescription.stringValue = descriptions[step];
    }
    
    NSViewController *controller = @[
        loadingViewController,
        loginViewController,
        eventsViewController,
        browseViewController,
        reviewViewController,
        scheduleViewController,
    ][step];
    
    if (step == kWizardStepLoading) {
        [loadingViewController.view setFrameSize:contentView.frame.size];
    }
    
    [self swapContentView:controller.view];
}

- (void)swapContentView:(NSView *)newView
{
    CGFloat widthDiff = newView.frame.size.width - contentView.frame.size.width;
    CGFloat heightDiff = newView.frame.size.height - contentView.frame.size.height;
    
    NSRect windowFrame = self.window.frame;
    
    [contentView setFrameSize:NSMakeSize(newView.frame.size.width, newView.frame.size.height)];
    [newView setFrameOrigin:NSZeroPoint];
    
    windowFrame.origin.x -= roundf(widthDiff / 2);
    windowFrame.origin.y -= roundf(heightDiff / 2);
    windowFrame.size.width += widthDiff;
    windowFrame.size.height += heightDiff;

    contentView.subviews = [NSArray array];
    [self.window setFrame:windowFrame display:YES animate:YES];
    [contentView addSubview:newView];
}

@end
