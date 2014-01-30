#import "LoginViewController.h"
#import "../WizardWindowController.h"
#import "../Prefs/AdvancedViewController.h"

#import "../../Services/AuthService.h"

@interface LoginViewController () {
    IBOutlet NSPopUpButton *btnService;
    IBOutlet NSTextField *txtUsername, *txtPassword, *txtEventNumber;
    AuthService *authService;
    WizardWindowController *wizardWindowController;

    NSString *quicPostUser, *quicPostPass;
    NSString *coreUser, *corePass, *coreDomain;
    NSNumber *quicPostSelected;
}

@end

@implementation LoginViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"LoginView" bundle:nil];

    if (self) {
        wizardWindowController = parent;
        authService = [AuthService new];
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    quicPostUser = [defaults objectForKey:@"quicPostUser"];
    quicPostPass = [defaults objectForKey:@"quicPostPass"];
    coreUser = [defaults objectForKey:@"coreUser"];
    corePass = [defaults objectForKey:@"corePass"];
    coreDomain = [defaults objectForKey:@"coreDomain"];
    quicPostSelected = [defaults objectForKey:@"quicPostSelected"];

    if (!quicPostUser) {
        quicPostUser = @"";
    }
    
    if (!quicPostPass) {
        quicPostPass = @"";
    }
    
    if (!coreUser) {
        coreUser = @"";
    }
    
    if (!corePass) {
        corePass = @"";
    }
    
    if (!coreDomain) {
        coreDomain = @"";
    }
    
    if (!quicPostSelected) {
        quicPostSelected = [NSNumber numberWithBool:YES];
    } else {
        [btnService selectItemWithTag:quicPostSelected.boolValue ? 0 : 1];
    }
    
    if (btnService.selectedTag == 0) {
        txtUsername.stringValue = quicPostUser;
        txtPassword.stringValue = quicPostPass;
    } else {
        txtUsername.stringValue = coreUser;
        txtPassword.stringValue = corePass;
    }
}

- (IBAction)serviceChanged:(id)sender
{
    if (btnService.selectedTag == 0) {
        txtUsername.stringValue = quicPostUser;
        txtPassword.stringValue = quicPostPass;
    } else {
        txtUsername.stringValue = coreUser;
        txtPassword.stringValue = corePass;
    }
}

- (void)startLogin
{
    BOOL started = [authService startAuth:txtUsername.stringValue password:txtPassword.stringValue
        complete:^(AuthResult *result) {
            if (result.error != nil) {
                NSAlert *alert = [NSAlert alertWithError:result.error];
                [wizardWindowController showLoginStep];
                [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
            } else {
                if (result.success) {
                    
                    
                    wizardWindowController.loadingViewController.txtMessage.stringValue = @"Retrieving events...";
                    [wizardWindowController.eventsViewController loadView];
                    [wizardWindowController.eventsViewController refreshEvents:YES];
                } else {
                    NSAlert *alert = [NSAlert new];
                    alert.messageText = @"Wrong username or password.";
                    [wizardWindowController showLoginStep];
                    [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
                }
            }
        }
    ];
    
    if (started) {
        wizardWindowController.loadingViewController.txtMessage.stringValue = @"Signing in...";
        [wizardWindowController showLoadingStep];
    }
}

- (IBAction)eventNumberHelp:(id)sender
{
    NSString *label = @"If left empty, you will be prompted to select an event from a list.";
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(220, 34)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

@end
