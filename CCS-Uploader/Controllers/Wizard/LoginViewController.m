#import "LoginViewController.h"
#import "../WizardWindowController.h"
#import "../Prefs/AdvancedViewController.h"

#import "../../Services/AuthService.h"

@interface LoginViewController () {
    IBOutlet NSPopUpButton *btnService;
    IBOutlet NSTextField *txtUsername, *txtPassword, *lblCoreURL, *txtCoreURL, *txtEventNumber;
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

- (void)reloadAccounts
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    quicPostUser = [defaults objectForKey:kQuicPostUser];
    quicPostPass = [defaults objectForKey:kQuicPostPass];
    coreUser = [defaults objectForKey:kCoreUser];
    corePass = [defaults objectForKey:kCorePass];
    coreDomain = [defaults objectForKey:kCoreDomain];
    quicPostSelected = [defaults objectForKey:kQuicPostSelected];
    
    if (!quicPostSelected) {
        quicPostSelected = [NSNumber numberWithBool:YES];
    } else {
        [btnService selectItemWithTag:quicPostSelected.boolValue ? 0 : 1];
    }
    
    if (btnService.selectedTag == 0) {
        txtUsername.stringValue = quicPostUser ? [quicPostUser copy] : @"";
        txtPassword.stringValue = quicPostPass ? [quicPostPass copy] : @"";
        [lblCoreURL setHidden:YES];
        [txtCoreURL setHidden:YES];
        txtCoreURL.stringValue = @"";
    } else {
        txtUsername.stringValue = coreUser ? [coreUser copy] : @"";
        txtPassword.stringValue = corePass ? [corePass copy] : @"";
        [lblCoreURL setHidden:NO];
        [txtCoreURL setHidden:NO];
        txtCoreURL.stringValue = coreDomain ? [coreDomain copy] : kDefaultCoreDomain;
    }
}

- (void)loadView
{
    [super loadView];
    [self reloadAccounts];
}

- (IBAction)serviceChanged:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (btnService.selectedTag == 0) {
        quicPostUser = [defaults objectForKey:kQuicPostUser];
        quicPostPass = [defaults objectForKey:kQuicPostPass];

        txtUsername.stringValue = quicPostUser ? [quicPostUser copy] : @"";
        txtPassword.stringValue = quicPostPass ? [quicPostPass copy] : @"";
        [lblCoreURL setHidden:YES];
        [txtCoreURL setHidden:YES];
        txtCoreURL.stringValue = @"";
    } else {
        coreUser = [defaults objectForKey:kCoreUser];
        corePass = [defaults objectForKey:kCorePass];
        coreDomain = [defaults objectForKey:kCoreDomain];
        
        txtUsername.stringValue = coreUser ? [coreUser copy] : @"";
        txtPassword.stringValue = corePass ? [corePass copy] : @"";
        [lblCoreURL setHidden:NO];
        [txtCoreURL setHidden:NO];
        txtCoreURL.stringValue = coreDomain ? [coreDomain copy] : kDefaultCoreDomain;
    }
}

- (void)startLogin
{
    if (!txtUsername.stringValue.length || !txtPassword.stringValue.length ||
        (btnService.selectedTag == 1 && !txtCoreURL.stringValue.length)) {
        
        NSAlert *alert = [NSAlert new];
        
        alert.messageText = !txtUsername.stringValue.length ?
            @"You must enter a username." : (!txtPassword.stringValue.length ?
                @"You must enter a password." : @"You must enter a CORE URL when the CORE service is selected.");
        
        [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
        return;
    }
    
    [authService setEffectiveServiceRoot:btnService.selectedTag coreDomain:txtCoreURL.stringValue];
    
    BOOL started = [authService startAuth:txtUsername.stringValue password:txtPassword.stringValue
        complete:^(AuthResult *result) {
            if (result.error != nil) {
                NSAlert *alert = [NSAlert alertWithError:result.error];
                [wizardWindowController showStep:kWizardStepLogin];
                [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
            } else {
                if (result.success) {
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    
                    if (btnService.selectedTag == 0) {
                        [defaults setObject:txtUsername.stringValue forKey:kQuicPostUser];
                        [defaults setObject:txtPassword.stringValue forKey:kQuicPostPass];
                        [defaults setObject:[NSNumber numberWithBool:YES] forKey:kQuicPostSelected];
                    } else {
                        [defaults setObject:txtUsername.stringValue forKey:kCoreUser];
                        [defaults setObject:txtPassword.stringValue forKey:kCorePass];
                        [defaults setObject:txtCoreURL.stringValue forKey:kCoreDomain];
                        [defaults setObject:[NSNumber numberWithBool:NO] forKey:kQuicPostSelected];
                    }
                    
                    [defaults synchronize];
                    
                    wizardWindowController.effectiveUser = [txtUsername.stringValue copy];
                    wizardWindowController.effectivePass = [txtPassword.stringValue copy];
                    wizardWindowController.effectiveService = btnService.selectedTag;
                    wizardWindowController.effectiveCoreDomain =
                        btnService.selectedTag == 1 ? [txtCoreURL.stringValue copy] : nil;
                    
                    wizardWindowController.loadingViewController.txtMessage.stringValue = @"Retrieving events...";
                    [wizardWindowController.eventsViewController refreshEvents:YES];
                } else {
                    NSAlert *alert = [NSAlert new];
                    alert.messageText = @"Wrong username or password.";
                    [wizardWindowController showStep:kWizardStepLogin];
                    [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
                }
            }
        }
    ];
    
    if (started) {
        wizardWindowController.loadingViewController.txtMessage.stringValue = @"Signing in...";
        [wizardWindowController showStep:kWizardStepLoading];
    }
}

- (IBAction)eventNumberHelp:(id)sender
{
    NSString *label = @"If left empty, you will be prompted to select an event from a list.";
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(220, 34)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

@end
