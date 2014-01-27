#import "LoginViewController.h"
#import "../Prefs/AdvancedViewController.h"
#import "../../Services/AuthService.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

- (id)init
{
    self = [super initWithNibName:@"LoginView" bundle:nil];

    if (self) {
    }
    
    return self;
}

- (IBAction)eventNumberHelp:(id)sender
{
    NSString *label = @"If left empty, you will be prompted to select an event from a list.";
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(220, 34)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
    
    AuthService *a = [AuthService new];
    
    [a start:@"ccsmacuploader" password:@"candid123" complete:^(AuthResult *result) {
        if (result.error != nil) {
            NSLog(@"Auth error: %@", result.error.localizedDescription);
        } else {
            if (result.success) {
                NSLog(@"Logged in successfully: %@.", result.accountID);
            } else {
                NSLog(@"Wrong username/password.");
            }
        }
    }];
}

@end
