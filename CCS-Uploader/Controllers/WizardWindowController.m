#import "WizardWindowController.h"
#import "MainWindowController.h"

#import "../Utils/FileUtil.h"
#import "../Models/OrderModel.h"

#import "../Services/ListEventsService.h"
#import "../Services/SendFeedbackService.h"

@interface WizardWindowController () {
    MainWindowController *mainWindowController;
    
    IBOutlet NSView *contentView;
    IBOutlet NSTextField *txtStepTitle, *txtStepDescription;
    IBOutlet NSButton *btnCancel, *btnBack, *btnNext, *btnSubmitFeedback;

    IBOutlet NSPanel *submitFeedbackSheet;
    IBOutlet NSTextField *txtFeedbackName, *txtFeedbackEmail, *txtFeedbackText;
    IBOutlet NSPopUpButton *feedbackType;
    IBOutlet NSTextField *sendingFeedbackLabel;
    IBOutlet NSProgressIndicator *sendingFeedbackProgress;
    IBOutlet NSButton *btnFeedbackCancel, *btnFeedbackSubmit;
    
    LoadingViewController *loadingViewController;
    LoginViewController *loginViewController;
    EventsViewController *eventsViewController;
    BrowseViewController *browseViewController;
    ReviewViewController *reviewViewController;
    ScheduleViewController *scheduleViewController;

    ListEventsService *listEventService;
    SendFeedbackService *sendFeedbackService;
    
    WizardStep wizardStep;
    
    NSString *effectiveUser, *effectivePass;
    NSInteger effectiveService;
    NSString *effectiveCoreDomain;
}
@end

@implementation WizardWindowController

@synthesize txtStepTitle, txtStepDescription;
@synthesize btnCancel, btnBack, btnNext;
@synthesize wizardStep;
@synthesize effectiveUser, effectivePass;
@synthesize effectiveService;
@synthesize effectiveCoreDomain;
@synthesize mainWindowController;
@synthesize eventRow;

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
        listEventService = [ListEventsService new];
        sendFeedbackService = [SendFeedbackService new];
    }
    
    return self;
}

- (void)centerWindow
{
    static CGFloat offset = 20;
    
    CGFloat windowWidth = self.window.frame.size.width;
    CGFloat windowHeight = self.window.frame.size.height;
    CGFloat screenWidth = [NSScreen mainScreen].visibleFrame.size.width;
    CGFloat screenHeight = [NSScreen mainScreen].visibleFrame.size.height;
    
    [self.window setFrameOrigin:NSMakePoint((screenWidth - windowWidth) / 2. - offset, (screenHeight - windowHeight) / 2. + offset)];

    if (offset >= 140) {
        offset = 20;
    } else {
        offset += 20;
    }
}

- (IBAction)showWindow:(id)sender
{
    [super showWindow:sender];
    [self centerWindow];
    
    [loginViewController reloadAccounts];
    [self showStep:kWizardStepLogin];
}

- (void)openEvent:(NSString *)orderNumber isQuicPost:(BOOL)isQuicPost
{
    [super showWindow:nil];
    [self centerWindow];

    [loadingViewController view];
    loadingViewController.txtMessage.stringValue = @"Checking the event...";
    txtStepTitle.stringValue = [NSString stringWithFormat:@"Opening event number %@ (%@)", orderNumber, isQuicPost ? @"QuicPost" : @"CORE"];
    txtStepDescription.stringValue = @"";
    
    [self showStep:kWizardStepLoading];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (!isQuicPost) {
        effectiveUser = [defaults objectForKey:kCoreUser];
        effectivePass = [defaults objectForKey:kCorePass];
        effectiveService = kServiceRootCore;
        effectiveCoreDomain = [defaults objectForKey:kCoreDomain];
    } else {
        effectiveUser = [defaults objectForKey:kQuicPostUser];
        effectivePass = [defaults objectForKey:kQuicPostPass];
        effectiveService = kServiceRootQuicPost;
        effectiveCoreDomain = nil;
    }
    
    if (!effectiveUser || !effectivePass) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Please setup your login credentials first."
            defaultButton:@"OK" alternateButton:@"" otherButton:@"" informativeTextWithFormat:@""];
        
        [alert beginSheetModalForWindow:self.window
            completionHandler:^(NSModalResponse response) {
                [self.window close];
            }
        ];
        
        return;
    }
    
    [listEventService setEffectiveServiceRoot:effectiveService coreDomain:effectiveCoreDomain];
    [listEventService startListEvent:effectiveUser password:effectivePass orderNumber:orderNumber
        complete:^(ListEventsResult *result) {
            if (!result.error && result.events.count == 1 &&
                ((EventRow *)result.events[0]).orderNumber != nil && ((EventRow *)result.events[0]).orderNumber.length != 0) {
                
                [browseViewController startLoadEvent:result.events[0] fromWizard:NO];
                [btnNext setEnabled:NO];
            } else {
                NSAlert *alert = [NSAlert new];
                                    
                alert.messageText = [NSString stringWithFormat:
                    @"Could not find a %@ event with the number \"%@\".",
                    effectiveService == kServiceRootCore ? @"CORE" : @"QuicPost", orderNumber];
                                    
                [alert beginSheetModalForWindow:self.window
                    completionHandler:^(NSModalResponse response) {
                        [self.window close];
                    }
                ];
            }
        }
    ];
}

- (void)showEvent:(NSString *)orderNumber user:(NSString *)user pass:(NSString *)pass
    source:(NSString *)source filename:(NSString *)filename
{
    [super showWindow:nil];
    [self centerWindow];

    [loadingViewController view];
    loadingViewController.txtMessage.stringValue = @"Checking the event...";
    txtStepTitle.stringValue = filename.lastPathComponent;
    txtStepDescription.stringValue = @"";
    
    [self showStep:kWizardStepLoading];
    
    if ([source.lowercaseString isEqualToString:@"core"]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        effectiveService = kServiceRootCore;
        effectiveCoreDomain = [defaults objectForKey:kCoreDomain];
        
        if (!effectiveCoreDomain) {
            effectiveCoreDomain = kDefaultCoreDomain;
        }
    } else if ([source.lowercaseString isEqualToString:@"quicpost"]) {
        effectiveService = kServiceRootQuicPost;
        effectiveCoreDomain = nil;
    } else {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Not a CORE or a QuicPost event."
            defaultButton:@"OK" alternateButton:@"" otherButton:@"" informativeTextWithFormat:@""];
        
        [alert beginSheetModalForWindow:self.window
            completionHandler:^(NSModalResponse response) {
                [self.window close];
            }
        ];
        
        return;
    }
    
    effectiveUser = user;
    effectivePass = pass;
    
    [listEventService setEffectiveServiceRoot:effectiveService coreDomain:effectiveCoreDomain];
    [listEventService startListEvent:user password:pass orderNumber:orderNumber
        complete:^(ListEventsResult *result) {
            if (!result.error && result.events.count == 1 &&
                ((EventRow *)result.events[0]).orderNumber != nil && ((EventRow *)result.events[0]).orderNumber.length != 0) {
                
                [browseViewController startLoadEvent:result.events[0] fromWizard:NO];
                [btnNext setEnabled:NO];
            } else {
                NSAlert *alert = [NSAlert new];
                
                alert.messageText = [NSString stringWithFormat:
                    @"Could not find a %@ event with the number \"%@\".",
                        effectiveService == kServiceRootCore ? @"CORE" : @"QuicPost", orderNumber];
                
                [alert beginSheetModalForWindow:self.window
                    completionHandler:^(NSModalResponse response) {
                        [self.window close];
                    }
                ];
            }
        }
    ];
}

- (IBAction)btnCancelClicked:(id)sender
{
    if (self.eventRow != nil && self.eventRow.orderNumber != nil) {
        [mainWindowController.openedEvents removeObject:self.eventRow.orderNumber];
        self.eventRow = nil;
    }
    
    if (wizardStep == kWizardStepBrowse || wizardStep == kWizardStepReview || wizardStep == kWizardStepSchedule) {
        [browseViewController saveOrderModel];
    }
    
    [self.window close];
}

- (IBAction)btnSubmitFeedbackClicked:(id)sender
{
    txtFeedbackName.stringValue = @"";
    txtFeedbackEmail.stringValue = @"";
    [feedbackType selectItemAtIndex:0];
    txtFeedbackText.stringValue = @"";
    [sendingFeedbackLabel setHidden:YES];
    
    [NSApp beginSheet:submitFeedbackSheet modalForWindow:self.window
        modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction)btnFeedbackCancelClicked:(id)sender
{
    [submitFeedbackSheet close];
    [NSApp endSheet:submitFeedbackSheet];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    BOOL result = NO;
    
    if (commandSelector == @selector(insertNewline:)) {
        [textView insertNewlineIgnoringFieldEditor:self];
        result = YES;
    } else if (commandSelector == @selector(insertTab:)) {
        [textView insertTabIgnoringFieldEditor:self];
        result = YES;
    }
    
    return result;
}

- (IBAction)btnFeedbackSubmitClicked:(id)sender
{
    if (!txtFeedbackName.stringValue.length) {
        [txtFeedbackName becomeFirstResponder];
        return;
    }
    
    if (!txtFeedbackEmail.stringValue.length) {
        [txtFeedbackEmail becomeFirstResponder];
        return;
    }
    
    if (!txtFeedbackText.stringValue.length) {
        [txtFeedbackText becomeFirstResponder];
        return;
    }
    
    NSString *credentials = @"";
    NSString *url = @"";
    
    if (effectiveUser) {
        credentials = [NSString stringWithFormat:@"%@", effectiveUser];
    }
    
    if (effectiveCoreDomain) {
        url = effectiveCoreDomain;
    } else {
        url = @"quicpost.candid.com/CORE";
    }
    
    NSString *ccsAccount = @"";
    NSString *orderNumber = @"";
    
    if (eventRow) {
        ccsAccount = eventRow.ccsAccount;
        orderNumber = eventRow.orderNumber;
    }
    
    NSData *zipData = nil;
    
    if (![FileUtil createLogFile]) {
        zipData = [FileUtil zipDataForFiles:@[@"/tmp/ccsuploader.log"]];
        [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/ccsuploader.log" error:nil];
    }
    
    BOOL started = [sendFeedbackService
        startSendFeedback:[FileUtil versionString]
        credentials:credentials
        url:url
        ccsAccount:ccsAccount
        orderNumber:orderNumber
        system:effectiveCoreDomain ? @"CORE" : @"QuicPost"
        program:@"Wizard"
        description:txtFeedbackText.stringValue
        type:feedbackType.selectedItem.title
        name:txtFeedbackName.stringValue
        email:txtFeedbackEmail.stringValue
        files:zipData
        complete:^(ServiceResult *result) {
            [btnFeedbackCancel setEnabled:YES];
            [btnFeedbackSubmit setEnabled:YES];
            [txtFeedbackName setEnabled:YES];
            [txtFeedbackEmail setEnabled:YES];
            [feedbackType setEnabled:YES];
            [txtFeedbackText setEnabled:YES];

            [sendingFeedbackProgress stopAnimation:nil];
            
            if (result.error) {
                sendingFeedbackLabel.stringValue = result.error.localizedDescription;
            } else {
                [sendingFeedbackLabel setHidden:YES];
                [submitFeedbackSheet close];
                [NSApp endSheet:submitFeedbackSheet];
            }
        }
    ];
    
    if (started) {
        [btnFeedbackCancel setEnabled:NO];
        [btnFeedbackSubmit setEnabled:NO];
        [txtFeedbackName setEnabled:NO];
        [txtFeedbackEmail setEnabled:NO];
        [feedbackType setEnabled:NO];
        [txtFeedbackText setEnabled:NO];
        
        sendingFeedbackLabel.stringValue = @"Sending feedback";
        [sendingFeedbackLabel setHidden:NO];
        [sendingFeedbackProgress startAnimation:nil];
    }
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
            self.window.title = @"Uploader Wizard";
            [browseViewController saveOrderModel];
            [mainWindowController.openedEvents removeObject:eventRow.orderNumber];
            eventRow = nil;
            [self showStep:kWizardStepEvents];
            [eventsViewController refreshIfEmpty];
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
            if (browseViewController.orderModel.rolls.count == 0) {
                NSAlert *alert = [NSAlert alertWithMessageText:@"You must add at least one folder in order to proceed." defaultButton:@"OK" alternateButton:@"" otherButton:@"" informativeTextWithFormat:@""];
                
                [alert beginSheetModalForWindow:self.window completionHandler:nil];
            } else {
                //[browseViewController saveOrderModel];
                [reviewViewController reload];
                [self showStep:kWizardStepReview];
            }
        } break;
            
        case kWizardStepReview: {
            [scheduleViewController resetFormState];
            [self showStep:kWizardStepSchedule];
        } break;
            
        case kWizardStepSchedule: {
            [scheduleViewController pushTransfer];
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
    
    if (step == kWizardStepLogin || step == kWizardStepSchedule) {
        btnNext.keyEquivalent = @"\r";
    } else {
        btnNext.keyEquivalent = @"";
    }

    if (step == kWizardStepSchedule) {
        btnNext.title = @"Push Transfer";
    } else {
        btnNext.title = @"Next →";
    }
    
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
