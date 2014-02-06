#import "WizardWindowController.h"

typedef NS_ENUM(NSUInteger, WizardStep) {
    kWizardStepLoading,
    kWizardStepLogin,
    kWizardStepEvents,
    kWizardStepBrowse,
    kWizardStepReview,
    kWizardStepSchedule,
};

@interface WizardWindowController () {
    IBOutlet NSView *contentView;
    IBOutlet NSTextField *txtStepTitle, *txtStepDescription;
    IBOutlet NSButton *btnCancel, *btnBack, *btnNext;
    
    LoadingViewController *loadingViewController;
    LoginViewController *loginViewController;
    EventsViewController *eventsViewController;
    BrowseViewController *browseViewController;
    NSAlert *alert;
    
    WizardStep wizardStep;
}
@end

@implementation WizardWindowController
@synthesize btnCancel, btnBack, btnNext, loadingViewController, loginViewController, eventsViewController, browseViewController;

- (id)init
{
    self = [super initWithWindowNibName:@"WizardWindow"];

    if (self) {
        loadingViewController = [LoadingViewController new];
        loginViewController = [[LoginViewController alloc] initWithWizardController:self];
        eventsViewController = [[EventsViewController alloc] initWithWizardController:self];
        browseViewController = [[BrowseViewController alloc] initWithWizardController:self];
        alert = [NSAlert new];
    }
    
    return self;
}

- (IBAction)showWindow:(id)sender
{
    [super showWindow:sender];
    [loginViewController reloadAccounts];
    [self showLoginStep];
}

- (IBAction)btnCancelClicked:(id)sender
{
    [self.window close];
}

- (IBAction)btnBackClicked:(id)sender
{
    switch (wizardStep) {
        case kWizardStepEvents:
            [self showLoginStep];
            break;

        case kWizardStepBrowse:
            [self showEventsStep];
            break;
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
            
            if (selectedEvent == nil) {
                alert.messageText = @"You must select an event.";
                [alert beginSheetModalForWindow:self.window completionHandler:nil];
            } else {
                [self showBrowseStep];
            }
            
        } break;
    }
    
    //[loadingViewController.view setFrameSize:NSMakeSize(700, 400)];
    //[self swapContentView:loadingViewController.view mode:kWindowResizingCenter animate:YES];
}

- (void)showLoginStep
{
    wizardStep = kWizardStepLogin;
    
    [btnBack setEnabled:NO];
    [btnNext setEnabled:YES];
    
    txtStepTitle.stringValue = @"Sign In";
    txtStepDescription.stringValue = @"Choose a service and enter your username and password";
    
    [self swapContentView:loginViewController.view];
}

- (void)showLoadingStep
{
    [btnBack setEnabled:NO];
    [btnNext setEnabled:NO];

    [loadingViewController.view setFrameSize:contentView.frame.size];    
    [self swapContentView:loadingViewController.view];
}

- (void)showEventsStep
{
    wizardStep = kWizardStepEvents;
    
    [btnBack setEnabled:YES];
    [btnNext setEnabled:YES];
    
    txtStepTitle.stringValue = @"Choose an Event";
    txtStepDescription.stringValue = @"Enter an event number or select an event from the list to continue";
    
    [self swapContentView:eventsViewController.view];
}

- (void)showBrowseStep
{
    wizardStep = kWizardStepBrowse;
    
    [btnBack setEnabled:YES];
    [btnNext setEnabled:YES];
    
    txtStepTitle.stringValue = @"Browse for Images";
    txtStepDescription.stringValue = @"Add images to event \"My Test Event\" (12345678)";
    
    [self swapContentView:browseViewController.view];
}

- (void)swapContentView:(NSView *)newView
{
    CGFloat widthDiff = newView.frame.size.width - contentView.frame.size.width;
    CGFloat heightDiff = newView.frame.size.height - contentView.frame.size.height;
    
    NSRect windowFrame = self.window.frame;
    
    [contentView setFrameSize:NSMakeSize(newView.frame.size.width, newView.frame.size.height)];
    [newView setFrameOrigin:NSZeroPoint];
    
    windowFrame.size.width += widthDiff;
    windowFrame.size.height += heightDiff;
    windowFrame.origin.x -= widthDiff / 2;
    windowFrame.origin.y -= heightDiff / 2;
    
    if (contentView.subviews.count) {
        [contentView.subviews[0] removeFromSuperview];
    }
    
    [self.window setFrame:windowFrame display:YES animate:YES];
    [contentView addSubview:newView];
}

@end
